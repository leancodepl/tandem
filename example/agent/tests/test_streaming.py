import asyncio
from collections.abc import AsyncGenerator

import pytest
from google.adk.models import Gemini, LlmRequest, LlmResponse
from google.genai import types

from order_agent.streaming import WholeTurnGemini, stream_turn

TURN = [
    types.Part(text="Filling the order."),
    types.Part(function_call=types.FunctionCall(name="set_quantity", args={"sku": "A"})),
    types.Part(function_call=types.FunctionCall(name="set_quantity", args={"sku": "B"})),
    types.Part(function_call=types.FunctionCall(name="set_delivery", args={"date": "2026-10-23"})),
]
CALLS = [
    ("set_quantity", {"sku": "A"}),
    ("set_quantity", {"sku": "B"}),
    ("set_delivery", {"date": "2026-10-23"}),
]


@pytest.fixture
def whole_turn(monkeypatch: pytest.MonkeyPatch) -> list[bool]:
    """Gemini answers TURN; the list collects the `stream` it was asked with."""
    asked: list[bool] = []

    async def generate(
        self: Gemini, llm_request: LlmRequest, stream: bool = False
    ) -> AsyncGenerator[LlmResponse, None]:
        asked.append(stream)
        yield LlmResponse(content=types.Content(role="model", parts=TURN))

    monkeypatch.setattr(Gemini, "generate_content_async", generate)
    return asked


def responses(stream: bool) -> list[LlmResponse]:
    async def collect() -> list[LlmResponse]:
        model = WholeTurnGemini(model="gemini-3.8-flash")
        return [r async for r in model.generate_content_async(LlmRequest(), stream=stream)]

    return asyncio.run(collect())


def pieces(response: LlmResponse) -> list[object]:
    parts = response.content.parts if response.content else None
    return [
        (call.name, call.args) if (call := part.function_call) else part.text
        for part in parts or []
    ]


def test_a_streamed_turn_brings_the_words_one_by_one_and_all_calls_in_one_chunk(
    whole_turn: list[bool],
) -> None:
    streamed = [(r.partial, pieces(r)) for r in responses(stream=True) if r.content]

    assert streamed == [
        (True, ["Filling "]),
        (True, ["the "]),
        (True, ["order."]),
        (True, CALLS),
        (False, ["Filling the order.", *CALLS]),
    ]
    assert whole_turn == [False]


def test_an_unstreamed_request_gets_the_turn_as_is(whole_turn: list[bool]) -> None:
    assert [pieces(r) for r in responses(stream=False)] == [["Filling the order.", *CALLS]]


def test_an_empty_turn_ends_without_an_error() -> None:
    async def collect() -> list[LlmResponse]:
        return [r async for r in stream_turn([])]

    ends = [(r.partial, r.content, r.error_code) for r in asyncio.run(collect())]
    assert ends == [(True, None, None), (False, None, None)]
