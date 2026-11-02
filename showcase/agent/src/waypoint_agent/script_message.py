from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Call:
    name: str
    args: dict[str, Any]


@dataclass(frozen=True)
class Answer:
    name: str
    result: Any


Part = str | Call | Answer
Message = Sequence[Part]
