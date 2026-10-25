import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

/// One line that says what the agent does now. It needs a `TandemScope`
/// above it.
final class const StatusLine({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (TandemSessionScope.of(context).status) {
        Idle() => const SizedBox.shrink(),
        Thinking(:final backendTool?) => Text('Using $backendTool…'),
        Thinking(drawing: true) => const Text('Drawing a view…'),
        Thinking() => const LinearProgressIndicator(),
        Calling(:final tool) => Text('Running $tool…'),
        AwaitingApproval(:final request) => Text(
          'Waiting for you: ${request.tool}',
        ),
        Stopping() => const Text('Stopping…'),
      };
}
