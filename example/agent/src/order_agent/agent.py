"""The order agent and the ADK app around it."""

import os
from datetime import date

from ag_ui_adk import AGUIToolset
from google.adk.agents import LlmAgent
from google.adk.apps import App, ResumabilityConfig
from google.adk.models import BaseLlm
from google.genai import types

from order_agent.instruction import build_instruction
from order_agent.scripted_llm import ScriptedOrderLlm
from order_agent.streaming import WholeTurnGemini
from order_agent.tools import find_customer, get_order_history

DEFAULT_MODEL = "gemini-3.8-flash"
# Pinned, so that "by Friday" in the demo e-mail is always 2026-10-23, as in the script.
DEFAULT_TODAY = "2026-10-16"

# The free tier answers 503 "high demand" and 429 in bursts.
_RETRY = types.HttpRetryOptions(
    attempts=6, initial_delay=2, max_delay=30, http_status_codes=[429, 503]
)


def today_from_env() -> date:
    """The demo's today, `TANDEM_TODAY`, so that "by Friday" is always the same date."""
    return date.fromisoformat(os.environ.get("TANDEM_TODAY", DEFAULT_TODAY))


def model_from_env(today: date) -> BaseLlm:
    """The scripted model with `TANDEM_FAKE_LLM=1`, otherwise Gemini as `TANDEM_MODEL`."""
    if os.environ.get("TANDEM_FAKE_LLM") == "1":
        return ScriptedOrderLlm(today=today)
    return WholeTurnGemini(
        model=os.environ.get("TANDEM_MODEL", DEFAULT_MODEL), retry_options=_RETRY
    )


def build_app() -> App:
    """The app from the environment; resumable, as ag-ui-adk needs for the app's tools."""
    today = today_from_env()
    agent = LlmAgent(
        name="order_agent",
        model=model_from_env(today),
        instruction=build_instruction(today),
        # AGUIToolset stands for the app's tools, which come with every run.
        tools=[find_customer, get_order_history, AGUIToolset()],
    )
    return App(
        name="tandem_demo",
        root_agent=agent,
        resumability_config=ResumabilityConfig(is_resumable=True),
    )
