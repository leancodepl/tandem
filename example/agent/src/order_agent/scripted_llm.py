"""A stand-in for Gemini that plays the script of the demo, without network or key.

Like a real model it decides only from the request: the conversation, the tools
it is offered and the screen in the system instruction. So it keeps no count of runs.
"""

import calendar
import json
import re
from collections.abc import AsyncGenerator, Iterator
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any

from google.adk.models import BaseLlm, LlmRequest, LlmResponse
from google.genai import types

from order_agent.streaming import stream_turn

# The product the e-mail of the demo asks for first.
_EMAIL_MARKER = "HDMI"
_SIGNATURE_MARKER = "Thanks,"
# The word of a user message that asks to place the order, as "Looks good, place it".
_PLACE_MARKER = "place"
_DELIVERY_WEEKDAY = calendar.FRIDAY
_DAYS_IN_WEEK = 7
_NEUTRAL = "Paste a customer's e-mail, or ask me to place the order."
_ASK_ADDRESS = "Which address should I deliver to?"
# The tool answer that Tandem sends for a rejected card.
_REJECTED = "rejected_by_user"
# Acme's price list takes 5 % more off monitors, 17 % in all, from 15 monitors of any model.
_MONITOR_PREFIX = "VM-"
_BULK_MONITORS = 15
_BULK_DISCOUNT = 17
_BRAND = "Voltra "
_PRODUCT_NAMES = {"VC-HDMI-2M": "HDMI cables", "VM-27Q": "ProView 27Q monitors"}
# The line of the system instruction that shows the order on the screen.
_ORDER_LINE = re.compile(r"^- order: .*?: (\{.*\})$", re.MULTILINE)


@dataclass(frozen=True)
class _Ask:
    """A product the e-mail asks for, as the catalog search takes it."""

    query: str
    quantity: int


_ASKS = (_Ask("HDMI cable 2 m", 40), _Ask("27-inch monitor", 12))


class ScriptedOrderLlm(BaseLlm):
    """Plays the demo script deterministically; `today` is the demo's today."""

    model: str = "scripted-order"
    today: date

    async def generate_content_async(
        self, llm_request: LlmRequest, stream: bool = False
    ) -> AsyncGenerator[LlmResponse, None]:
        parts = _Turn(llm_request, self.today).decide()
        if not stream:
            yield LlmResponse(content=types.Content(role="model", parts=parts))
            return
        async for response in stream_turn(parts):
            yield response


