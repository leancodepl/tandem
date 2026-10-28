"""The demo script that each agent's scripted model plays in place of a real model.

Like a real model it decides only from the request: the conversation, the offered tools and the
screen in the instruction. So it keeps no count of runs. Each agent turns its framework's request
into `Part`s and the turn back into its framework's response.
"""

import calendar
import json
import re
from collections.abc import Collection, Iterator, Sequence
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any

NEUTRAL_REPLY = "Paste a customer's e-mail, or ask me to place the order."
_EMAIL_LINES = {"HDMI cable 2 m": 40, "27-inch monitor": 12}


@dataclass(frozen=True)
class Call:
    name: str
    args: dict[str, Any]


@dataclass(frozen=True)
class Answer:
    name: str
    result: Any


Part = str | Call | Answer
Message = Sequence[Part]


def play(
    messages: Sequence[Message], tools: Collection[str], instruction: str, today: date
) -> list[str | Call]:
    """The next turn of the model, oldest message first. The last message holds the user's text
    or the answers the model waits for."""
    return _Turn(messages, tools, instruction, today).decide()


class _Turn:
    def __init__(
        self, messages: Sequence[Message], tools: Collection[str], instruction: str, today: date
    ) -> None:
        self.messages = messages
        self.tools = tools
        self.instruction = instruction
        self.today = today

    def decide(self) -> list[str | Call]:
        if self._just_invalidated("place_order") and "place_order" in self.tools:
            return self._place()
        last = self.messages[-1]
        answered = {part.name for part in last if isinstance(part, Answer)}
        text = " ".join(part for part in last if isinstance(part, str))
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
            return [Call("find_customer", {"query": text.rpartition("Thanks,")[2].strip()})]
        return [NEUTRAL_REPLY]

    def _look_up_history(self) -> list[str | Call]:
        customers = self._answers("find_customer")[-1]
        if not customers:
            return ["I could not find this customer. Who is the order for?"]
        return [Call("get_order_history", {"customer_id": customers[0]["id"]})]

    def _look_up_products(self) -> list[str | Call]:
        customer = self._answers("find_customer")[-1][0]
        return [
            Call("set_customer", {"customerId": customer["id"]}),
            *(Call("search_catalog", {"query": query}) for query in _EMAIL_LINES),
        ]

    def _fill_order(self) -> list[str | Call]:
        customer = self._answers("find_customer")[-1][0]
        orders = self._answers("get_order_history")[-1]
        last_skus = {line["sku"] for line in orders[0]["lines"]} if orders else set()
        if not (address := customer.get("usualDeliveryAddress")):
            return ["Which address should I deliver to?"]
        said: list[str | Call] = []
        quantities = []
        searches = self._answers("search_catalog")[-len(_EMAIL_LINES) :]
        for (query, quantity), products in zip(_EMAIL_LINES.items(), searches, strict=True):
            if not products:
                return [f'I could not find "{query}" in the catalog.']
            # "Like last time": of several matches, take the product of the last order.
            product = next((p for p in products if p["sku"] in last_skus), products[0])
            quantities.append(Call("set_quantity", {"sku": product["sku"], "quantity": quantity}))
            if len(products) > 1 and product["sku"] in last_skus:
                said = [_assumption(product, orders[0])]
        friday = _next_friday(self.today).isoformat()
        return [*said, *quantities, Call("set_delivery", {"address": address, "date": friday})]

    def _ask_to_place(self) -> list[str | Call]:
        order = self._order()
        names = {"VC-HDMI-2M": "HDMI cables", "VM-27Q": "ProView 27Q monitors"}
        lines = " and ".join(
            f"{line['quantity']} {names.get(line['sku'], line['name'])}" for line in order["lines"]
        )
        day = _day_month(order["delivery"]["date"])
        return [f"{lines}, delivered on {day}. Total {order['total']}. Shall I place it?"]

    def _place(self) -> list[str | Call]:
        monitors = sum(
            line["quantity"] for line in self._order()["lines"] if line["sku"].startswith("VM-")
        )
        # Acme's bulk tier, as in example/lib/desk/data/price_lists.dart.
        if monitors < 15:
            return [Call("place_order", {})]
        tier = f"You changed the monitors to {monitors}, which unlocks Acme's 15+ tier"
        return [f"{tier} (17 % off monitors).", Call("place_order", {})]

    def _report(self) -> list[str | Call]:
        match self._answers("place_order")[-1]:
            case str(order_id):
                # A desk filled by hand has no set_delivery call in this chat.
                delivery = next(self._call_args("set_delivery"), None)
                when = f" for {_day_month(delivery['date'])}" if delivery else ""
                return [f"Order {order_id} placed{when}."]
            case {"status": "rejected_by_user"}:
                return ["OK, I won't place it."]
            case _:
                return [NEUTRAL_REPLY]

    def _order(self) -> dict:
        found = re.search(r"^- order: .*?: (\{.*\})$", self.instruction, re.MULTILINE)
        if found is None:
            raise ValueError("The screen has no order.")
        return json.loads(found[1])

    def _just_invalidated(self, tool: str) -> bool:
        # Some frameworks keep the answers that come with a user message as a message of their own.
        return any(
            isinstance(part, Answer)
            and part.name == tool
            and isinstance(part.result, dict)
            and part.result.get("status") == "invalidated"
            for message in self.messages[-2:]
            for part in message
        )

    def _answers(self, tool: str) -> list[Any]:
        return [
            part.result
            for message in self.messages
            for part in message
            if isinstance(part, Answer) and part.name == tool
        ]

    def _call_args(self, tool: str) -> Iterator[dict]:
        for message in reversed(self.messages):
            for part in message:
                if isinstance(part, Call) and part.name == tool:
                    yield part.args


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
