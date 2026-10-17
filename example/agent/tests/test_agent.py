from datetime import date
from types import SimpleNamespace

import pytest
from google.genai import types

from order_agent.agent import build_app
from order_agent.instruction import build_instruction
from order_agent.streaming import WholeTurnGemini

ORDER = {
    "description": "order: The order as the user sees it on the screen.",
    "value": '{"customer":null,"lines":[],"delivery":null,"total":"0.00 PLN"}',
}


def context(entries: list[dict] | None) -> SimpleNamespace:
    metadata = {"ag_ui_context": entries} if entries else None
    return SimpleNamespace(run_config=SimpleNamespace(custom_metadata=metadata))


def test_the_instruction_has_today_and_the_screen_of_this_run() -> None:
    instruction = build_instruction(date(2026, 10, 16))

    text = instruction(context([ORDER]))

    assert "Today is Friday, 16 October 2026." in text
    assert f"- {ORDER['description']}: {ORDER['value']}" in text
    assert "- order:" not in instruction(context(None))


@pytest.fixture
def gemini_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TANDEM_FAKE_LLM", raising=False)
    monkeypatch.delenv("TANDEM_MODEL", raising=False)


@pytest.mark.usefixtures("gemini_env")
def test_gemini_retries_the_busy_free_tier(monkeypatch: pytest.MonkeyPatch) -> None:
    app = build_app()
    model = app.root_agent.canonical_model

    assert isinstance(model, WholeTurnGemini)
    assert model.model == "gemini-3.8-flash"
    assert model.retry_options == types.HttpRetryOptions(
        attempts=6, initial_delay=2, max_delay=30, http_status_codes=[429, 503]
    )
    assert app.resumability_config.is_resumable
    tools = [getattr(tool, "__name__", type(tool).__name__) for tool in app.root_agent.tools]
    assert tools == ["find_customer", "get_order_history", "AGUIToolset"]

    monkeypatch.setenv("TANDEM_MODEL", "gemini-3.1-pro-preview")
    assert build_app().root_agent.canonical_model.model == "gemini-3.1-pro-preview"
