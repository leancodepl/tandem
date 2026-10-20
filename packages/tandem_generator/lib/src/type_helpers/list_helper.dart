part of '../agent_types.dart';

final class _ListHelper(final DartType _item) extends _TypeHelper {
  @override
  Map<String, Object?> schema(AgentTypes types, {required String path}) {
    if (_item.isNullable || _item.isDartCoreList) {
      throw AgentTypeError.invalidListItem(types._element, path: path);
    }

    final itemPath = '$path[]';
    final helper = types._helperFor(_item, operation: .read, path: itemPath);
    final itemSchema = helper.schema(types, path: itemPath);

    return {'type': 'array', 'items': itemSchema};
  }

  @override
  String read(
    AgentTypes types, {
    required String from,
    required String key,
    required String name,
  }) {
    final helper = types._helperFor(_item, operation: .read, path: '$name[]');

    return helper.readList(types, from: from, key: key);
  }

  @override
  String write(
    AgentTypes types, {
    required String value,
    required String path,
  }) {
    final written = types.write(_item, value: 'item', path: '$path[]');

    if (written == 'item') return value;

    return '[for (final item in $value) $written]';
  }
}
