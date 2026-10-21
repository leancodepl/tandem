# Examples

The examples use real code in [`example/lib/recipes`](../example/lib/recipes) and [`example/lib/shopping_list`](../example/lib/shopping_list). Their UI tests use scripted agents. CI analyzes the code and checks that the snippets below match the files. Copy the one closest to your screen. The [example gallery](../example/README.md) runs most of them with scripted agents.

The screens take an `AgentConnection`, except the last, which makes its own. In the app it is `HttpAgentConnection(Uri.parse('https://your.server/agent'))`, made once and kept, not made in `build`. In a test it is a `ScriptedAgent`. `TandemScope(agent: uri, ...)` makes the connection for you when you need nothing else.

| You have | Example |
|---|---|
| A bloc screen, and you want a chat next to it | [A chat next to the screen](#a-chat-next-to-the-screen) |
| A form to fill in from text, without a chat | [Fill from e-mail](#fill-from-e-mail) |
| An action the user approves in a dialog | [An approval dialog](#an-approval-dialog) |
| Riverpod | [A Riverpod Notifier](#a-riverpod-notifier) |
| provider or a `ChangeNotifier` | [A ChangeNotifier](#a-changenotifier) |
| An agent behind sign-in | [A token for your backend](#a-token-for-your-backend) |
| No backend or no API key yet | [Without an API key](#without-an-api-key) |
| Apple's local system model | [On-device Apple](#on-device-apple) |

## A chat next to the screen

The README's quick start. [`OrderCubit`](../example/lib/order_cubit.dart) lists what the agent sees and calls. [`AgentChat`](../example/lib/agent_chat.dart) is the chat to copy and make your own. The scope has `approvals: const .fromState()`, because the chat draws the approval cards. The demo's order desk in [`example/lib/desk`](../example/lib/desk) is the same, with more methods.

## Fill from e-mail

The user pastes an e-mail and taps a button, and the agent fills in the form. There is no chat. Code: [`fill_from_email`](../example/lib/recipes/fill_from_email).

The Cubit lists the form and the methods its fields call:

<!-- example/lib/recipes/fill_from_email/contact_cubit.dart -->
```dart
@TandemAgent()
class ContactCubit() extends Cubit<ContactState> with _$ContactCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(contact),
    .calls(setName),
    .calls(setEmail),
    .calls(setCompany),
  ];

  @override
  Stream<Object?> get changes => stream;

  /// The contact as the user sees it in the form.
  ContactState get contact => state;

  /// Sets the person's full name.
  void setName(String name) => emit(state.copyWith(name: name));

  /// Sets the person's e-mail address.
  void setEmail(String email) => emit(state.copyWith(email: email));

  /// Sets the company the person works for.
  void setCompany(String company) => emit(state.copyWith(company: company));
}
```

Nothing here needs approval, so the scope has `approvals: const .none()`. Without a chat, the user would not see that a run failed, so `onEvent` shows a snackbar:

<!-- example/lib/recipes/fill_from_email/contact_screen.dart -->
```dart
    child: TandemScope.connected(
      surface: (context) => context.read<ContactCubit>(),
      connection: connection,
      approvals: const .none(),
      onEvent: (context, event, session) {
        final problem = switch (event) {
          RunFailed() => 'The agent ran into a problem. Try again.',
          ConnectionLost() => 'The connection to the agent broke. Try again.',
          AgentCall() || RunStopped() => null,
        };
        if (problem case final text?) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(text)));
        }
      },
```

The button sends the e-mail with `session.send`. `session.status` tells what the agent does now, and the agent's last message is the last `AgentMessage` in `session.items`:

<!-- example/lib/recipes/fill_from_email/contact_screen.dart -->
```dart
    final session = TandemSessionScope.of(context);
    final progress = switch (session.status) {
      Idle() || AwaitingApproval() => null,
      Thinking() || Stopping() => 'Reading the e-mail…',
      Calling() => 'Filling in the form…',
    };
    final reply = session.items.whereType<AgentMessage>().lastOrNull;
```

<!-- example/lib/recipes/fill_from_email/contact_screen.dart -->
```dart
        FilledButton(
          onPressed: progress == null
              ? () => session.send(
                  'Fill in the contact from this e-mail:\n\n${_email.text}',
                )
              : null,
          child: const Text('Fill from e-mail'),
        ),
```

Each field is a `TextField` whose controller takes the Cubit's value when the agent changes it (`_Field` in [`contact_screen.dart`](../example/lib/recipes/fill_from_email/contact_screen.dart)). Test: [`contact_screen_test.dart`](../example/test/recipes/contact_screen_test.dart).

## An approval dialog

The agent writes a reply to a customer, and the reply goes out only after the user taps Send in a dialog. Code: [`approval_dialog`](../example/lib/recipes/approval_dialog).

<!-- example/lib/recipes/approval_dialog/reply_cubit.dart -->
```dart
  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(reply),
    .calls(setReply),
    if (reply.isNotEmpty && !sent) .callsWithApproval(send),
  ];
```

`send` is listed only once the reply has text, so the agent writes the reply in one turn and sends it in the next. The scope has `approvals: const .callback(_confirmSend)`:

<!-- example/lib/recipes/approval_dialog/reply_screen.dart -->
```dart
Future<void> _confirmSend(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final reply = context.read<ReplyCubit>().reply;
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => _SendDialog(reply),
  );
  try {
    if (send ?? false) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // The reply changed, or the screen closed, while the dialog showed.
  }
}
```

- The dialog shows the reply from the Cubit, because the approval covers what `.sees` lists. When the reply changes before Send, `approve` throws `ApprovalNotPending` and the method does not run.
- With several methods that need approval, pick the dialog's text by `request.tool`.
- The requests are in `session.items` as well. A chat on the same screen should not draw Approve and Reject for them too.
- The screen has no chat either, so its `onEvent` shows a snackbar when a run fails, as in [Fill from e-mail](#fill-from-e-mail).

Test: [`reply_screen_test.dart`](../example/test/recipes/reply_screen_test.dart).

## A Riverpod Notifier

A cart on Riverpod 3, with `AgentChat` beside it. Code: [`riverpod`](../example/lib/recipes/riverpod).

<!-- example/lib/recipes/riverpod/cart_notifier.dart -->
```dart
// Written by hand: riverpod_generator writes a `_$CartNotifier` too.
final cartProvider = NotifierProvider.autoDispose(CartNotifier.new);

@TandemAgent()
class CartNotifier() extends Notifier<List<String>> with _$CartNotifier {
  final _changes = StreamController<Object?>.broadcast();

  @override
  List<String> build() {
    // Riverpod drops this listener when it builds again, so it is never
    // there twice.
    listenSelf((_, next) => _changes.add(next));
    return const [];
  }

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(items),
    .calls(add),
    .calls(remove),
    if (items.isNotEmpty) .callsWithApproval(checkout),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  // Protected, so riverpod_lint does not ask to read it through `state`.
  /// What is in the cart now.
  @protected
  List<String> get items => state;

  /// Puts [item] in the cart.
  void add(String item) => state = [...state, item];

  /// Takes [item] out of the cart.
  void remove(String item) => state = [...state]..remove(item);

  /// Orders everything in the cart and empties it.
  void checkout() => state = const [];
}
```

- A `Notifier` has no stream of its states, so `listenSelf` feeds `changes`. It is a broadcast stream, because every new session listens again.
- Do not close the controller in `ref.onDispose`. Riverpod calls it before every rebuild of the provider, and the notifier with its controller lives on.
- `riverpod_lint`'s `avoid_public_notifier_properties` skips a getter marked `@protected`, and `.sees` takes one. A private getter works too, but its generated code trips `no_leading_underscores_for_local_identifiers`.

The screen is a `ConsumerWidget`, and the scope reads the notifier with `ref.read`. `_Cart` below it lists the items with `ref.watch(cartProvider)`, which keeps the notifier alive while the screen shows:

<!-- example/lib/recipes/riverpod/cart_screen.dart -->
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) => TandemScope.connected(
    surface: (context) => ref.read(cartProvider.notifier),
    connection: connection,
    approvals: const .fromState(),
    child: const Scaffold(
      body: AgentWorkspace(
        title: 'Shopping cart',
        chat: AgentChat(
          suggestion: 'Add a keyboard and a USB-C cable, then check out.',
        ),
        child: _Cart(),
      ),
    ),
  );
```

When the screen closes, the scope disposes its session first, and `autoDispose` disposes the notifier a frame later. Test: [`cart_screen_test.dart`](../example/test/recipes/cart_screen_test.dart), where removing an item invalidates the checkout card.

## A ChangeNotifier

A to-do list on provider, with `AgentChat` beside it. Code: [`change_notifier`](../example/lib/recipes/change_notifier).

<!-- example/lib/recipes/change_notifier/todo_list.dart -->
```dart
@TandemAgent()
class TodoList() extends ChangeNotifier with _$TodoList {
  final _changes = StreamController<Object?>.broadcast();
  final _todos = <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(todos),
    .calls(add),
    if (todos.isNotEmpty) .callsWithApproval(clear),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _changes.add(null);
  }

  /// The to-dos as the user sees them, oldest first.
  List<String> get todos => List.unmodifiable(_todos);

  /// Adds [todo] at the end of the list.
  void add(String todo) {
    _todos.add(todo);
    notifyListeners();
  }

  /// Removes every to-do.
  void clear() {
    _todos.clear();
    notifyListeners();
  }
}
```

Every `notifyListeners` also goes to `changes`. The controller is never closed: each session cancels its subscription when it ends. A `ValueNotifier` subclass works the same way. The screen puts the scope below the `ChangeNotifierProvider`. Its chat gives the approval card a title in the user's language, see [Your texts and language](#your-texts-and-language):

<!-- example/lib/recipes/change_notifier/todo_screen.dart -->
```dart
final class const TodoScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => TodoList(),
    child: TandemScope.connected(
      surface: (context) => context.read<TodoList>(),
      connection: connection,
      approvals: const .fromState(),
      child: Scaffold(
        body: AgentWorkspace(
          title: 'Release tasks',
          chat: AgentChat(
            suggestion: 'Add two release tasks, then clear the list.',
            approvalBuilder: (context, request) => _ApprovalTitle(request),
          ),
          child: const _Todos(),
        ),
      ),
    ),
  );
}
```

Test: [`todo_screen_test.dart`](../example/test/recipes/todo_screen_test.dart).

## A token for your backend

`HttpAgentConnection` takes an `http.Client`. One that adds a header to every request is enough for most sign-ins. Code: [`auth`](../example/lib/recipes/auth).

<!-- example/lib/recipes/auth/signed_in_contact_screen.dart -->
```dart
/// Adds the signed-in user's token to every request to the agent.
final class BearerClient(final Future<String> Function() _token)
    extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer ${await _token()}';
    return await _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
```

The screen keeps the client and the connection in its state. A new connection would start a new session, and `HttpAgentConnection` never closes a client you give it:

<!-- example/lib/recipes/auth/signed_in_contact_screen.dart -->
```dart
  // A field, not in build: another connection would start a new session.
  late final _client = BearerClient(widget.token);
  late final _connection = HttpAgentConnection(
    Uri.parse('https://agent.example.com/agent'),
    client: _client,
  );

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
```

## Without an API key

You can try Tandem without a backend, and the demo without a model.

**Your screen with a script.** `ScriptedAgent` from `package:tandem/testing.dart` works in the app too. It plays the same turns whatever the user writes, and a run past the script fails, so script every turn you want to try:

<!-- example/lib/recipes/fill_from_email/try_it.dart -->
```dart
// Plays the same turns whatever the e-mail says. A run past the script fails.
final _agent = ScriptedAgent([
  (_) => const [
    AgentStep.callTool('set_name', {'name': 'Marta Nowak'}),
    AgentStep.callTool('set_email', {'email': 'marta@acme.example'}),
    AgentStep.callTool('set_company', {'company': 'Acme Office Supply'}),
  ],
  (_) => const [AgentStep.say('Filled in from the signature.')],
]);

void main() => runApp(MaterialApp(home: ContactScreen(connection: _agent)));
```

In `example`, `flutter run -t lib/recipes/fill_from_email/try_it.dart` runs it. The example has Android, iOS and macOS hosts. For a browser, add the web platform first with `flutter create --platforms=web .` in `example`, then run `flutter run -d chrome -t lib/recipes/fill_from_email/try_it.dart`. `ScriptedAgent` sends nothing over the network, so the browser needs no CORS.

**The demo with a scripted model.** The demo's agent has a scripted model that plays the order desk script with no key and no model calls. In `example/agent`, with [uv](https://docs.astral.sh/uv/):

```sh
TANDEM_FAKE_LLM=1 uv run order-agent
```

Then [connect the order desk](../example/README.md#connect-the-order-desk-to-a-backend) of the gallery to it and send the sample e-mail.

**A local model.** ADK runs local models through LiteLLM, such as Ollama with `LiteLlm(model="ollama_chat/<model>")` and `OLLAMA_API_BASE=http://localhost:11434` ([ADK docs](https://adk.dev/agents/models/ollama/)). Use `ollama_chat`, not `ollama`, and a model whose `ollama show` lists `tools`. The demo's agent takes only Gemini names: to try one, return a `LiteLlm` from `_model` in [`agent.py`](../example/agent/src/order_agent/agent.py) and add the `litellm` package. This is not tested with the demo. Small local models are weaker at many tool calls in a row, and the order desk script makes nine of them. The fix for parallel calls in [`streaming.py`](../example/agent/src/order_agent/streaming.py) is for Gemini only, so two calls of the same tool in one turn, as the demo's two `set_quantity`, may not reach the app.

**Gemini.** The real model of the demo. It has a free tier, but needs a key: copy `example/agent/.env.example` to `.env` and set `GOOGLE_API_KEY`.

## Your texts and language

Tandem shows no text of its own. In [`AgentChat`](../example/lib/agent_chat.dart) every text is inline, in the switches over `ChatNoticeKind`, `ApprovalStatus` and `session.status`. Replace them with your app's localizations. `request.description` is the method's doc comment, written for the agent, so pick a card's title by `request.tool`, as the to-do list does:

<!-- example/lib/recipes/change_notifier/todo_screen.dart -->
```dart
          chat: AgentChat(
            suggestion: 'Add two release tasks, then clear the list.',
            approvalBuilder: (context, request) => _ApprovalTitle(request),
          ),
```

<!-- example/lib/recipes/change_notifier/todo_screen.dart -->
```dart
// In an app, these texts come from its localizations, such as the
// AppLocalizations class that `flutter gen-l10n` writes.
final class const _ApprovalTitle(final ApprovalRequest request)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(switch ((
    Localizations.localeOf(context).languageCode,
    request.tool,
  )) {
    ('pl', 'clear') => 'Usunąć wszystkie zadania?',
    (_, 'clear') => 'Remove every to-do?',
    _ => request.description,
  });
}
```

## Testing

`ScriptedAgent` plays a script instead of a model. Every turn of the script is one run: a turn that calls a method, then the turn after Tandem sent the answer. `agent.requests` holds the body of every run, so a test can check what the agent saw in `context` or what the user sent. The examples above have tests, and the README has [another](https://github.com/leancodepl/tandem#testing). To check only what a class gives the agent, use `AgentListing.of(cubit)` from `package:tandem/testing.dart`, with its `context`, `tools` and `call(name, arguments)`.

## The backend

Any AG-UI endpoint works. The backend has to put the AG-UI `context` into the model's prompt, accept `tools` on every run and, on the web, allow the app's origin with CORS. The example backend has no CORS middleware, so a browser build cannot reach it without adding one. The `tools`, their descriptions and the `context` come from the app, so the backend treats them as untrusted input. Tandem is tested with [ag-ui-adk](https://pypi.org/project/ag-ui-adk/) 0.9.0.

The demo's agent in [`example/agent`](../example/agent) is a Google ADK agent to copy from:

- [`instruction.py`](../example/agent/src/order_agent/instruction.py) puts the `context` into the prompt. ag-ui-adk does not.
- [`streaming.py`](../example/agent/src/order_agent/streaming.py) streams all calls of a Gemini turn in one chunk. ag-ui-adk drops a second parallel call of the same tool when the calls come in separate chunks.
- Its own tools, such as `find_customer`, run on the server. The app's methods come as the run's `tools`, so the agent changes the screen only through them.

## On-device Apple

The shopping list with Apple's on-device model instead of a backend, with the same capabilities and approvals. Entry point: [`recipes/on_device/apple.dart`](../example/lib/recipes/on_device/apple.dart).

<!-- example/lib/recipes/on_device/apple.dart -->
```dart
void main() => runApp(
  MaterialApp(home: ShoppingListScreen(connection: OnDeviceAgent.apple())),
);
```

[Requirements and limits](../README.md#apples-on-device-model), [how to run it](../example/README.md#run-the-shopping-list-with-apples-on-device-model).

**Smart input.** The invoice list of [`recipes/on_device/invoices`](../example/lib/recipes/on_device/invoices) has no chat. Its search field sends one sentence, and the model reports what it asks for with `interpretInvoiceInput`, a method with an enum for each part of the request. The app checks what it supports, and the user approves the invoices it found ([how to run it](../example/README.md#smart-invoice-input-with-apples-on-device-model)).
