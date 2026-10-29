from collections.abc import Callable
from datetime import date
from enum import StrEnum
from pathlib import Path

from google.adk.agents.readonly_context import ReadonlyContext


class Screen(StrEnum):
    """A screen of the app with an agent of its own."""

    TRIP = "trip"
    BOOKING = "booking"
    PLAN = "plan"
    EXPENSES = "expenses"
    ARRIVAL = "arrival"


def build_instruction(screen: Screen, today: date) -> Callable[[ReadonlyContext], str]:
    """An instruction provider: ag-ui-adk keeps the AG-UI `context` out of the prompt."""
    template = Path(__file__).with_name(f"{screen}.txt").read_text()

    def provide(context: ReadonlyContext) -> str:
        return template.format(today=today, screen=_screen(context))

    return provide


def _screen(context: ReadonlyContext) -> str:
    # Not the session state, where ag-ui-adk keeps a stale copy when a run has no context.
    metadata = context.run_config.custom_metadata if context.run_config else None
    entries = (metadata or {}).get("ag_ui_context", [])
    return "\n".join(f"- {entry['description']}: {entry['value']}" for entry in entries)
