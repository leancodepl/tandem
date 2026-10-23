---
name: tandem-coding-agent
description: Fill in or change a screen of a running Flutter debug app that uses Tandem, such as a form, through the methods its state class lists, and set up TandemBridge so a coding agent can. Use when asked to fill a Flutter form or screen from a text, an e-mail or a ticket, or to let the coding agent drive the app.
user-invocable: false
---

# Drive a Tandem screen as the coding agent

You, the coding agent, call the methods a Tandem screen lists, in the running debug app: the same setters the screen's widgets call, with the same checks and approvals. No backend, no API key, no chat. The screen needs a `TandemScope` around a state class with `@TandemAgent()`; if it has none, follow `tandem-agent-aware-screen` first.

The app answers through two VM service extensions: `ext.tandem.describe` and `ext.tandem.call`. Use them, not the widget inspector, Flutter Driver or taps on the widgets. Do the steps in order and check each "Done when" before the next.

## 1. Enable the bridge

Add one line at the start of `main()`, before `runApp`:

```dart
void main() {
  TandemBridge.enable();
  runApp(const App());
}
```

- Find the entry point the user runs: `lib/main.dart`, or a flavor such as `lib/main_dev.dart`. Look for `-t`, `--target` or `program` in `.vscode/launch.json`, `.run/` and the scripts. When there are several, ask the user which ones get the line.
- A profile or release build ignores the line, so it may stay in an entry point that release builds use too.
- `TandemBridge.enable(autoApprove: true)` lets you approve your own calls of `.callsWithApproval` methods, without the user. Add it only when the user asks for it, such as for a scripted run, and say what it lets you do.

**Done when** the entry point the user runs calls `TandemBridge.enable()`.

## 2. Reach the running app

You need the VM service address of the app in debug mode, such as `http://127.0.0.1:50300/Xq3uEv7mT1c=/`. `flutter run` prints it as "A Dart VM Service on … is available at", and so does the debug console of the IDE.

- The user runs the app: ask for the address. After the change of step 1, the app needs a hot restart or a new start, since hot reload does not run `main()` again.
- You start the app: run it in the background with `flutter run -d <device> --vmservice-out-file=build/tandem_vm_service.txt`, and wait until that file has the address. The first build takes a minute or two. `flutter devices` lists the devices. On a desktop host with that platform enabled, its desktop device builds fastest; otherwise ask. The file has the WebSocket form of the address, such as `ws://127.0.0.1:50300/Xq3uEv7mT1c=/ws`.
- When the address stops answering, the app has stopped, such as with the end of your session's turn: start it again.

Call the extensions in one of two ways:

- **With the Dart MCP server** (`dart mcp-server`), when its `vm_service` tool is among your tools. Connect with `{"command": "connect", "appUri": "ws://127.0.0.1:50300/Xq3uEv7mT1c=/ws"}`: the address with `ws://` and `ws` at the end. Then `{"command": "callMethod", "method": "getVM"}` gives the isolates. Call each extension with `"command": "callMethod"`, its name as `method`, the `isolateId` and its parameters in `arguments`.
- **With HTTP**, in any shell. Append the method to the address and pass the parameters in the query:

  ```sh
  VM=http://127.0.0.1:50300/Xq3uEv7mT1c=/
  curl -s "${VM}getVM"
  curl -s -G "${VM}ext.tandem.describe" --data-urlencode "isolateId=isolates/123"
  ```

  The answer is JSON-RPC: what the app returns is under `result`. On Windows, call `curl.exe`.

Take the isolate named `main` from `getVM`.

**Done when** `ext.tandem.describe` answers, and its `screens` include the screen to fill. An unknown method means the bridge is not enabled in the running code: check step 1 and restart the app. An empty `screens` means no `TandemScope` is open: ask the user to open the screen.

## 3. Fill in the screen

`ext.tandem.describe` gives every open screen with its `id`, whether it is `front`, what it `sees`, the `tools` it lists with their JSON Schemas, and which of them `needsApproval`.

`ext.tandem.call` calls one tool. Its parameters are `tool`, `arguments` as a JSON object in a string, and `screen` with an id when more than one screen is open:

```sh
curl -s -G "${VM}ext.tandem.call" \
  --data-urlencode "isolateId=isolates/123" \
  --data-urlencode "tool=set_quantity" \
  --data-urlencode 'arguments={"sku": "VM-27Q", "quantity": 15}'
```

With the MCP tool, the same call has `"arguments": {"tool": "set_quantity", "arguments": "{\"sku\": \"VM-27Q\", \"quantity\": 15}"}`.

- Fill only what the source text states. Leave a field as it is when the text does not say, and never invent a value, an id or a date to fill a gap.
- Call only the listed tools, with arguments that fit their schemas. Read the `screens` of every answer: the tools change with the state, so a method can appear once the form is complete.
- A value the text gives but no tool takes, such as a password, stays with the user: tell them to type it.
- Call a tool from `needsApproval` only when the user asked for that action. Before the call, tell the user the app will ask them to approve it.

Every answer has a `status`, and the `screens` as they are after the call:

| `status` | What to do |
|---|---|
| `returned` | Done. `result` is what the method returned. |
| `refused` | Read `reason`. Fix the arguments when it says how, pass `screen` when it lists ids, otherwise leave the field and tell the user. |
| `failed`, `result_unavailable` | The method threw, or its result cannot be read: the app may have changed. Read `screens`, and tell the user. |
| `rejected_by_user` | The user said no. Do not call it again unless they ask. |
| `invalidated` | What the screen shows changed while the request waited. Read `screens`, and ask the user before you call it again. |
| `cancelled` | The user wrote to the in-app agent, started over or closed the screen. Tell the user. |

**Done when** every value the text states is set, the `sees` of the last answer shows them, and you told the user what you set, what you left and why, and what waits for them.

## 4. Wait for an approval

A call of a `.callsWithApproval` method waits until the user decides in the app, unless the bridge has `autoApprove: true`. The request shows once the in-app agent's own requests are decided. A screen with `approvals: .none()` refuses the call. Your call can time out first:

- Claude Code waits up to 30 minutes for the Dart MCP server. In an interactive session it moves the call to the background after 2 minutes and tells you the result later.
- Codex CLI stops after 60 seconds, unless `tool_timeout_sec` of the server in `config.toml` is longer. Cursor's CLI stops after 60 seconds.
- A shell command stops at the timeout of your shell tool. Run the `curl` in the background, or give the command a longer timeout.

The request keeps waiting in the app after your call timed out. Then:

1. Call `ext.tandem.describe` first. The screen's `lastApproval` has the `tool`, the `arguments` and the `status` of your last request: `pending` while it waits for the user, `approved` while the method runs, then the answer as in the table of step 3.
2. When it is your call and has an answer, report it. Calling again would run the method a second time, such as a second order.
3. When it is `pending` or `approved`, call the same tool with the same arguments: the call waits for the same answer. Another call that needs approval is refused while one waits.

**Done when** you reported the user's decision, or told them the request still waits in the app.
