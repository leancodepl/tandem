import 'dart:async';

import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

/// Streams [_first] as its first run, as a server whose events a test
/// writes by hand, and lets [_agent] run the rest.
final class RawFirstRun(
  final Stream<Map<String, Object?>> _first,
  final ScriptedAgent _agent,
) implements AgentConnection {
  final requests = <Map<String, Object?>>[];

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    requests.add(input);
    return requests.length == 1 ? _first : _agent.run(input);
  }
}

/// Throws on its first run before any stream exists, as an adapter that
/// checks its input can.
final class ThrowsFirst(final ScriptedAgent _agent) implements AgentConnection {
  var _runs = 0;

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    if (_runs++ == 0) {
      throw StateError('No token.');
    }
    return _agent.run(input);
  }
}

/// Keeps its run open until a Stop or [end], then ends it with [ending], as
/// an AG-UI server with a cancel message does.
final class StoppableAgent(
  final Map<String, Object?> ending, {
  final bool failsToStop = false,
}) implements StoppableAgentConnection {
  final requests = <Map<String, Object?>>[];
  final stopped = <Map<String, Object?>>[];
  final _events = StreamController<Map<String, Object?>>();

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    requests.add(input);
    return _events.stream;
  }

  @override
  Future<void> stop(Map<String, Object?> input) async {
    if (failsToStop) {
      throw StateError('The socket is closed.');
    }
    stopped.add(input);
    await end();
  }

  Future<void> end() async {
    _events.add(ending);
    await _events.close();
  }
}
