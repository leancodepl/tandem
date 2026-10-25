from collections.abc import Callable
from datetime import date

from google.adk.agents.readonly_context import ReadonlyContext
from order_desk.instruction import instruction


def build_instruction(today: date) -> Callable[[ReadonlyContext], str]:
    """An instruction provider: ag-ui-adk keeps the AG-UI `context` out of the prompt."""

    def provide(context: ReadonlyContext) -> str:
        return instruction(today, _screen(context))

    return provide


def _screen(context: ReadonlyContext) -> list[tuple[str, str]]:
    # Not the session state, where ag-ui-adk keeps a stale copy when a run has no context.
    metadata = context.run_config.custom_metadata if context.run_config else None
    entries = (metadata or {}).get("ag_ui_context", [])
    return [(entry["description"], entry["value"]) for entry in entries]
