import 'package:example/firebase_order_app.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const options = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  );
  const model = String.fromEnvironment('FIREBASE_MODEL');
  const siteKey = String.fromEnvironment('FIREBASE_RECAPTCHA_SITE_KEY');
  const debugToken = String.fromEnvironment('FIREBASE_APP_CHECK_DEBUG_TOKEN');
  final useDebugAppCheck = kDebugMode && debugToken.isNotEmpty;
  if ([
    options.apiKey,
    options.appId,
    options.messagingSenderId,
    options.projectId,
    model,
  ].any((value) => value.isEmpty)) {
    throw StateError('Set the Firebase configuration from example/README.md.');
  }
  final webProvider = switch ((kIsWeb, useDebugAppCheck)) {
    (false, _) => null,
    (true, true) => WebDebugProvider(debugToken: debugToken),
    (true, false) when siteKey.isNotEmpty => ReCaptchaV3Provider(siteKey),
    _ => throw StateError(
      'Set FIREBASE_RECAPTCHA_SITE_KEY for the web example.',
    ),
  };

  await Firebase.initializeApp(options: options);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    providerWeb: webProvider,
  );

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
