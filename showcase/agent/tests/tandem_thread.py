"""A chat with the agent the way Tandem's session keeps it.

One thread id for all runs and a new run id for each. The history holds what the user typed and
the agent's messages under the ids the server gave them, each with its text and calls, and the
app's answers come as tool messages before the next user message. Every run brings `tools` and
`context`.
"""

import json
import uuid
from dataclasses import dataclass, field

import httpx


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
    url: str
    description: str
    tools: list[dict]
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    history: list[dict] = field(default_factory=list)

    def run(
        self,
        screen: dict,
        text: str | None = None,
        answers: dict[str, str] | None = None,
        notes: list[str] | None = None,
    ) -> Run:
        """Sends the app's `answers` by call id, then `text`, with `screen` and the app's new
        `notes` as the context."""
        self.history += [
            {"id": f"tool-{call_id}", "role": "tool", "toolCallId": call_id, "content": content}
            for call_id, content in (answers or {}).items()
        ]
        if text is not None:
            self.history.append({"id": f"user-{uuid.uuid4()}", "role": "user", "content": text})
        body = {
            "threadId": self.id,
            "runId": str(uuid.uuid4()),
            "state": {},
            "messages": self.history,
            "tools": self.tools,
            "context": [
                {"description": self.description, "value": _compact(screen)},
                *_notes(notes),
            ],
            "forwardedProps": {},
        }
        run = Run(self._post(body))
        self._remember(run, {tool["name"] for tool in self.tools})
        return run

    def _post(self, body: dict) -> list[dict]:
        with httpx.stream("POST", self.url, json=body) as response:
            response.raise_for_status()
            return [
                json.loads(line.removeprefix("data: "))
                for line in response.iter_lines()
                if line.startswith("data: ")
            ]

    def _remember(self, run: Run, app_tools: set[str]) -> None:
        messages: dict[str, dict] = {}
        calls: dict[str, dict] = {}
        results: dict[str, dict] = {}
        for event in run.events:
            match event["type"]:
                case "TEXT_MESSAGE_CONTENT":
                    message = _message(messages, event["messageId"])
                    message["content"] = message.get("content", "") + event["delta"]
                case "TOOL_CALL_START":
                    # Without a parent, never the bare call id: ag-ui-adk would swallow the answer.
                    parent = event.get("parentMessageId") or f"asst-{event['toolCallId']}"
                    function = {"name": event["toolCallName"], "arguments": ""}
                    call = {"id": event["toolCallId"], "type": "function", "function": function}
                    calls[call["id"]] = call
                    _message(messages, parent).setdefault("toolCalls", []).append(call)
                case "TOOL_CALL_ARGS":
                    calls[event["toolCallId"]]["function"]["arguments"] += event["delta"]
                case "TOOL_CALL_RESULT":
                    results[event["toolCallId"]] = {
                        "id": event["messageId"],
                        "role": "tool",
                        "toolCallId": event["toolCallId"],
                        "content": event["content"],
                    }
        for message in messages.values():
            kept = [
                call
                for call in message.pop("toolCalls", [])
                if call["function"]["name"] in app_tools or call["id"] in results
            ]
            for call in kept:
                call["function"]["arguments"] = call["function"]["arguments"] or "{}"
            if kept:
                message["toolCalls"] = kept
            if "content" in message or kept:
                self.history.append(message)
            self.history += [results[call["id"]] for call in kept if call["id"] in results]


def _message(messages: dict[str, dict], message_id: str) -> dict:
    return messages.setdefault(message_id, {"id": message_id, "role": "assistant"})


def _compact(value: object) -> str:
    """JSON the way Dart's `jsonEncode` writes it."""
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def _notes(notes: list[str] | None) -> list[dict]:
    """The `app_notes` entry as Tandem's session sends it, with every note new."""
    if not notes:
        return []
    value = {"new": [{"note": note} for note in notes]}
    return [{"description": "app_notes: What happened in the app.", "value": _compact(value)}]
