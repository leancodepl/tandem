import calendar
import json
import re
from collections.abc import AsyncGenerator, Iterator
from datetime import date, datetime, timedelta
from typing import Any

from google.adk.models import BaseLlm, LlmRequest, LlmResponse
from google.genai import types

from order_agent.streaming import stream_turn

_NEUTRAL_REPLY = "Paste a customer's e-mail, or ask me to place the order."
_EMAIL_LINES = {"HDMI cable 2 m": 40, "27-inch monitor": 12}


class ScriptedOrderLlm(BaseLlm):
    """Plays the demo script in place of Gemini, with no network and no API key.

    Like a real model it decides only from the request: the conversation, the offered tools and
    the screen in the system instruction. So it keeps no count of runs.
    """

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
    def __init__(self, request: LlmRequest, today: date) -> None:
        self.today = today
        self.contents = request.contents
        self.tools = request.tools_dict
        instruction = request.config.system_instruction
        if not isinstance(instruction, str):
            raise TypeError("The system instruction is not a string.")
        self.instruction = instruction

    def decide(self) -> list[types.Part]:
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
        if "place" in text.lower() and "place_order" in self.tools:
            return self._place()
        if "HDMI" in text:
            return [_call("find_customer", query=text.rpartition("Thanks,")[2].strip())]
        return [_say(_NEUTRAL_REPLY)]

    def _look_up_history(self) -> list[types.Part]:
        customers = _result(self._answers("find_customer")[-1])
        if not customers:
            return [_say("I could not find this customer. Who is the order for?")]
        return [_call("get_order_history", customer_id=customers[0]["id"])]

    def _look_up_products(self) -> list[types.Part]:
        customer = _result(self._answers("find_customer")[-1])[0]
        return [
            _call("set_customer", customerId=customer["id"]),
            *(_call("search_catalog", query=query) for query in _EMAIL_LINES),
        ]

    def _fill_order(self) -> list[types.Part]:
        customer = _result(self._answers("find_customer")[-1])[0]
        orders = _result(self._answers("get_order_history")[-1])
        last_skus = {line["sku"] for line in orders[0]["lines"]} if orders else set()
        if not (address := customer.get("usualDeliveryAddress")):
            return [_say("Which address should I deliver to?")]
        said: list[types.Part] = []
        quantities = []
        searches = self._answers("search_catalog")[-len(_EMAIL_LINES) :]
        for (query, quantity), search in zip(_EMAIL_LINES.items(), searches, strict=True):
            if not (products := _result(search)):
                return [_say(f'I could not find "{query}" in the catalog.')]
            # "Like last time": of several matches, take the product of the last order.
            product = next((p for p in products if p["sku"] in last_skus), products[0])
            quantities.append(_call("set_quantity", sku=product["sku"], quantity=quantity))
            if len(products) > 1 and product["sku"] in last_skus:
                said = [_say(_assumption(product, orders[0]))]
        friday = _next_friday(self.today).isoformat()
        return [*said, *quantities, _call("set_delivery", address=address, date=friday)]

    def _ask_to_place(self) -> list[types.Part]:
        order = self._order()
        names = {"VC-HDMI-2M": "HDMI cables", "VM-27Q": "ProView 27Q monitors"}
        lines = " and ".join(
            f"{line['quantity']} {names.get(line['sku'], line['name'])}" for line in order["lines"]
        )
        day = _day_month(order["delivery"]["date"])
        return [_say(f"{lines}, delivered on {day}. Total {order['total']}. Shall I place it?")]

    def _place(self) -> list[types.Part]:
        monitors = sum(
            line["quantity"] for line in self._order()["lines"] if line["sku"].startswith("VM-")
        )
        # Acme's bulk tier, as in example/lib/desk/price_list.dart.
        if monitors < 15:
            return [_call("place_order")]
        return [
            _say(
                f"You changed the monitors to {monitors}, which unlocks Acme's 15+ tier "
                "(17 % off monitors)."
            ),
            _call("place_order"),
        ]

    def _report(self) -> list[types.Part]:
        match _result(self._answers("place_order")[-1]):
            case str(order_id):
                # A desk filled by hand has no set_delivery call in this chat.
                delivery = next(self._call_args("set_delivery"), None)
                when = f" for {_day_month(delivery['date'])}" if delivery else ""
                return [_say(f"Order {order_id} placed{when}.")]
            case {"status": "rejected_by_user"}:
                return [_say("OK, I won't place it.")]
            case _:
                return [_say(_NEUTRAL_REPLY)]

    def _order(self) -> dict:
        found = re.search(r"^- order: .*?: (\{.*\})$", self.instruction, re.MULTILINE)
        if found is None:
            raise ValueError("The screen has no order.")
        return json.loads(found[1])

    def _answers(self, tool: str) -> list[dict]:
        return [
            part.function_response.response
            for content in self.contents
            for part in content.parts
            if part.function_response and part.function_response.name == tool
        ]

    def _call_args(self, tool: str) -> Iterator[dict]:
        for content in reversed(self.contents):
            for part in content.parts:
                if part.function_call and part.function_call.name == tool:
                    yield part.function_call.args


def _result(response: dict) -> Any:
    """ADK wraps a tool result that is not an object in `{"result": ...}`."""
    return response.get("result", response)


def _next_friday(today: date) -> date:
    days = (calendar.FRIDAY - today.weekday()) % 7
    return today + timedelta(days=days or 7)


def _assumption(product: dict, order: dict) -> str:
    model = product["name"].split(",")[0].removeprefix("Voltra ")
    month = f"{date.fromisoformat(order['date']):%B}"
    return f"I assumed the {model}, as in your {month} order {order['orderId']}."


def _day_month(iso: str) -> str:
    day = datetime.fromisoformat(iso)
    return f"{day.day} {day:%b}"


def _call(name: str, **args: object) -> types.Part:
    # No id: ADK gives every function call its own.
    return types.Part(function_call=types.FunctionCall(name=name, args=args))


def _say(text: str) -> types.Part:
    return types.Part(text=text)
