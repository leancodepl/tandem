part of '../agent_types.dart';

final class const _PrimitiveHelper._(final String _jsonType)
    extends _TypeHelper {
  static _PrimitiveHelper? tryFromDartType(DartType type) {
    if (type.isDartCoreString) return const _PrimitiveHelper._('string');
    if (type.isDartCoreInt) return const _PrimitiveHelper._('integer');
    if (type.isDartCoreDouble) return const _PrimitiveHelper._('number');
    if (type.isDartCoreNum) return const _PrimitiveHelper._('number');
    if (type.isDartCoreBool) return const _PrimitiveHelper._('boolean');

    return null;
  }

  @override
  Map<String, Object?> schema(AgentTypes types, {required String path}) => {
    'type': _jsonType,
  };
}

final class const _DateTimeHelper() extends _TypeHelper {
  @override
  Map<String, Object?> schema(AgentTypes types, {required String path}) => {
    'type': 'string',
    'format': 'date-time',
  };

  @override
  String write(
    AgentTypes types, {
    required String value,
    required String path,
  }) => '$value.toIso8601String()';

  @override
  String writeNullable(
    AgentTypes types, {
    required String value,
    required String path,
  }) => '$value?.toIso8601String()';
}

final class _EnumHelper(final EnumElement _element) extends _TypeHelper {
  @override
  Map<String, Object?> schema(AgentTypes types, {required String path}) => {
    'type': 'string',
    'enum': [for (final constant in _element.constants) constant.name],
  };

  @override
  String read(
    AgentTypes types, {
    required String from,
    required String key,
    required String name,
  }) => '$from.read($key, oneOf: [$_values])';

  @override
  String readList(
    AgentTypes types, {
    required String from,
    required String key,
  }) => '$from.readList($key, oneOf: [$_values])';

  @override
  String write(
    AgentTypes types, {
    required String value,
    required String path,
  }) => '$value.name';

  @override
  String writeNullable(
    AgentTypes types, {
    required String value,
    required String path,
  }) => '$value?.name';

  String get _values =>
      [for (final constant in _element.constants) '.${constant.name}']
          .join(', ');
}

final class _ExtensionHelper(
  final InterfaceType _type,
  final ExtensionTypeElement _element,
  final _PrimitiveHelper _representation,
) extends _TypeHelper {
  @override
  Map<String, Object?> schema(AgentTypes types, {required String path}) {
    _validateConstructor(types, path: path);

    return _representation.schema(types, path: path);
  }

  @override
  String read(
    AgentTypes types, {
    required String from,
    required String key,
    required String name,
  }) {
    if (!_type.isNullable) return '.new($from.read($key))';

    final erasure = _type.extensionTypeErasure.getDisplayString();

    return 'switch ($from.read<$erasure>($key)) '
        '{ null => null, final $name => .new($name) }';
  }

  @override
  String readList(
    AgentTypes types, {
    required String from,
    required String key,
  }) {
    final erasure = _type.extensionTypeErasure.getDisplayString();
    final list = '$from.readList<$erasure>($key)';

    return '[for (final item in $list) .new(item)]';
  }

  void _validateConstructor(AgentTypes types, {required String path}) {
    final valueType = types._element.library.typeSystem.promoteToNonNull(
      _element.typeErasure,
    );
    final constructor = _element.unnamedConstructor;

    if (constructor != null && constructor.acceptsValue(valueType)) return;

    throw AgentTypeError.invalidValueConstructor(
      types._element,
      className: _element.displayName,
      valueType: valueType,
      path: path,
    );
  }
}

extension on ConstructorElement {
  bool acceptsValue(DartType valueType) {
    if (!isPublic || formalParameters.length != 1) return false;

    final parameter = formalParameters.single;

    return parameter.isPositional && parameter.type == valueType;
  }
}
