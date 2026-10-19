import 'package:example/apple_foundation_models/apple_model_connection.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/material.dart';

void main() =>
    runApp(MaterialApp(theme: deskTheme, home: const _OnDevicePilot()));

final class const _OnDevicePilot() extends StatefulWidget {
  @override
  State<_OnDevicePilot> createState() => _OnDevicePilotState();
}

final class _OnDevicePilotState() extends State<_OnDevicePilot> {
  var _connection = AppleModelConnection();
  late Future<AppleModelAvailability> _availability = _connection
      .availability();
  var _generation = 0;

  void _reset() => setState(() {
    _generation++;
    _connection = AppleModelConnection();
    _availability = _connection.availability();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      scrolledUnderElevation: 0,
      title: const Text('Tandem · On-device AI'),
      actions: [
        IconButton(
          tooltip: 'Reset pilot',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: FutureBuilder<AppleModelAvailability>(
      future: _availability,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return const Center(
            child: Column(
              mainAxisSize: .min,
              spacing: 16,
              children: [
                CircularProgressIndicator(),
                Text('Checking the on-device model…'),
              ],
            ),
          );
        }
        if (snapshot.data case final availability?) {
          if (availability.available) {
            return Column(
              crossAxisAlignment: .stretch,
              children: [
                Visibility(
                  visible: MediaQuery.viewInsetsOf(context).bottom == 0,
                  child: const Padding(
                    padding: .fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'On-device · Apple Foundation Models · No AI backend\n'
                      'One action per message.',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ValueListenableBuilder<String?>(
                  valueListenable: _connection.error,
                  builder: (context, reason, child) => switch (reason) {
                    final reason? => _ModelError(reason: reason),
                    null => const SizedBox.shrink(),
                  },
                ),
                Expanded(
                  child: ShoppingListScreen(
                    key: ValueKey(_generation),
                    connection: _connection,
                    suggestion: 'Add milk to the list.',
                  ),
                ),
              ],
            );
          }
          return _ModelUnavailable(
            reason: availability.reason,
            onRetry: _reset,
          );
        }
        return _ModelUnavailable(
          reason: 'The model availability check failed: ${snapshot.error}',
          onRetry: _reset,
        );
      },
    ),
  );
}

final class const _ModelError({required final String reason})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
    color: context.colorScheme.errorContainer,
    child: Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 4,
        children: [
          Text(reason),
          const Text('Reset pilot to start a fresh conversation.'),
        ],
      ),
    ),
  );
}

final class const _ModelUnavailable({
  required final String reason,
  required final VoidCallback onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const .all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: .min,
            spacing: 16,
            children: [
              const Icon(Icons.mobile_off_outlined, size: 40),
              Text(
                'On-device AI is unavailable',
                textAlign: .center,
                style: context.textTheme.titleLarge,
              ),
              Text(reason, textAlign: .center),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    ),
  );
}
