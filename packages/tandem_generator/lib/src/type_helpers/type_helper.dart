part of '../agent_types.dart';

abstract class const _TypeHelper() {
  Map<String, Object?> schema(AgentTypes types, {required String path});

  String read(
    AgentTypes types, {
    required String from,
    required String key,
    required String name,
  }) => '$from.read($key)';

  String readList(
    AgentTypes types, {
    required String from,
    required String key,
  }) => '$from.readList($key)';

  String write(
    AgentTypes types, {
    required String value,
    required String path,
  }) => value;

  String writeNullable(
    AgentTypes types, {
    required String value,
    required String path,
  }) {
    final name = value.split('.').last;
    final written = write(types, value: name, path: path);

    if (written == name) return value;

    return 'switch ($value) { null => null, final $name => $written }';
  }
}
