from collections.abc import AsyncGenerator
from typing import Any

from adk_streaming import stream_turn
from google.adk.models import BaseLlm, LlmRequest, LlmResponse
from google.genai import types

from waypoint_agent.instruction import Screen
from waypoint_agent.script import Answer, Call, Part, play


class ScriptedLlm(BaseLlm):
    """Plays the screen's script in place of a model, with no network and no API key."""

    model: str = "scripted"
    screen: Screen

    async def generate_content_async(
        self, llm_request: LlmRequest, stream: bool = False
    ) -> AsyncGenerator[LlmResponse, None]:
        instruction = llm_request.config.system_instruction
        if not isinstance(instruction, str):
            raise TypeError("The system instruction is not a string.")
        messages = [_parts(content) for content in llm_request.contents]
        parts = [_part(step) for step in play(self.screen, messages, instruction)]
        if not stream:
            yield LlmResponse(content=types.Content(role="model", parts=parts))
            return
        async for response in stream_turn(parts):
            yield response


def _parts(content: types.Content) -> list[Part]:
    parts: list[Part] = []
    for part in content.parts or []:
        if part.text:
            parts.append(part.text)
        if call := part.function_call:
            parts.append(Call(call.name or "", call.args or {}))
        if response := part.function_response:
            parts.append(Answer(response.name or "", _result(response.response or {})))
    return parts


def _result(response: dict) -> Any:
    """ADK wraps a tool result that is not an object in `{"result": ...}`."""
    return response.get("result", response)


def _part(step: str | Call) -> types.Part:
    if isinstance(step, str):
        return types.Part(text=step)
    # No id: ADK gives every function call its own.
    return types.Part(function_call=types.FunctionCall(name=step.name, args=step.args))
