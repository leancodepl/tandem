# Order desk agent on Google ADK

The order desk agent on [Google ADK](https://google.github.io/adk-docs/), over AG-UI with [ag-ui-adk](https://pypi.org/project/ag-ui-adk/). How to run it: [example/agents/README.md](../README.md).

## What ADK needs for Tandem

- ag-ui-adk keeps the AG-UI `context` out of the prompt, in the metadata of the run. An instruction provider ([instruction.py](src/order_agent/instruction.py)) puts it into the instruction of every model call.
- ag-ui-adk drops a call whose name repeats a call of an earlier chunk of the same run. Gemini streams parallel calls in separate chunks, so [streaming.py](src/order_agent/streaming.py) asks for the whole turn and streams it in one piece. LiteLLM, which reaches Ollama, sends all the calls of a turn in one chunk already.
- ag-ui-adk keeps each thread in a session of its own, in memory, and forgets it after 20 minutes without a run. Then, as after a restart, it reads the conversation from the app. A session lost while the answers of the app are on their way starts the turn again from the user's message.
- LiteLLM 1.106 fails every call with tools unless the `mcp` package is installed, so the agent stays on 1.105.
