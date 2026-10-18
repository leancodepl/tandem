import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

/// The `onEvent` of the order form: a snackbar when the agent placed the
/// order, or when a run failed.
void showOrderMessages(
  BuildContext context,
  TandemEvent event,
  TandemSession session,
) {
  final message = switch (event) {
    AgentCall(tool: 'place_order', :final result) => 'Placed order $result.',
    RunFailed() || ConnectionLost() => 'The agent did not answer. Try again.',
    AgentCall() || RunStopped() => null,
  };
  if (message case final text?) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
