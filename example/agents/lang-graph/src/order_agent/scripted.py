import json
import re
import uuid
from collections.abc import Iterator, Sequence
from datetime import date
from typing import Any

from langchain_core.callbacks import CallbackManagerForLLMRun
from langchain_core.messages import (
    AIMessage,
    AIMessageChunk,
    BaseMessage,
    HumanMessage,
    SystemMessage,
    ToolMessage,
)
from langchain_core.outputs import ChatGeneration, ChatGenerationChunk, ChatResult
from langchain_core.utils.function_calling import convert_to_openai_tool
from order_desk.script import Answer, Call, Part, play

from order_agent.streaming import OneCallPerChunk


class ScriptedChatModel(OneCallPerChunk):
    """Plays the order desk script in place of a model, with no network and no API key."""

    today: date
    tool_names: tuple[str, ...] = ()

    @property
    def _llm_type(self) -> str:
        return "scripted-order"

    def bind_tools(self, tools: Sequence[Any], **kwargs: Any) -> "ScriptedChatModel":
        names = tuple(convert_to_openai_tool(t)["function"]["name"] for t in tools)
        return self.model_copy(update={"tool_names": names})

    def _generate(
        self,
        messages: list[BaseMessage],
        stop: list[str] | None = None,
        run_manager: CallbackManagerForLLMRun | None = None,
        **kwargs: Any,
    ) -> ChatResult:
        return ChatResult(generations=[ChatGeneration(message=self._reply(messages))])

    def _stream(
        self,
        messages: list[BaseMessage],
        stop: list[str] | None = None,
        run_manager: CallbackManagerForLLMRun | None = None,
        **kwargs: Any,
    ) -> Iterator[ChatGenerationChunk]:
        """The text word by word, then all the calls whole in one chunk, as Ollama sends them."""
        reply = self._reply(messages)
        for word in re.findall(r"\S+\s*", reply.text):
            yield ChatGenerationChunk(message=AIMessageChunk(content=word))
        if calls := [
            {"name": c["name"], "args": json.dumps(c["args"]), "id": c["id"], "index": i}
            for i, c in enumerate(reply.tool_calls)
        ]:
            yield ChatGenerationChunk(message=AIMessageChunk(content="", tool_call_chunks=calls))

    def _reply(self, messages: list[BaseMessage]) -> AIMessage:
        system, *conversation = messages
        if not isinstance(system, SystemMessage):
            raise TypeError("The first message is not the instruction.")
        turn = play(_messages(conversation), self.tool_names, system.text, self.today)
        return AIMessage(
            content=" ".join(step for step in turn if isinstance(step, str)),
            tool_calls=[
                {"name": step.name, "args": step.args, "id": f"call_{uuid.uuid4().hex}"}
                for step in turn
                if isinstance(step, Call)
            ],
        )


def _messages(conversation: list[BaseMessage]) -> list[list[Part]]:
    """One message per LangChain message, except that the answers of one turn form one."""
    names: dict[str, str] = {}
    messages: list[list[Part]] = []
    for message in conversation:
        match message:
            case HumanMessage():
                messages.append([message.text])
            case AIMessage():
                names |= {c["id"] or "": c["name"] for c in message.tool_calls}
                calls = [Call(c["name"], c["args"]) for c in message.tool_calls]
                messages.append([message.text, *calls] if message.text else calls)
            case ToolMessage():
                answer = Answer(names.get(message.tool_call_id, ""), _result(message.text))
                if messages and all(isinstance(part, Answer) for part in messages[-1]):
                    messages[-1].append(answer)
                else:
                    messages.append([answer])
    return messages


def _result(content: str) -> Any:
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        return content
