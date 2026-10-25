from typing import Annotated, Any, TypedDict

from ag_ui.core import Context
from langchain_core.language_models import BaseChatModel
from langchain_core.messages import AIMessage, AnyMessage, SystemMessage
from langchain_core.runnables import RunnableConfig
from langchain_core.tools import BaseTool, tool
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_ollama import ChatOllama
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.checkpoint.serde.jsonplus import JsonPlusSerializer
from langgraph.graph import END, START, StateGraph
from langgraph.graph.message import add_messages
from langgraph.graph.state import CompiledStateGraph
from order_desk.instruction import instruction
from order_desk.tools import find_customer, get_order_history

from order_agent.scripted import ScriptedChatModel
from order_agent.settings import Settings
from order_agent.streaming import OneCallPerChunk

_SERVER_TOOLS: dict[str, BaseTool] = {
    t.name: t
    for t in (
        tool(find_customer, parse_docstring=True),
        tool(get_order_history, parse_docstring=True),
    )
}

# No top-level "tools" key: ag-ui-langgraph would merge the tools of earlier runs into it, and the
# model would see methods the app no longer lists. "ag-ui" holds this run's `tools` and `context`.
State = TypedDict(
    "State",
    {"messages": Annotated[list[AnyMessage], add_messages], "ag-ui": dict[str, Any]},
)


def build_graph(settings: Settings) -> CompiledStateGraph:
    model = _model(settings)

    async def agent(state: State, config: RunnableConfig) -> dict:
        ag_ui = state["ag-ui"]
        prompt = instruction(settings.today, [_entry(e) for e in ag_ui.get("context", [])])
        bound = model.bind_tools([*_SERVER_TOOLS.values(), *ag_ui.get("tools", [])])
        reply = await bound.ainvoke([SystemMessage(prompt), *state["messages"]], config)
        return {"messages": [reply]}

    async def server_tools(state: State, config: RunnableConfig) -> dict:
        calls = [c for c in _calls(state) if c["name"] in _SERVER_TOOLS]
        return {"messages": [await _SERVER_TOOLS[c["name"]].ainvoke(c, config) for c in calls]}

    graph = StateGraph(State)
    graph.add_node("agent", agent)
    graph.add_node("server_tools", server_tools)
    graph.add_edge(START, "agent")
    graph.add_conditional_edges("agent", _after_agent, ["server_tools", END])
    graph.add_conditional_edges("server_tools", _after_server_tools, ["agent", END])
    # The adapter reads and dedupes the thread's history from the checkpoint on every run. It keeps
    # the run's `context` there as ag_ui objects, which a checkpoint reads only when allowed.
    serde = JsonPlusSerializer(allowed_msgpack_modules=[(Context.__module__, Context.__name__)])
    return graph.compile(checkpointer=InMemorySaver(serde=serde))


def _after_agent(state: State) -> str:
    return "server_tools" if any(c["name"] in _SERVER_TOOLS for c in _calls(state)) else END


def _after_server_tools(state: State) -> str:
    """The run ends with the calls of the app's tools, which the app answers in the next run."""
    calls = [m for m in state["messages"] if isinstance(m, AIMessage)][-1].tool_calls
    return END if any(c["name"] not in _SERVER_TOOLS for c in calls) else "agent"


def _calls(state: State) -> list[dict]:
    last = state["messages"][-1]
    return last.tool_calls if isinstance(last, AIMessage) else []


def _entry(entry: Any) -> tuple[str, str]:
    if isinstance(entry, dict):
        return entry["description"], entry["value"]
    return entry.description, entry.value


def _model(settings: Settings) -> BaseChatModel:
    if settings.fake_llm:
        return ScriptedChatModel(today=settings.today)
    if settings.provider == "ollama":
        # Thinking makes a small model 3 to 4 times slower, for no better calls in the demo.
        return _Ollama(model=settings.model_name, base_url=settings.ollama_url, reasoning=False)
    return _Gemini(model=settings.model_name, max_retries=6)


class _Ollama(OneCallPerChunk, ChatOllama):
    pass


class _Gemini(OneCallPerChunk, ChatGoogleGenerativeAI):
    pass
