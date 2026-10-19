import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Asks for the URL of an AG-UI endpoint and pops it as a [Uri].
final class const BackendDialog({super.key}) extends StatefulWidget {
  @override
  State<BackendDialog> createState() => _BackendDialogState();
}

final class _BackendDialogState() extends State<BackendDialog> {
  final _url = TextEditingController(
    text: switch (defaultTargetPlatform) {
      .android when !kIsWeb => 'http://10.0.2.2:8000/agent',
      _ => 'http://localhost:8000/agent',
    },
  );
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    switch (Uri.tryParse(_url.text.trim())) {
      case final uri?
          when uri.host.isNotEmpty &&
              (uri.isScheme('http') || uri.isScheme('https')):
        Navigator.of(context).pop(uri);
      case _:
        setState(() => _error = 'Enter an HTTP or HTTPS URL.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect an AG-UI backend'),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _url,
        autofocus: true,
        keyboardType: .url,
        decoration: InputDecoration(labelText: 'Agent URL', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Connect')),
    ],
  );
}
