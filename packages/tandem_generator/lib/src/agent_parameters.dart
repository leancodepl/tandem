part of 'agent_types.dart';

typedef GeneratedParameters = ({Map<String, Object?> schema, String arguments});

final class _AgentParameters(final AgentTypes _types) {
  Map<String, Object?> schema(
    List<FormalParameterElement> parameters, {
    required String prefix,
    InterfaceType? owner,
  }) {
    final properties = <String, Object?>{};
    final required = <String>[];

    for (final parameter in parameters) {
      final name = parameter.displayName;
      final type = parameter.type;
      final path = '$prefix$name';
      final isRequired =
          !type.isNullable && !parameter.defaultValueOrigin.hasDefaultValue;

      if (isRequired) {
        required.add(name);
      } else if (type.isDartCoreList) {
        throw AgentTypeError.optionalList(_types._element, path: path);
      }

      properties[name] = _parameterSchema(parameter, path: path, owner: owner);
    }

    return {
      'type': 'object',
      'description': ?documentationOf(owner?.element),
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  String arguments(
    List<FormalParameterElement> parameters, {
    required String from,
  }) {
    final arguments = <String>[];

    for (final parameter in parameters) {
      final value = _readParameter(parameter, from: from);

      if (parameter.isNamed) {
        arguments.add('${parameter.displayName}: $value');
      } else {
        arguments.add(value);
      }
    }

    return arguments.join(', ');
  }

  Map<String, Object?> _parameterSchema(
    FormalParameterElement parameter, {
    required String path,
    required InterfaceType? owner,
  }) {
    final helper = _types._helperFor(
      parameter.type,
      operation: .read,
      path: path,
    );
    final valueSchema = helper.schema(_types, path: path);

    return {
      // Not a list of types, which ag-ui-adk 0.9.0 fails on.
      if (parameter.type.isNullable)
        'anyOf': [
          valueSchema,
          {'type': 'null'},
        ]
      else
        ...valueSchema,
      'description': ?_documentation(parameter, owner: owner),
    };
  }

  String _readParameter(
    FormalParameterElement parameter, {
    required String from,
  }) {
    final name = parameter.displayName;
    final key = DartLiteral.json(name);
    final helper = _types._helperFor(
      parameter.type,
      operation: .read,
      path: name,
    );
    final code = helper.read(_types, from: from, key: key, name: name);
    final fallback = _defaultValue(parameter);

    if (fallback == null) return code;

    return '$from.json.containsKey($key) ? $code : $fallback';
  }

  String? _defaultValue(FormalParameterElement parameter) {
    final origin = parameter.defaultValueOrigin;

    if (!origin.hasDefaultValue) return null;

    final value = origin.computeConstantValue();

    if (value == null || value.isNull) return null;

    if (parameter.type.element is! ExtensionTypeElement) {
      final literal = value.toBoolValue() ?? value.toIntValue();

      if (literal != null) return '$literal';

      final number = value.toDoubleValue();

      if (number != null && number.isFinite) return '$number';

      final text = value.toStringValue();

      if (text != null) return DartLiteral.json(text);

      if (value.type case InterfaceType(:final EnumElement element)) {
        final index = value.getField('index')?.toIntValue();

        if (index != null) return '.${element.constants[index].name}';
      }
    }

    throw AgentTypeError.unsupportedDefault(
      _types._element,
      parameterName: parameter.displayName,
    );
  }

  static String? _documentation(
    FormalParameterElement parameter, {
    required InterfaceType? owner,
  }) {
    final getter = owner?.lookUpGetter(
      parameter.displayName,
      owner.element.library,
    );

    return documentationOf(getter) ?? documentationOf(parameter);
  }
}

extension on FormalParameterElement {
  FormalParameterElement get defaultValueOrigin {
    final constructor = enclosingElement;

    if (constructor is! ConstructorElement) return this;

    final target = constructor.redirectedConstructor;

    if (target == null) return this;

    for (final candidate in target.formalParameters) {
      if (candidate.name == name) return candidate.defaultValueOrigin;
    }

    return this;
  }
}
