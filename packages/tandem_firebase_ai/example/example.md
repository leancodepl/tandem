The [Firebase order example](https://github.com/leancodepl/tandem/blob/main/example/README.md#connect-directly-to-firebase-ai-logic)
uses an existing Tandem screen. Configure Firebase and App Check, then create
one connection outside `build`:

<!-- example/lib/main_firebase.dart -->
```dart
  final connection = FirebaseConnection(
    firebase: FirebaseAI.googleAI(),
    model: model,
    instructions:
        'Help the user prepare their order. '
        'Describe the result after each change. '
        'Only place an order when the user asks you to.',
  );
```

Pass it to `TandemScope.connected`. The scope still reads the same surface and
uses the same approval UI:

<!-- example/lib/firebase_order_app.dart -->
```dart
      child: TandemScope.connected(
        surface: (context) => context.read<OrderCubit>(),
        connection: connection,
        approvals: const .fromState(),
```

The screen's methods are the model's tools. Tandem sends their results back to
the model after execution or a user decision. The app supplies the chat through
the scope's `child`.
