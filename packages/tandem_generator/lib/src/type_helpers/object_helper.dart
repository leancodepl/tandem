part of '../agent_types.dart';

final class _ObjectHelper(final InterfaceType _type) extends _TypeHelper {
  @override
  Map<String, Object?> schema(AgentTypes types, {required String path}) =>
      types._withPlainClass(
        _type,
        operation: .read,
        path: path,
        body: (object) {
          final parameters = [
            for (final field in object.fields) field.parameter,
          ];

          return _AgentParameters(types)
              .schema(parameters, prefix: '$path.', owner: object.type);
        },
      );

  @override
  String read(
    AgentTypes types, {
    required String from,
    required String key,
    required String name,
  }) {
    final arguments = _arguments(types, from: name);

    return '$from.readObject($key, ($name) => .new($arguments))';
  }

  @override
  String readList(
    AgentTypes types, {
    required String from,
    required String key,
  }) {
    final arguments = _arguments(types, from: 'item');

    return '$from.readObjects($key, (item) => .new($arguments))';
  }

  @override
  String write(
    AgentTypes types, {
    required String value,
    required String path,
  }) => types._withPlainClass(
    _type,
    operation: .write,
    path: path,
    body: (object) =>
        _writeFields(types, object.fields, value: value, path: path),
  );

  String _arguments(AgentTypes types, {required String from}) =>
      types._withPlainClass(
        _type,
        operation: .read,
        path: from,
        body: (object) {
          final parameters = [
            for (final field in object.fields) field.parameter,
          ];

          return _AgentParameters(types).arguments(parameters, from: from);
        },
      );

  static String _writeFields(
    AgentTypes types,
    List<AgentField> fields, {
    required String value,
    required String path,
  }) {
    final entries = <String>[];

    for (final field in fields) {
      final name = field.parameter.displayName;
      final key = DartLiteral.json(name);
      final written = types.write(
        field.getter.returnType,
        value: '$value.$name',
        path: '$path.$name',
      );

      entries.add('$key: $written');
    }

    final contents = entries.join(', ');

    return '{$contents}';
  }
}
