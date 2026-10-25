from collections.abc import Iterable
from datetime import date
from pathlib import Path

_TEMPLATE = Path(__file__).with_name("instruction.txt").read_text()


def instruction(today: date, screen: Iterable[tuple[str, str]]) -> str:
    """The system instruction, with the run's AG-UI `context` as (description, value) pairs."""
    lines = "\n".join(f"- {description}: {value}" for description, value in screen)
    return _TEMPLATE.format(today=today, screen=lines)
