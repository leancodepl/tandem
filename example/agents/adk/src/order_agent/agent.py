from adk_streaming import WholeTurnGemini
from ag_ui_adk import AGUIToolset
from google.adk.agents import LlmAgent
from google.adk.apps import App, ResumabilityConfig
from google.adk.models import BaseLlm
from google.adk.models.lite_llm import LiteLlm
from google.genai import types
from order_desk.tools import find_customer, get_order_history

from order_agent.instruction import build_instruction
from order_agent.scripted import ScriptedOrderLlm
from order_agent.settings import Settings

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
    if settings.provider == "ollama":
        # Thinking makes a small model 3 to 4 times slower, for no better calls in the demo.
        return LiteLlm(
            model=f"ollama_chat/{settings.model_name}",
            api_base=settings.ollama_url,
            reasoning_effort="none",
        )
    return WholeTurnGemini(model=settings.model_name, retry_options=_RETRY)
