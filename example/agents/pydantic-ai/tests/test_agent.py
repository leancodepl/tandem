import pytest
from google.genai.types import FunctionCallingConfigMode
from pydantic_ai.models import ModelRequestParameters
from pydantic_ai.tools import ToolDefinition

from order_agent.agent import build_agent
from order_agent.settings import Settings

# Tandem's tandem_show_view: its A2UI messages are objects without a schema.
_SHOW_VIEW = ToolDefinition(
    name="tandem_show_view",
    parameters_json_schema={
        "type": "object",
        "properties": {"messages": {"type": "array", "items": {"type": "object"}}},
        "required": ["messages"],
    },
)


def test_gemini_calls_tools_without_schema_enforcement(monkeypatch: pytest.MonkeyPatch) -> None:
    # In VALIDATED mode Gemini writes each component of tandem_show_view as a string, such as
    # "{child:body,component:Card,id:root}".
    monkeypatch.setenv("GOOGLE_API_KEY", "not-used")
    model = build_agent(Settings(provider="gemini")).model

    _, config, _ = model._get_tool_config(ModelRequestParameters(function_tools=[_SHOW_VIEW]), {})

    assert config["function_calling_config"]["mode"] == FunctionCallingConfigMode.AUTO
