from adk_streaming import WholeTurnGemini
from ag_ui_adk import AGUIToolset
from google.adk.agents import LlmAgent
from google.adk.apps import App, ResumabilityConfig
from google.adk.models import BaseLlm
from google.genai import types

from waypoint_agent.instruction import Screen, build_instruction
from waypoint_agent.scripted import ScriptedLlm
from waypoint_agent.settings import Settings

# The free tier answers 503 "high demand" and 429 in bursts.
_RETRY = types.HttpRetryOptions(
    attempts=6, initial_delay=2, max_delay=30, http_status_codes=[429, 503]
)


def build_app(settings: Settings, screen: Screen) -> App:
    """The agent of one screen. Each screen has its own instruction, because the trip's rules
    make the model slow on the booking form. All its tools are the app's, so the screen changes
    only through the app's methods."""
    agent = LlmAgent(
        name=f"waypoint_{screen}",
        model=_model(settings, screen),
        instruction=build_instruction(screen, settings.today),
        tools=[AGUIToolset()],
        generate_content_config=types.GenerateContentConfig(
            thinking_config=types.ThinkingConfig(
                thinking_level=types.ThinkingLevel(settings.thinking.upper())
            ),
        ),
    )
    return App(
        name=f"waypoint_{screen}",
        root_agent=agent,
        resumability_config=ResumabilityConfig(is_resumable=True),
    )


def _model(settings: Settings, screen: Screen) -> BaseLlm:
    if settings.fake_llm:
        return ScriptedLlm(screen=screen)
    return WholeTurnGemini(model=settings.model, retry_options=_RETRY)
