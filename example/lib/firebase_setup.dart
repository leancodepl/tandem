import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const _options = FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
  appId: String.fromEnvironment('FIREBASE_APP_ID'),
  messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
);
const _recaptchaSiteKey = String.fromEnvironment('FIREBASE_RECAPTCHA_SITE_KEY');
const _debugToken = String.fromEnvironment('FIREBASE_APP_CHECK_DEBUG_TOKEN');

Future<void> initializeFirebase() async {
  final configuration = [
    _options.apiKey,
    _options.appId,
    _options.messagingSenderId,
    _options.projectId,
  ];
  if (configuration.any((value) => value.isEmpty)) {
    throw StateError('Set the Firebase configuration from example/README.md.');
  }

  await Firebase.initializeApp(options: _options);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    providerWeb: kIsWeb ? _webProvider() : null,
  );
}

WebProvider _webProvider() {
  if (kDebugMode && _debugToken.isNotEmpty) {
    return WebDebugProvider(debugToken: _debugToken);
  }
  if (_recaptchaSiteKey.isEmpty) {
    throw StateError('Set FIREBASE_RECAPTCHA_SITE_KEY for the web example.');
  }
  return ReCaptchaV3Provider(_recaptchaSiteKey);
}
