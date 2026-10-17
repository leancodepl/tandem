from ag_ui_adk import AGUIToolset
from google.adk.agents import LlmAgent
from google.adk.apps import App, ResumabilityConfig
from google.adk.models import BaseLlm
from google.genai import types

from order_agent.instruction import build_instruction
from order_agent.scripted.llm import ScriptedOrderLlm
from order_agent.settings import Settings
from order_agent.streaming import WholeTurnGemini
from order_agent.tools import find_customer, get_order_history

# The free tier answers 503 "high demand" and 429 in bursts.
_RETRY = types.HttpRetryOptions(
    attempts=6, initial_delay=2, max_delay=30, http_status_codes=[429, 503]
)


def build_app(settings: Settings) -> App:
    agent = LlmAgent(
        name="order_agent",
        model=_model(settings),
        instruction=build_instruction(settings.today),
        tools=[find_customer, get_order_history, AGUIToolset()],
    )
    return App(
        name="tandem_demo",
        root_agent=agent,
        resumability_config=ResumabilityConfig(is_resumable=True),
    )


def _model(settings: Settings) -> BaseLlm:
    if settings.fake_llm:
        return ScriptedOrderLlm(today=settings.today)
    return WholeTurnGemini(model=settings.model, retry_options=_RETRY)
