# Order desk agents

The order desk of the example app ([example/README.md](../README.md)) on the three agent frameworks that Tandem is checked with:

| Folder | Framework | AG-UI |
|---|---|---|
| [adk](adk) | [Google ADK](https://google.github.io/adk-docs/) | [ag-ui-adk](https://pypi.org/project/ag-ui-adk/) |
| [lang-graph](lang-graph) | [LangGraph](https://langchain-ai.github.io/langgraph/) | [ag-ui-langgraph](https://pypi.org/project/ag-ui-langgraph/) |
| [pydantic-ai](pydantic-ai) | [Pydantic AI](https://ai.pydantic.dev/) | built in |

Each agent fills in a B2B order from an e-mail, together with the user, over AG-UI. Its own tools are `find_customer` and `get_order_history`. The order on the screen reaches the model as the AG-UI `context` of each run, and the app's methods as the run's `tools`, so the agent changes the order only through the app. The README of each agent says what its framework needs for that.

[order-desk](order-desk) holds what the three share: the customers, the two tools, the instruction, the script of the scripted model and the tests.

Needs [uv](https://docs.astral.sh/uv/). Run the commands below in the folder of an agent.

## Run

With the scripted model, which needs no model and no API key:

```sh
TANDEM_FAKE_LLM=1 uv run order-agent
```

With [Ollama](https://ollama.com), after `ollama pull qwen3.5:4b` (3.3 GB):

```sh
uv run order-agent
```

A model this small takes 5 to 20 s per step on a Mac with Apple silicon, and sometimes needs a nudge, such as the delivery date. Thinking is off: it makes a small model 3 to 4 times slower.

With Gemini, after copying `.env.example` to `.env` and setting `GOOGLE_API_KEY` in it, which also sets `TANDEM_PROVIDER=gemini`:

```sh
uv run order-agent
```

The server listens on `127.0.0.1:8000`, with the AG-UI endpoint at `POST /agent`. Threads live in memory, so a restart forgets them.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `TANDEM_FAKE_LLM` | | `1` swaps in the scripted model. |
| `TANDEM_PROVIDER` | `ollama` | `ollama` or `gemini`. |
| `TANDEM_MODEL` | `qwen3.5:4b`, `gemini-3.8-flash` | The provider's model name. |
| `TANDEM_OLLAMA_URL` | `http://127.0.0.1:11434` | Where Ollama listens. |
| `TANDEM_TODAY` | `2026-10-16` | The demo's today, so "by Friday" is 2026-10-23. |
| `TANDEM_HOST` | `127.0.0.1` | The address to listen on. Only a physical device needs `0.0.0.0`: an emulator or a simulator reaches `127.0.0.1`. With `0.0.0.0`, anyone on your network can use the agent, which has no sign-in and spends your API key. |
| `TANDEM_PORT` | `8000` | The port to listen on. |
| `GOOGLE_API_KEY` | | The Gemini API key, also read from `.env`. |

## The script

What the scripted model ([order-desk/src/order_desk/script.py](order-desk/src/order_desk/script.py)) plays when the order desk sends it the sample e-mail.

| # | You | The agent | The screen |
|---|---|---|---|
| 1 | Tap the sample e-mail | `find_customer`, `get_order_history` | Nothing yet |
| 2 | | `set_customer`, two times `search_catalog` | The customer card fills in |
| 3 | | "I assumed the ProView 27Q, as in your September order ORD-0987." `set_quantity` for both products, `set_delivery` | Lines, prices, address and date appear |
| 4 | | "40 HDMI cables and 12 ProView 27Q monitors, delivered on 23 Oct. Total 14 349.44 PLN. Shall I place it?" | |
| 5 | Tap + on the monitors until 15, type `Looks good, place it` | "You changed the monitors to 15, which unlocks Acme's 15+ tier (17 % off monitors)." `place_order` | Prices update on each tap; an approval card |
| 6 | Tap Approve | "Order ORD-1042 placed for 23 Oct." | The card shows Approved; the order stays, marked "Placed as ORD-1042", read-only for the user and the agent |

Instead of 6, change the delivery date while the card is open: the card says the screen changed. Type `Place it` for a new card, and tap Reject: the agent answers "OK, I won't place it."

## Checks

```sh
uv sync --locked
uv run ruff check . ../order-desk
uv run ruff format --check . ../order-desk
uv run pytest
```

The tests of [order-desk/tests](order-desk/tests) play the script over HTTP with the scripted model, through a client that keeps the thread the way Tandem's session does ([tandem_thread.py](order-desk/tests/tandem_thread.py)). Each agent runs them, and its own tests in `tests`. CI runs the checks for each agent.
