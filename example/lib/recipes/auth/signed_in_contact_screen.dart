import 'package:example/recipes/fill_from_email/contact_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:tandem/tandem.dart';

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

/// The contact form of the "Fill from e-mail" recipe, talking to an agent
/// that needs the user's token.
final class const SignedInContactScreen({
  super.key,
  required final Future<String> Function() token,
}) extends StatefulWidget {
  @override
  State<SignedInContactScreen> createState() => _SignedInContactScreenState();
}

final class _SignedInContactScreenState() extends State<SignedInContactScreen> {
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

  @override
  Widget build(BuildContext context) => ContactScreen(connection: _connection);
}
