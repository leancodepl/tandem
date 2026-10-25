# Order desk agent on LangGraph

The order desk agent on [LangGraph](https://langchain-ai.github.io/langgraph/), over AG-UI with [ag-ui-langgraph](https://pypi.org/project/ag-ui-langgraph/). How to run it: [example/agents/README.md](../README.md).

## What LangGraph needs for Tandem

- ag-ui-langgraph puts the AG-UI `context` and `tools` into the graph's state, under `ag-ui`. The agent node ([graph.py](src/order_agent/graph.py)) puts the context into the system prompt and gives the model the tools.
- It also merges the `tools` of earlier runs into a `tools` key of the state. The graph's state has no such key, so the model gets only what the app lists now.
- The graph needs a checkpointer: on every run the adapter reads the thread from it and adds the messages it has not stored. `InMemorySaver` keeps threads in memory, with no expiry.
- The adapter takes only the first call of a streamed chunk, and the call's arguments only from the chunks after it. ChatOllama and Gemini send all the calls of a turn whole, in one chunk, so [streaming.py](src/order_agent/streaming.py) splits them. The model has to stream: without it, the app gets no calls.
- A call of the app's tools ends the run. The graph runs its own tools first, and ends when the model also called the app's.
- `interrupt()` in the graph ends the run with an interrupt, which Tandem does not support.
