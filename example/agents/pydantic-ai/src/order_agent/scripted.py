import json
import re
from collections.abc import AsyncIterator
from datetime import date
from typing import Any

from order_desk.script import Answer, Call, Part, play
from pydantic_ai.messages import (
    ModelMessage,
    ModelResponse,
    TextPart,
    ToolCallPart,
    ToolReturnPart,
    UserPromptPart,
)
from pydantic_ai.models.function import AgentInfo, DeltaToolCall, DeltaToolCalls, FunctionModel


def scripted_model(today: date) -> FunctionModel:
    """Plays the order desk script in place of a model, with no network and no API key."""

    def turn(messages: list[ModelMessage], info: AgentInfo) -> list[str | Call]:
        tools = [tool.name for tool in info.function_tools]
        return play([_parts(m) for m in messages], tools, info.instructions or "", today)

    async def respond(messages: list[ModelMessage], info: AgentInfo) -> ModelResponse:
        steps = turn(messages, info)
        return ModelResponse(
            parts=[
                TextPart(step) if isinstance(step, str) else ToolCallPart(step.name, step.args)
                for step in steps
            ]
        )

    async def stream(
        messages: list[ModelMessage], info: AgentInfo
    ) -> AsyncIterator[str | DeltaToolCalls]:
        """The text word by word, then all the calls in one chunk."""
        steps = turn(messages, info)
        for step in steps:
            if isinstance(step, str):
                for word in re.findall(r"\S+\s*", step):
                    yield word
        if calls := [step for step in steps if isinstance(step, Call)]:
            yield {
                i: DeltaToolCall(name=call.name, json_args=json.dumps(call.args))
                for i, call in enumerate(calls)
            }

    return FunctionModel(respond, stream_function=stream, model_name="scripted-order")


def _parts(message: ModelMessage) -> list[Part]:
    parts: list[Part] = []
    for part in message.parts:
        match part:
            case UserPromptPart(content=str(text)) | TextPart(content=text):
                parts.append(text)
            case ToolCallPart():
                parts.append(Call(part.tool_name, part.args_as_dict()))
            case ToolReturnPart():
                parts.append(Answer(part.tool_name, _result(part.content)))
    return parts


def _result(content: Any) -> Any:
    if not isinstance(content, str):
        return content
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        return content
