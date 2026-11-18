import 'package:example/firebase_order_app.dart';
import 'package:example/firebase_setup.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/widgets.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();

  const model = String.fromEnvironment('FIREBASE_MODEL');
  final connection = FirebaseConnection(
    firebase: FirebaseAI.googleAI(),
    model: model,
    instructions:
        'Help the user prepare their order. '
        'Describe the result after each change. '
        'Only place an order when the user asks you to.',
  );

  TandemBridge.enable();
  runApp(FirebaseOrderApp(connection: connection));
}
