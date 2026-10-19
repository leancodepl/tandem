# Order agent

The Google ADK agent of the Tandem demo app: it fills in a B2B order from an e-mail, together with
the user, over AG-UI ([ag-ui-adk](https://pypi.org/project/ag-ui-adk/)). To run it with the app,
see [example/README.md](../README.md).

Its own tools are `find_customer` and `get_order_history`. The order on the screen reaches the
model as the AG-UI `context` of each run, and the app's methods as the run's `tools`, so the
agent changes the order only through the app.

Needs [uv](https://docs.astral.sh/uv/). Run the commands below in `example/agent`.

## Run

With the scripted model, which needs no API key and no network:

```sh
TANDEM_FAKE_LLM=1 uv run order-agent
```

With Gemini, after copying [.env.example](.env.example) to `.env` and setting `GOOGLE_API_KEY` in
it:

```sh
uv run order-agent
```

By default the server listens on `127.0.0.1:8000`, with the AG-UI endpoint at `POST /agent`.
Sessions live in memory, so a restart forgets every thread.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `TANDEM_FAKE_LLM` | | `1` swaps in the scripted model. |
| `TANDEM_MODEL` | `gemini-3.8-flash` | Any Gemini model name. |
| `TANDEM_TODAY` | `2026-10-16` | The demo's today, so "by Friday" is 2026-10-23. |
| `TANDEM_HOST` | `127.0.0.1` | The address to listen on. Only a physical device needs `0.0.0.0`: an emulator or a simulator reaches `127.0.0.1`. With `0.0.0.0`, anyone on your network can use the agent, which has no sign-in and spends your API key. |
| `TANDEM_PORT` | `8000` | The port to listen on. |
| `GOOGLE_API_KEY` | | The Gemini API key, also read from `.env`. |

## The script

What the scripted model ([src/order_agent/scripted](src/order_agent/scripted)) plays when the
order desk of the gallery ([example/README.md](../README.md)) sends it the sample e-mail.

| # | You | The agent | The screen |
|---|---|---|---|
| 1 | Tap the sample e-mail | `find_customer`, `get_order_history` | Nothing yet |
| 2 | | `set_customer`, two times `search_catalog` | The customer card fills in |
| 3 | | "I assumed the ProView 27Q, as in your September order ORD-0987." `set_quantity` for both products, `set_delivery` | Lines, prices, address and date appear |
| 4 | | "40 HDMI cables and 12 ProView 27Q monitors, delivered on 23 Oct. Total 14 349.44 PLN. Shall I place it?" | |
| 5 | Tap + on the monitors until 15, type `Looks good, place it` | "You changed the monitors to 15, which unlocks Acme's 15+ tier (17 % off monitors)." `place_order` | Prices update on each tap; an approval card |
| 6 | Tap Approve | "Order ORD-1042 placed for 23 Oct." | The card shows Approved; the order stays, marked "Placed as ORD-1042", read-only for the user and the agent |

Instead of 6, change the delivery date while the card is open: the card says the screen changed.
Type `Place it` for a new card, and tap Reject: the agent answers "OK, I won't place it."

## Checks

```sh
uv run pytest
uv run ruff check
uv run ruff format --check
```

The tests play the script over HTTP with the scripted model, through a client that talks to the
agent the way Tandem's session does ([tests/tandem_thread.py](tests/tandem_thread.py)). CI runs all
three.
