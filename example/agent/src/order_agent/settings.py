from datetime import date

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="TANDEM_")

    fake_llm: bool = False
    model: str = "gemini-3.8-flash"
    # Pinned so that "by Friday" in the demo e-mail is always 2026-10-23, as in the script.
    today: date = date(2026, 10, 16)
    port: int = 8000
