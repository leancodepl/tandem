"""Streams the calls of a model turn one by one, the way ag-ui-langgraph reads them.

ag-ui-langgraph takes only the first call of a chunk, and the call's arguments only from the
chunks after it. ChatOllama and Gemini send all the calls of a turn whole, in one chunk, so the
app would get the first call without its arguments and none of the others.
"""

import itertools
from collections.abc import AsyncIterator, Iterator
from typing import Any

from langchain_core.callbacks import AsyncCallbackManagerForLLMRun
from langchain_core.language_models import BaseChatModel
from langchain_core.messages import AIMessageChunk, BaseMessage
from langchain_core.outputs import ChatGenerationChunk


class OneCallPerChunk(BaseChatModel):
    """A chat model mixin: put it before the model class."""

    async def _astream(
        self,
        messages: list[BaseMessage],
        stop: list[str] | None = None,
        run_manager: AsyncCallbackManagerForLLMRun | None = None,
        **kwargs: Any,
    ) -> AsyncIterator[ChatGenerationChunk]:
        indexes = itertools.count()
        async for chunk in super()._astream(messages, stop, run_manager, **kwargs):
            for piece in _split(chunk, indexes):
                yield piece


def _split(chunk: ChatGenerationChunk, indexes: Iterator[int]) -> Iterator[ChatGenerationChunk]:
    message = chunk.message
    if not isinstance(message, AIMessageChunk) or not message.tool_call_chunks:
        yield chunk
        return
    if message.content:
        yield ChatGenerationChunk(message=AIMessageChunk(content=message.content))
    for call in message.tool_call_chunks:
        # A running index: chunks with the same index merge into one call.
        index = next(indexes)
        start = {"name": call["name"], "id": call["id"], "args": "", "index": index}
        args = {"name": None, "id": None, "args": call["args"], "index": index}
        for part in (start, args):
            yield ChatGenerationChunk(message=AIMessageChunk(content="", tool_call_chunks=[part]))
    # Last, because the adapter skips a chunk with a finish reason.
    rest = message.model_copy(update={"content": "", "tool_call_chunks": [], "tool_calls": []})
    yield ChatGenerationChunk(message=rest, generation_info=chunk.generation_info)
