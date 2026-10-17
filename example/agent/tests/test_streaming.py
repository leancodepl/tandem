import asyncio
from collections.abc import AsyncGenerator

import pytest
from google.adk.models import Gemini, LlmRequest, LlmResponse
from google.genai import types

from order_agent.streaming import WholeTurnGemini

TURN = [
    types.Part(text="Filling the order."),
    types.Part(function_call=types.FunctionCall(name="set_quantity", args={"sku": "A"})),
    types.Part(function_call=types.FunctionCall(name="set_quantity", args={"sku": "B"})),
    types.Part(function_call=types.FunctionCall(name="set_delivery", args={"date": "2026-10-23"})),
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


def calls(response: LlmResponse) -> list[str]:
    parts = response.content.parts if response.content else None
    return [
        p.function_call.args["sku"]
        if p.function_call.name == "set_quantity"
        else p.function_call.name
        for p in parts or []
        if p.function_call
    ]


def test_a_streamed_turn_brings_parallel_calls_in_one_chunk(whole_turn: list[bool]) -> None:
    streamed = responses(stream=True)

    partial = [calls(r) for r in streamed if r.partial and calls(r)]
    assert partial == [["A", "B", "set_delivery"]]
    assert calls(streamed[-1]) == ["A", "B", "set_delivery"]
    assert not streamed[-1].partial
    assert whole_turn == [False]


def test_the_text_streams_word_by_word(whole_turn: list[bool]) -> None:
    texts = [
        r.content.parts[0].text
        for r in responses(stream=True)
        if r.partial and r.content and r.content.parts[0].text
    ]

    assert texts == ["Filling ", "the ", "order."]


def test_an_unstreamed_request_gets_the_turn_as_is(whole_turn: list[bool]) -> None:
    assert [calls(r) for r in responses(stream=False)] == [["A", "B", "set_delivery"]]
