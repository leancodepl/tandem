"""A chat with the agent the way Tandem's session keeps it.

One thread id for all runs and a new run id for each. The history holds what the user typed, what
the agent said and the calls of the app's tools, with the app's answers as tool messages before
the next user message. It leaves out the calls of the server's own tools. Every run brings `tools`
and `context`.
"""

import json
import uuid
from dataclasses import dataclass, field

import httpx

ORDER_DESCRIPTION = "order: The order as the user sees it on the screen."

# The app's tools as `order_desk_cubit.g.dart` declares them.
SEARCH_CATALOG = {
    "name": "search_catalog",
    "description": "Finds products by SKU, name or description.",
    "parameters": {
        "type": "object",
        "properties": {"query": {"type": "string"}},
        "required": ["query"],
    },
}
SET_CUSTOMER = {
    "name": "set_customer",
    "description": "Sets the customer the order is for; prices follow their price list.",
    "parameters": {
        "type": "object",
        "properties": {"customerId": {"type": "string"}},
        "required": ["customerId"],
    },
}
SET_QUANTITY = {
    "name": "set_quantity",
    "description": "Sets how many pieces of [sku] the order has; 0 removes the line.",
    "parameters": {
        "type": "object",
        "properties": {"sku": {"type": "string"}, "quantity": {"type": "integer"}},
        "required": ["sku", "quantity"],
    },
}
SET_DELIVERY = {
    "name": "set_delivery",
    "description": "Sets where and when the order is delivered.",
    "parameters": {
        "type": "object",
        "properties": {
            "address": {"type": "string"},
            "date": {"type": "string", "format": "date-time"},
        },
        "required": ["address", "date"],
    },
}
PLACE_ORDER = {
    "name": "place_order",
    "description": "Places the order exactly as it is on the screen.",
    "parameters": {"type": "object", "properties": {}},
}


@dataclass
class Call:
    id: str
    name: str
    arguments: str = ""

    @property
    def args(self) -> dict:
        return json.loads(self.arguments or "{}")


@dataclass
class Run:
    events: list[dict]

    @property
    def types(self) -> list[str]:
        return [event["type"] for event in self.events]

    @property
    def text(self) -> str:
        return "".join(e["delta"] for e in self.events if e["type"] == "TEXT_MESSAGE_CONTENT")

    @property
    def calls(self) -> list[Call]:
        calls: dict[str, Call] = {}
        for event in self.events:
            match event["type"]:
                case "TOOL_CALL_START":
                    calls[event["toolCallId"]] = Call(event["toolCallId"], event["toolCallName"])
                case "TOOL_CALL_ARGS":
                    calls[event["toolCallId"]].arguments += event["delta"]
        return list(calls.values())

    @property
    def app_calls(self) -> list[Call]:
        answered = {e["toolCallId"] for e in self.events if e["type"] == "TOOL_CALL_RESULT"}
        return [call for call in self.calls if call.id not in answered]


@dataclass
class Thread:
    agent_url: str
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    history: list[dict] = field(default_factory=list)

    def run(
        self,
        order: dict,
        text: str | None = None,
        answers: dict[str, str] | None = None,
        *,
        placed: bool = False,
    ) -> Run:
        """Sends the app's `answers` by call id, then `text`.

        With `placed`, the desk shows `order` as placed and read-only.
        """
        self.history += [
            {"id": f"tool-{call_id}", "role": "tool", "toolCallId": call_id, "content": content}
            for call_id, content in (answers or {}).items()
        ]
        if text is not None:
            self.history.append({"id": f"user-{uuid.uuid4()}", "role": "user", "content": text})
        # As the order desk lists them.
        tools = [SEARCH_CATALOG]
        if not placed:
            tools += [SET_CUSTOMER, SET_QUANTITY, SET_DELIVERY]
            if order["lines"] and order["customer"] and order["delivery"]:
                tools.append(PLACE_ORDER)
        body = {
            "threadId": self.id,
            "runId": str(uuid.uuid4()),
            "state": {},
            "messages": self.history,
            "tools": tools,
            "context": [{"description": ORDER_DESCRIPTION, "value": _compact(order)}],
            "forwardedProps": {},
        }
        run = Run(self._post(body))
        self._remember(run, {tool["name"] for tool in tools})
        return run

    def _post(self, body: dict) -> list[dict]:
        with httpx.stream("POST", f"{self.agent_url}/agent", json=body) as response:
            response.raise_for_status()
            return [
                json.loads(line.removeprefix("data: "))
                for line in response.iter_lines()
                if line.startswith("data: ")
            ]

    def _remember(self, run: Run, app_tools: set[str]) -> None:
        texts: dict[str, dict] = {}
        for event in run.events:
            if event["type"] == "TEXT_MESSAGE_START":
                texts[event["messageId"]] = {
                    "id": event["messageId"],
                    "role": "assistant",
                    "content": "",
                }
                self.history.append(texts[event["messageId"]])
            elif event["type"] == "TEXT_MESSAGE_CONTENT":
                texts[event["messageId"]]["content"] += event["delta"]
        for call in run.calls:
            if call.name in app_tools:
                function = {"name": call.name, "arguments": call.arguments or "{}"}
                self.history.append(
                    {
                        "id": f"asst-{call.id}",
                        "role": "assistant",
                        "toolCalls": [{"id": call.id, "type": "function", "function": function}],
                    }
                )


def _compact(value: object) -> str:
    """JSON the way Dart's `jsonEncode` writes it."""
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)