class _Turn:
    """One model call: what the request shows, and what to answer."""

    def __init__(self, request: LlmRequest, today: date) -> None:
        self.today = today
        self.contents = request.contents
        self.tools = request.tools_dict
        instruction = request.config.system_instruction
        self.instruction = instruction if isinstance(instruction, str) else ""

    def decide(self) -> list[types.Part]:
        """The step of the script that follows the end of the conversation."""
        last = self.contents[-1]
        answered = {part.function_response.name for part in last.parts if part.function_response}
        text = " ".join(part.text for part in last.parts if part.text)
        after = {
            "place_order": self._report,
            "search_catalog": self._fill_order,
            "get_order_history": self._look_up_products,
            "find_customer": self._look_up_history,
            "set_delivery": self._ask_to_place,
        }
        for name, handle in after.items():
            if name in answered:
                return handle()
        # The app lists place_order only for an order it can place.
        if _PLACE_MARKER in text.lower() and "place_order" in self.tools:
            return self._place()
        if _EMAIL_MARKER in text:
            return [_call("find_customer", query=text.rpartition(_SIGNATURE_MARKER)[2].strip())]
        return [_say(_NEUTRAL)]

    # The steps of the script, in order.

    def _look_up_history(self) -> list[types.Part]:
        customers = _result(self._answers("find_customer")[-1])
        if not customers:
            return [_say("I could not find this customer. Who is the order for?")]
        return [_call("get_order_history", customer_id=customers[0]["id"])]

    def _look_up_products(self) -> list[types.Part]:
        customer = _result(self._answers("find_customer")[-1])[0]
        return [
            _call("set_customer", customerId=customer["id"]),
            *(_call("search_catalog", query=ask.query) for ask in _ASKS),
        ]

    def _fill_order(self) -> list[types.Part]:
        customer = _result(self._answers("find_customer")[-1])[0]
        orders = _result(self._answers("get_order_history")[-1])
        last_skus = {line["sku"] for line in orders[0]["lines"]} if orders else set()
        if not (address := customer.get("usualDeliveryAddress")):
            return [_say(_ASK_ADDRESS)]
        said: list[types.Part] = []
        quantities = []
        for ask, found in zip(_ASKS, self._answers("search_catalog")[-len(_ASKS) :], strict=True):
            if not (products := _result(found)):
                return [_say(f'I could not find "{ask.query}" in the catalog.')]
            # "Like last time": of several matches take the product of the last order.
            product = next((p for p in products if p["sku"] in last_skus), products[0])
            quantities.append(_call("set_quantity", sku=product["sku"], quantity=ask.quantity))
            if len(products) > 1 and product["sku"] in last_skus:
                said = [_say(_assumption(product, orders[0]))]
        friday = _next_friday(self.today).isoformat()
        return [*said, *quantities, _call("set_delivery", address=address, date=friday)]

    def _ask_to_place(self) -> list[types.Part]:
        order = self._order()
        lines = " and ".join(
            f"{line['quantity']} {_PRODUCT_NAMES.get(line['sku'], line['name'])}"
            for line in order["lines"]
        )
        day = _day_month(order["delivery"]["date"])
        return [_say(f"{lines}, delivered on {day}. Total {order['total']}. Shall I place it?")]

    def _place(self) -> list[types.Part]:
        monitors = sum(
            line["quantity"]
            for line in self._order()["lines"]
            if line["sku"].startswith(_MONITOR_PREFIX)
        )
        tier = []
        if monitors >= _BULK_MONITORS:
            tier = [
                _say(
                    f"You changed the monitors to {monitors}, which unlocks Acme's "
                    f"{_BULK_MONITORS}+ tier ({_BULK_DISCOUNT} % off monitors)."
                )
            ]
        return [*tier, _call("place_order")]

    def _report(self) -> list[types.Part]:
        result = _result(self._answers("place_order")[-1])
        if isinstance(result, str):  # The id of the order.
            # Known only when this chat filled the delivery, not for a desk filled by hand.
            delivery = next(self._call_args("set_delivery"), None)
            when = f" for {_day_month(delivery['date'])}" if delivery else ""
            return [_say(f"Order {result} placed{when}.")]
        if isinstance(result, dict) and result.get("status") == _REJECTED:
            return [_say("OK, I won't place it.")]
        return [_say(_NEUTRAL)]

    # Reading the request.

    def _order(self) -> dict:
        """The order on the screen, from the system instruction."""
        found = _ORDER_LINE.search(self.instruction)
        return json.loads(found[1]) if found else {"lines": []}

    def _answers(self, tool: str) -> list[dict]:
        """The answers to the calls of `tool`, oldest first."""
        return [
            part.function_response.response
            for content in self.contents
            for part in content.parts
            if part.function_response and part.function_response.name == tool
        ]

    def _call_args(self, tool: str) -> Iterator[dict]:
        """The arguments of the calls of `tool`, newest first."""
        for content in reversed(self.contents):
            for part in content.parts:
                if part.function_call and part.function_call.name == tool:
                    yield part.function_call.args


def _result(response: dict) -> Any:
    """What a tool returned: ADK wraps a value that is not an object in `result`."""
    return response.get("result", response)


def _next_friday(today: date) -> date:
    """The first Friday after `today`, which is a week later when today is one."""
    days = (_DELIVERY_WEEKDAY - today.weekday()) % _DAYS_IN_WEEK
    return today + timedelta(days=days or _DAYS_IN_WEEK)


def _assumption(product: dict, order: dict) -> str:
    """Says that the product was taken from `order`, as in "like last time"."""
    model = product["name"].split(",")[0].removeprefix(_BRAND)
    month = f"{date.fromisoformat(order['date']):%B}"
    return f"I assumed the {model}, as in your {month} order {order['orderId']}."


def _day_month(iso: str) -> str:
    """An ISO date or date and time as `23 Oct`."""
    day = datetime.fromisoformat(iso)
    return f"{day.day} {day:%b}"


def _call(name: str, **args: object) -> types.Part:
    # No id: ADK gives every function call its own.
    return types.Part(function_call=types.FunctionCall(name=name, args=args))


def _say(text: str) -> types.Part:
    return types.Part(text=text)
