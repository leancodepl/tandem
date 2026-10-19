import uvicorn
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint
from fastapi import FastAPI

from order_agent.agent import build_app
from order_agent.settings import Settings, load_settings


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(title="Tandem demo agent")
    agent = ADKAgent.from_app(build_app(settings), use_in_memory_services=True)
    add_adk_fastapi_endpoint(app, agent, path="/agent")
    return app


def main() -> None:
    settings = load_settings()
    uvicorn.run(create_app(settings), host=settings.host, port=settings.port)
