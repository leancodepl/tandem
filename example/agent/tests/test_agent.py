from datetime import date
from types import SimpleNamespace

from order_agent.agent import build_app
from order_agent.instruction import build_instruction
from order_agent.settings import Settings
from order_agent.streaming import WholeTurnGemini


def test_the_instruction_tells_the_model_the_weekday_of_today() -> None:
    instruction = build_instruction(date(2026, 10, 16))
    context = SimpleNamespace(run_config=SimpleNamespace(custom_metadata=None))

    assert "Today is Friday, 16 October 2026." in instruction(context)


def test_gemini_streams_whole_turns() -> None:
    model = build_app(Settings(fake_llm=False)).root_agent.canonical_model

    assert isinstance(model, WholeTurnGemini)
