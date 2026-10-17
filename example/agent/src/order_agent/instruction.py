from collections.abc import Callable
from datetime import date
from pathlib import Path

from google.adk.agents.readonly_context import ReadonlyContext

_TEMPLATE = Path(__file__).with_name("instruction.txt").read_text()


def build_instruction(today: date) -> Callable[[ReadonlyContext], str]:
    def instruction(context: ReadonlyContext) -> str:
        return _TEMPLATE.format(today=today, screen=_screen(context))

    return instruction


def _screen(context: ReadonlyContext) -> str:
    # Not the session state, where ag-ui-adk keeps a stale copy when a run has no context.
    metadata = context.run_config.custom_metadata if context.run_config else None
    entries = (metadata or {}).get("ag_ui_context", [])
    return "\n".join("- {description}: {value}".format_map(entry) for entry in entries)
