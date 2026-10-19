# Tandem examples

Six screens on bloc, Riverpod and provider, in one gallery app. Edit the screen yourself, let the
agent act, and see when an approval request is invalidated. Every screen starts with a scripted
agent, without a backend or an API key.

<p align="center">
  <img src="../doc/imgs/examples/approval.gif" alt="The agent asks to empty a shopping list. Removing an item invalidates the request, and a new request can be approved." width="340">
</p>

## Run the gallery

With [FVM](https://fvm.app/) and your platform's Flutter tooling, from the repository root:

```sh
fvm flutter pub get
cd example
fvm flutter run
```

Choose an iOS simulator, an Android emulator or a connected device. For desktop, run
`fvm flutter run -d macos`.

Pick a screen and tap its suggested prompt or button. **Reset example** starts it again with fresh
state and a new session. The scripted agents follow the scenario and do not read what you write.

| Screen | Try it | Source |
|---|---|---|
| Order desk | Fill an order from the sample e-mail, change quantities, then ask to place it. Edit again while the approval is pending. | [bloc](lib/desk) |
| Shopping list | Let the agent add items, then approve emptying the list, or remove an item to invalidate the request. | [bloc](lib/shopping_list/shopping_list.dart) |
| Contact form | Fill the form from the sample e-mail, then edit the fields yourself. No chat. | [bloc](lib/recipes/fill_from_email) |
| Reply approval | Let the agent answer a customer, then send or cancel the reply in a dialog. Sending is simulated. | [bloc](lib/recipes/approval_dialog) |
| Shopping cart | Remove an item before you approve checkout, then ask again with the new cart. Checkout is simulated. | [Riverpod](lib/recipes/riverpod) |
| To-do list | Add a task while the approval is pending, then ask again to clear the list. | [provider](lib/recipes/change_notifier) |

<p align="center">
  <img src="../doc/imgs/examples/gallery.png" alt="The gallery of example screens" width="23%">
  <img src="../doc/imgs/examples/order.png" alt="The order draft with its quantities on a phone" width="23%">
  <img src="../doc/imgs/examples/approval.png" alt="The shopping list with a pending approval" width="23%">
  <img src="../doc/imgs/examples/contact.png" alt="The contact form filled from the sample e-mail" width="23%">
</p>

[doc/examples.md](../doc/examples.md) explains each screen. [`AgentChat`](lib/agent_chat.dart) is
the chat to copy into your app and make your own. [`demo_agents.dart`](lib/gallery/demo_agents.dart)
holds the scripts.

## Apple on-device AI pilot

The [pilot](lib/apple_foundation_models/try_it.dart) connects the shopping list to Apple's local
Foundation Models framework. It uses the screen's existing methods, manual controls and approval
flow, with no AI server, API key or cloud fallback. This is an in-app integration; Siri and App
Intents are separate. The [proposal](../doc/rfc/0002-on-device-apple-connection.md) describes the
boundary and open questions.

Use Xcode 26 or later and an Apple Intelligence device running iOS 26 or macOS 26 or later,
with Apple Intelligence enabled and its model downloaded. The pilot checks availability and
shows a reason when the model is unavailable. Availability does not guarantee that generation
will succeed. Local generation was exercised on a supported Mac; physical iPhone inference
remains unverified. Simulator availability succeeded locally, but generation failed.

From the repository root:

```sh
fvm flutter pub get
cd example
fvm flutter run -t lib/apple_foundation_models/try_it.dart
```

Choose a physical iPhone, or add `-d macos` for a supported Mac. The default gallery still uses
scripts. This experimental adapter selects at most one action per user message and acknowledges
the actual result without another model call. Send each action separately. English prompts are
the starting point; this pilot makes no claim of supported Polish model behavior.

To check the app manually:

1. Send **Add milk.**, then **Add bread.** Check the list after each message. Add an item manually.
2. Send **Remove milk.** Check that the agent changes the same list as the manual controls.
3. Send **Empty the list.**, approve the request and check that the list becomes empty.
4. Add items, ask to empty the list again, then remove an item manually while approval is pending.
   Check that the request becomes stale. Ask again and approve the new request.
5. With the model ready, disconnect networking and repeat. **Reset pilot** starts a fresh list
   and conversation. A model error shows its reason and a reset instruction.

These are verification steps, not a model-quality guarantee. The model can select the wrong
action or arguments, including a mutation for a read-only request. Check each result. Automated
Flutter tests use fake native responses and never call a real model.

### Check the native adapter

On macOS 26 or later, from the repository root:

```sh
xcrun swiftc -parse-as-library -swift-version 6 \
  -module-cache-path /private/tmp/tandem-apple-module-cache \
  example/apple/AppleFoundationModelsRunner.swift \
  example/apple/AppleHandoffTool.swift example/apple/AppleToolSchema.swift \
  example/apple/AppleConversation.swift example/apple/AppleToolOutcome.swift \
  example/apple/AppleFoundationModelsSmoke.swift \
  -o /private/tmp/tandem-apple-smoke
/private/tmp/tandem-apple-smoke --check
```

`--check` checks native transcript reconstruction and result acknowledgments without inference.
`--availability` checks device readiness. Opt in to `--flow` for three real local model selections:
add milk, add bread and clear. This harness supplies simulated tool results. Use the app to check
actual Tandem execution and approvals. Model calls are separate from automated tests.

## Connect the order desk to a backend

In `example/agent`, with [uv](https://docs.astral.sh/uv/), start the Google ADK backend with its
scripted model, which needs no API key:

```sh
TANDEM_FAKE_LLM=1 uv run order-agent
```

In the gallery, open **Order desk**, tap **Use backend** and enter the agent's URL:

- iOS simulator, or macOS on the same Mac: `http://localhost:8000/agent`.
- Android emulator: `http://10.0.2.2:8000/agent`.
- Physical device: your computer's address on the local network. Start the backend with
  `TANDEM_HOST=0.0.0.0 TANDEM_FAKE_LLM=1 uv run order-agent` and allow port 8000 through your
  firewall. See [the backend settings](agent/README.md#configuration).

Then tap the sample e-mail. Connecting or resetting starts a new order. **Use script** goes back to
the scripted agent. The rest of the script is in [agent/README.md](agent/README.md#the-script).

For Gemini, copy `agent/.env.example` to `agent/.env`, set `GOOGLE_API_KEY` in it, and run
`uv run order-agent` in `example/agent`.

## Other platforms

In `example`, generate the host for your platform, such as Windows:

```sh
fvm flutter create --empty --platforms=windows .
fvm flutter run -d windows
```

For Linux, use `linux`. For a browser, use `--platforms=web` and `-d chrome`. The example backend
has no CORS middleware, so a browser build cannot reach it without adding one.
