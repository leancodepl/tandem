## 0.2.0

- **Breaking:** Upgrade `tandem` to 0.4.0 with it: `tandem_firebase_ai` depends on `tandem` 0.4.0 or a later 0.4.x release.
- The README links to `doc/checks.json` for the models and Firebase backends each release ran on, in place of the two models it named.
- The description on pub.dev says the adapter needs no agent backend, and the topics add `genui`, `generative-ai` and `function-calling`.

## 0.1.1

- `idleTimeout` is 120 seconds by default. Before, it was 60 seconds, and `gemini-3.6-flash` can take longer to send its first bytes.
- A run that gets an error page that is not JSON, such as the HTML page of a gateway, fails with the HTTP status in its message. Before, the message was a `FormatException` that quoted the page.
- The README names the models the connection is tested on: `gemini-3.5-flash-lite` and `gemini-3.6-flash`.
- A `TandemView` catalog works through the `tandem_show_view` tool. It is checked on both models.

## 0.1.0

- `FirebaseConnection` connects a Tandem screen to Gemini through Firebase AI Logic, without an agent backend. Each run sends the screen's current `.sees` values and offers its methods to the model as tools.
- The model streams text to the chat and proposes calls of the methods. Tandem checks each call and runs it in the app, a `.callsWithApproval` method only after the user approves it.
- The next run sends the model the results of the calls and the user's decisions.
- Stop aborts the run's HTTP request. A failed run reports a `FirebaseErrorCode`.
- `tandem_firebase_ai` depends on `firebase_ai` 5.2 or a later 5.x release and on `tandem` 0.3.3 or a later 0.3.x release.
