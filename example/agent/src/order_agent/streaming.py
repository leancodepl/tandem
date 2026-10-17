"""A whole model turn, streamed so that ag-ui-adk sees every call of it.

ag-ui-adk takes a call that repeats the name of a call in an earlier chunk for a replay of it
and drops it. Gemini streams parallel calls in separate chunks, so of two `set_quantity` calls
of one turn only the first reached the app. Here the text comes word by word and all the calls
in one chunk.
"""

import asyncio
import re
from collections.abc import AsyncGenerator

from google.adk.models import Gemini, LlmRequest, LlmResponse
from google.adk.utils.streaming_utils import StreamingResponseAggregator
from google.genai import types

# What a streaming model takes between two chunks of text.
_CHUNK_DELAY_SECONDS = 0.03


async def stream_turn(parts: list[types.Part]) -> AsyncGenerator[LlmResponse, None]:
    """`parts` the way the streaming path of ADK's Gemini yields them, which ag-ui-adk uses."""
    aggregator = StreamingResponseAggregator()
    for chunk in _chunks(parts):
        async for response in aggregator.process_response(chunk):
            yield response
        await asyncio.sleep(_CHUNK_DELAY_SECONDS)
    if (final := aggregator.close()) is not None:
        yield final


class WholeTurnGemini(Gemini):
    """Gemini that answers a streaming request with the whole turn, through `stream_turn`."""

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


def _chunks(parts: list[types.Part]) -> list[types.GenerateContentResponse]:
    """The text of `parts` word by word, then all their calls at once."""
    pieces = [
        [types.Part(text=word)]
        for part in parts
        if part.text
        for word in re.findall(r"\S+\s*", part.text)
    ]
    if calls := [part for part in parts if part.function_call]:
        pieces.append(calls)
    if not pieces:
        pieces.append([types.Part(text="")])
    chunks = [
        types.GenerateContentResponse(
            candidates=[types.Candidate(content=types.Content(role="model", parts=piece))]
        )
        for piece in pieces
    ]
    chunks[-1].candidates[0].finish_reason = types.FinishReason.STOP
    return chunks
