"""Streams a whole model turn so that ag-ui-adk sees all its calls.

ag-ui-adk takes a call whose name repeats a call of an earlier chunk for a replay and drops it.
Gemini streams parallel calls in separate chunks, so of two `set_quantity` calls only the first
would reach the app. Here the text comes word by word and all the calls in one chunk.
"""

import asyncio
import re
from collections.abc import AsyncGenerator, Iterator

from google.adk.models import Gemini, LlmRequest, LlmResponse
from google.adk.utils.streaming_utils import StreamingResponseAggregator
from google.genai import types


async def stream_turn(parts: list[types.Part]) -> AsyncGenerator[LlmResponse, None]:
    """Yields `parts` the way ADK's streaming Gemini does, which is the path ag-ui-adk uses."""
    aggregator = StreamingResponseAggregator()
    for candidate in _candidates(parts):
        chunk = types.GenerateContentResponse(candidates=[candidate])
        async for response in aggregator.process_response(chunk):
            yield response
        # The pace of a streaming model.
        await asyncio.sleep(0.03)
    if (final := aggregator.close()) is not None:
        yield final


class WholeTurnGemini(Gemini):
    """Gemini that asks for the whole turn and streams it through `stream_turn`."""

    async def generate_content_async(
        self, llm_request: LlmRequest, stream: bool = False
    ) -> AsyncGenerator[LlmResponse, None]:
        async for response in super().generate_content_async(llm_request, stream=False):
            parts = response.content.parts if response.content else None
            if not stream or response.error_code or not parts:
                yield response
                continue
            async for chunk in stream_turn(parts):
                yield chunk


def _candidates(parts: list[types.Part]) -> Iterator[types.Candidate]:
    for part in parts:
        for word in re.findall(r"\S+\s*", part.text or ""):
            yield types.Candidate(content=types.ModelContent(parts=[types.Part(text=word)]))
    if calls := [part for part in parts if part.function_call]:
        yield types.Candidate(content=types.ModelContent(parts=calls))
    yield types.Candidate(finish_reason=types.FinishReason.STOP)
