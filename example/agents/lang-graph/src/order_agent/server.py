import uvicorn
from ag_ui_langgraph import LangGraphAgent, add_langgraph_fastapi_endpoint
from fastapi import FastAPI

from order_agent.graph import build_graph
from order_agent.settings import Settings, load_settings


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(title="Tandem demo agent")
    agent = LangGraphAgent(name="order_agent", graph=build_graph(settings))
    add_langgraph_fastapi_endpoint(app, agent, path="/agent")
    return app


def main() -> None:
    settings = load_settings()
    uvicorn.run(create_app(settings), host=settings.host, port=settings.port)
