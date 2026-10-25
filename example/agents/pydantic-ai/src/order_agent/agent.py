from dataclasses import dataclass

from order_desk.instruction import instruction
from order_desk.tools import find_customer, get_order_history
from pydantic_ai import Agent, RunContext
from pydantic_ai.models import Model
from pydantic_ai.models.google import GoogleModel
from pydantic_ai.models.ollama import OllamaModel
from pydantic_ai.models.openai import OpenAIChatModelSettings
from pydantic_ai.profiles.google import GoogleModelProfile
from pydantic_ai.providers.ollama import OllamaProvider

from order_agent.scripted import scripted_model
from order_agent.settings import Settings


@dataclass(frozen=True)
class Screen:
    """The run's AG-UI `context` as (description, value) pairs."""

    entries: list[tuple[str, str]]


def build_agent(settings: Settings) -> Agent[Screen, str]:
    agent = Agent(
        _model(settings),
        deps_type=Screen,
        tools=[find_customer, get_order_history],
    )

    # Pydantic AI keeps the AG-UI `context` out of the prompt: it is what the client claims.
    @agent.instructions
    def with_screen(ctx: RunContext[Screen]) -> str:
        return instruction(settings.today, ctx.deps.entries)

    return agent


def _model(settings: Settings) -> Model:
    if settings.fake_llm:
        return scripted_model(settings.today)
    if settings.provider == "ollama":
        provider = OllamaProvider(base_url=f"{settings.ollama_url}/v1")
        # Thinking makes a small model 3 to 4 times slower, for no better calls in the demo.
        # `thinking=False` does not reach Ollama; this does.
        no_thinking = OpenAIChatModelSettings(openai_reasoning_effort="none")
        return OllamaModel(settings.model_name, provider=provider, settings=no_thinking)
    # Off Gemini's VALIDATED mode, which writes the open objects of tandem_show_view as strings.
    no_schema_enforcement = GoogleModelProfile(google_supports_strict_tool_definition=False)
    return GoogleModel(settings.model_name, profile=no_schema_enforcement)
