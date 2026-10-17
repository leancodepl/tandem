import os
from pathlib import Path

import uvicorn
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from order_agent.agent import build_app

DEFAULT_PORT = "8000"


def create_app() -> FastAPI:
    app = FastAPI(title="Tandem demo agent")
    app.add_middleware(
        CORSMiddleware,
        # Lets the app call the agent from a browser on localhost.
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_methods=["*"],
        allow_headers=["*"],
    )
    agent = ADKAgent.from_app(build_app(), use_in_memory_services=True)
    add_adk_fastapi_endpoint(app, agent, path="/agent")

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


def main() -> None:
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    uvicorn.run(create_app(), host="127.0.0.1", port=int(os.environ.get("PORT", DEFAULT_PORT)))
