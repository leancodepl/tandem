from datetime import date
from pathlib import Path
from typing import Literal

from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

_DEFAULT_MODELS = {"ollama": "qwen3.5:4b", "gemini": "gemini-3.8-flash"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="TANDEM_", env_ignore_empty=True)

    fake_llm: bool = False
    provider: Literal["ollama", "gemini"] = "ollama"
    model: str | None = None
    ollama_url: str = "http://127.0.0.1:11434"
    # Pinned so that "by Friday" in the demo e-mail is always 2026-10-23, as in the script.
    today: date = date(2026, 10, 16)
    host: str = "127.0.0.1"
    port: int = 8000

    @property
    def model_name(self) -> str:
        return self.model or _DEFAULT_MODELS[self.provider]


def load_settings() -> Settings:
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    return Settings()
