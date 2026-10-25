# Order desk agent on Pydantic AI

The order desk agent on [Pydantic AI](https://ai.pydantic.dev/), over its built-in AG-UI adapter. How to run it: [example/agents/README.md](../README.md).

## What Pydantic AI needs for Tandem

- Pydantic AI keeps the AG-UI `context` out of the prompt on purpose: it is what the client claims. The endpoint ([server.py](src/order_agent/server.py)) passes it to the run as `deps`, and an instruction ([agent.py](src/order_agent/agent.py)) puts it into the prompt.
- Pydantic AI keeps no state: the messages of each run are the whole conversation.
- A call of the app's tools ends the run as a deferred call, and its answer comes with the next run.
- `ModelSettings(thinking=False)` does not reach Ollama. `openai_reasoning_effort="none"` does.
- Pydantic AI 2.61 speaks AG-UI below 1.0, with `ag-ui-protocol` 0.1.
