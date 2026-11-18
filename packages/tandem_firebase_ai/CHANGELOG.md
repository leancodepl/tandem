## 0.1.0

- `FirebaseConnection` connects a Tandem screen to Gemini through Firebase AI Logic, without an agent backend. Each run sends the screen's current `.sees` values and offers its methods to the model as tools.
- The model streams text to the chat and proposes calls of the methods. Tandem checks each call and runs it in the app, a `.callsWithApproval` method only after the user approves it.
- The next run sends the model the results of the calls and the user's decisions.
- Stop aborts the run's HTTP request. A failed run reports a `FirebaseErrorCode`.
- `tandem_firebase_ai` depends on `firebase_ai` 5.2 or a later 5.x release and on `tandem` 0.3.3 or a later 0.3.x release.
