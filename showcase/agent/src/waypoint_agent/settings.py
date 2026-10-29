from datetime import date
from pathlib import Path
from typing import Literal

from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="WAYPOINT_", env_ignore_empty=True)

    fake_llm: bool = False
    model: str = "gemini-3.8-flash"
    # Low still plans a reschedule and keeps a turn within seconds.
    thinking: Literal["minimal", "low", "medium", "high"] = "low"
    # The trip's week, as the app's today is.
    today: date = date(2026, 10, 24)
    host: str = "127.0.0.1"
    port: int = 8010


def load_settings() -> Settings:
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    return Settings()
