import pytest
from adk_streaming import WholeTurnGemini

from waypoint_agent import agent
from waypoint_agent.instruction import Screen
from waypoint_agent.settings import Settings


@pytest.mark.parametrize("screen", Screen)
def test_real_agent_uses_the_requested_model_without_scripted_fallback(
    screen: Screen, monkeypatch: pytest.MonkeyPatch
) -> None:
    def reject_scripted_model(**kwargs: object) -> None:
        pytest.fail("A real agent must never select the scripted model.")

    monkeypatch.setattr(agent, "ScriptedLlm", reject_scripted_model)

    app = agent.build_app(Settings(fake_llm=False, model="requested-gemini"), screen)

    assert isinstance(app.root_agent.model, WholeTurnGemini)
    assert app.root_agent.model.model == "requested-gemini"


def test_real_model_configuration_errors_do_not_select_a_script(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fail_real_model(**kwargs: object) -> None:
        raise ValueError("Invalid model configuration.")

    def reject_scripted_model(**kwargs: object) -> None:
        pytest.fail("A model error must not fall back to a script.")

    monkeypatch.setattr(agent, "WholeTurnGemini", fail_real_model)
    monkeypatch.setattr(agent, "ScriptedLlm", reject_scripted_model)

    with pytest.raises(ValueError, match="Invalid model configuration"):
        agent.build_app(Settings(fake_llm=False), Screen.TRIP)
