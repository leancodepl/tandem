import asyncio
from datetime import date
from types import SimpleNamespace

from ag_ui.core import Tool
from ag_ui_adk.client_proxy_tool import ClientProxyTool
from google.genai import types

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


def test_nullable_enum_survives_adk_declaration_conversion() -> None:
    tool = ClientProxyTool(
        Tool(
            name="stock",
            description="Stocks a product.",
            parameters={
                "type": "object",
                "properties": {
                    "size": {
                        "anyOf": [
                            {"type": "string", "enum": ["s", "m", "l"]},
                            {"type": "null"},
                        ]
                    }
                },
            },
        ),
        asyncio.Queue(),
    )

    declaration = tool._get_declaration()

    assert declaration is not None
    assert declaration.parameters is not None
    assert declaration.parameters.properties is not None
    size = declaration.parameters.properties["size"]
    assert size.any_of is not None
    assert [(item.type, item.enum) for item in size.any_of] == [
        (types.Type.STRING, ["s", "m", "l"]),
        (types.Type.NULL, None),
    ]
