import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

/// How the types of one getter or method of an agent list map to JSON.
///
/// The agent sends and sees `String`, `int`, `double`, `num`, `bool`,
/// `DateTime` as ISO 8601, enums by name, extension types over the first five,
/// lists, and plain classes. Tandem builds an extension type as `Code(value)`,
/// so its unnamed constructor must be public and take only the value, as a
/// positional parameter of the non-null type it wraps. A plain class is a
/// non-generic class outside the SDK whose public unnamed constructor takes
/// only parameters named like its getters, all named except at most one.
/// Tandem builds it with that constructor and writes it as an object of those
/// getters, so it needs neither `fromJson` nor `toJson`.
///
/// The generated code names only core types. It builds classes, extension
/// types and enum values with dot shorthands, so it compiles without imports
/// of the libraries that declare them.
final class AgentTypes(final ExecutableElement _element) {
  final _visitingClasses = <ClassElement>{};

  /// The JSON Schema of an object with a property for each of [parameters],
  /// which the agent sends at [prefix] plus the parameter's name. [owner] is
  /// the class whose constructor takes them, null for a method.
  Map<String, Object?> object(
    List<FormalParameterElement> parameters,
    String prefix, {
    InterfaceType? owner,
  }) {
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final parameter in parameters) {
      final name = parameter.displayName;
      final type = parameter.type;
      final nullable = type.nullabilitySuffix != .none;
      if (!nullable && !_origin(parameter).hasDefaultValue) {
        required.add(name);
      } else if (_listItemType(type) != null) {
        throw _error(
          '$prefix$name is a list, so the agent must send it: drop the ? and '
          'the default value',
        );
      }
      final valueSchema = schema(type, '$prefix$name');
      properties[name] = {
        // Not a list of types, which ag-ui-adk 0.9.0 fails on.
        if (nullable)
          'anyOf': [
            valueSchema,
            {'type': 'null'},
          ]
        else
          ...valueSchema,
        'description': ?_doc(parameter, owner),
      };
    }
    return {
      'type': 'object',
      'description': ?documentationOf(owner?.element),
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  Map<String, Object?> schema(DartType type, String path) {
    if (_scalarSchema(type) case final scalar?) {
      if (type.element case final ExtensionTypeElement extension) {
        _checkValueConstructor(extension, path);
      }
      return scalar;
    }
    if (_listItemType(type) case final item?) {
      if (item.nullabilitySuffix != .none || _listItemType(item) != null) {
        throw _error(
          '$path: the agent sends lists of items that are neither null nor '
          'lists',
        );
      }
      return {'type': 'array', 'items': schema(item, '$path[]')};
    }
    return _plain(
      type,
      'send',
      path,
      (type, fields) => object(
        [for (final (:parameter, getter: _) in fields) parameter],
        '$path.',
        owner: type,
      ),
    );
  }

  /// The arguments that pass [parameters] in order, read from the `ToolArgs`
  /// expression [args]. Call it after [object], which checks the types.
  String arguments(List<FormalParameterElement> parameters, String args) => [
    for (final parameter in parameters)
      if (parameter.isNamed)
        '${parameter.displayName}: ${_read(parameter, args)}'
      else
        _read(parameter, args),
  ].join(', ');

  /// Code that writes [value], an expression of [type] that the agent sees
  /// at [path], as JSON.
  String write(DartType type, String value, String path) {
    final nullable = type.nullabilitySuffix != .none;
    if (_scalarSchema(type) != null) {
      final dot = nullable ? '?.' : '.';

      return switch (type) {
        _ when _isDateTime(type) => '$value${dot}toIso8601String()',
        InterfaceType(element: EnumElement()) => '$value${dot}name',
        _ => value,
      };
    }
    if (nullable) {
      final name = value.split('.').last;
      final nonNull = _element.library.typeSystem.promoteToNonNull(type);
      final written = write(nonNull, name, path);

      return written == name
          ? value
          : 'switch ($value) { null => null, final $name => $written }';
    }
    if (_listItemType(type) case final item?) {
      final written = write(item, 'item', '$path[]');

      return written == 'item'
          ? value
          : '[for (final item in $value) $written]';
    }
    return _plain(type, 'see', path, (_, fields) {
      String entry(_Field field) {
        final name = field.parameter.displayName;
        final written = write(
          field.getter.returnType,
          '$value.$name',
          '$path.$name',
        );

        return '${dartJsonLiteral(name)}: $written';
      }

      return '{${fields.map(entry).join(', ')}}';
    });
  }

  String _read(FormalParameterElement parameter, String args) {
    final name = parameter.displayName;
    final key = dartJsonLiteral(name);
    final type = parameter.type;
    final code = switch (_listItemType(type)) {
      final item? when _isExtension(item) =>
        '[for (final item in $args.readList<${_erasure(item)}>($key)) '
            '.new(item)]',
      final item? when _scalarSchema(item) == null =>
        '$args.readObjects($key, (item) => .new(${_build(item, 'item')}))',
      final item? => '$args.readList($key${_oneOf(item)})',
      null when _isExtension(type) && type.nullabilitySuffix == .none =>
        '.new($args.read($key))',
      null when _isExtension(type) =>
        'switch ($args.read<${_erasure(type)}>($key)) '
            '{ null => null, final $name => .new($name) }',
      null when _scalarSchema(type) == null =>
        '$args.readObject($key, ($name) => .new(${_build(type, name)}))',
      null => '$args.read($key${_oneOf(type)})',
    };

    // An explicit null is a value: the default is only for a missing key.
    return switch (_default(parameter)) {
      final fallback? => '$args.json.containsKey($key) ? $code : $fallback',
      null => code,
    };
  }

  String _build(DartType type, String args) => _plain(
    type,
    'send',
    args,
    (_, fields) =>
        arguments([for (final field in fields) field.parameter], args),
  );

  T _plain<T>(
    DartType type,
    String verb,
    String path,
    T Function(InterfaceType type, List<_Field> fields) body,
  ) {
    if (type case InterfaceType(:final ClassElement element, typeArguments: [])
        when element.isPublic && !element.library.isInSdk) {
      final name = element.displayName;
      final constructor = switch (element.unnamedConstructor) {
        final constructor?
            when constructor.isPublic &&
                (!element.isAbstract || constructor.isFactory) =>
          constructor,
        _ => throw _error(
          '$path: Tandem builds $name with its unnamed constructor, and it '
          'has no public one',
        ),
      };
      final parameters = constructor.formalParameters;
      if (parameters.isEmpty) {
        throw _error(
          '$path: Tandem writes $name through its constructor parameters, and '
          'it has none',
        );
      }
      if (parameters.where((parameter) => parameter.isPositional).length > 1) {
        throw _error(
          '$path: make the parameters of $name named, so that reordering them '
          'cannot swap values in code generated before',
        );
      }
      final fields = [
        for (final parameter in parameters)
          (
            parameter: parameter,
            getter: switch (type.lookUpGetter(
              parameter.displayName,
              element.library,
            )) {
              final getter? when !getter.isStatic && parameter.isPublic =>
                getter,
              _ => throw _error(
                '$path: Tandem writes $name through the getters named like '
                'its constructor parameters, and it has no getter '
                '${parameter.displayName}',
              ),
            },
          ),
      ];
      if (!_visitingClasses.add(element)) {
        throw _error('$path: $name contains itself');
      }
      try {
        return body(type, fields);
      } finally {
        _visitingClasses.remove(element);
      }
    }
    throw _cannot(verb, type, path);
  }

  void _checkValueConstructor(ExtensionTypeElement extension, String path) {
    final value = _element.library.typeSystem.promoteToNonNull(
      extension.typeErasure,
    );
    final takesValue = switch (extension.unnamedConstructor) {
      ConstructorElement(
        isPublic: true,
        formalParameters: [
          FormalParameterElement(isPositional: true, :final type),
        ],
      ) =>
        type == value,
      _ => false,
    };
    if (!takesValue) {
      final name = extension.displayName;
      throw _error(
        '$path: Tandem builds $name as $name(value), so its unnamed '
        'constructor must be public and take only the value: one positional, '
        'non-null ${value.getDisplayString()}',
      );
    }
  }

  String? _default(FormalParameterElement parameter) {
    final origin = _origin(parameter);
    if (!origin.hasDefaultValue) {
      return null;
    }
    final value = origin.computeConstantValue();
    if (value == null || value.isNull) {
      return null;
    }
    if (!_isExtension(parameter.type)) {
      if (value.toBoolValue() ?? value.toIntValue() case final literal?) {
        return '$literal';
      }
      if (value.toDoubleValue() case final number? when number.isFinite) {
        return '$number';
      }
      if (value.toStringValue() case final text?) {
        return dartJsonLiteral(text);
      }
      if (value.type case InterfaceType(
        element: EnumElement(:final constants),
      )) {
        if (value.getField('index')?.toIntValue() case final index?) {
          return '.${constants[index].name}';
        }
      }
    }
    throw _error(
      'Tandem copies only literals, enum values and null as default values. '
      'Make ${parameter.displayName} required or nullable instead',
    );
  }

  // A redirecting factory, as freezed writes, keeps the default on its target.
  static FormalParameterElement _origin(FormalParameterElement parameter) {
    if (parameter.enclosingElement case ConstructorElement(
      redirectedConstructor: final target?,
    )) {
      for (final candidate in target.formalParameters) {
        if (candidate.name == parameter.name) {
          return _origin(candidate);
        }
      }
    }
    return parameter;
  }

  static String? _doc(FormalParameterElement parameter, InterfaceType? owner) =>
      documentationOf(
        owner?.lookUpGetter(parameter.displayName, owner.element.library),
      ) ??
      documentationOf(parameter);

  static Map<String, Object?>? _scalarSchema(DartType type) => switch (type) {
    _ when type.isDartCoreString => {'type': 'string'},
    _ when type.isDartCoreInt => {'type': 'integer'},
    _ when type.isDartCoreDouble || type.isDartCoreNum => {'type': 'number'},
    _ when type.isDartCoreBool => {'type': 'boolean'},
    _ when _isDateTime(type) => {'type': 'string', 'format': 'date-time'},
    InterfaceType(element: EnumElement(:final constants)) => {
      'type': 'string',
      'enum': [for (final constant in constants) constant.name],
    },
    _ when _isExtension(type) => switch (type.extensionTypeErasure) {
      final erasure
          when erasure.isDartCoreString ||
              erasure.isDartCoreInt ||
              erasure.isDartCoreDouble ||
              erasure.isDartCoreNum ||
              erasure.isDartCoreBool =>
        _scalarSchema(erasure),
      _ => null,
    },
    _ => null,
  };

  static bool _isExtension(DartType type) =>
      type is InterfaceType && type.element is ExtensionTypeElement;

  static String _erasure(DartType type) =>
      type.extensionTypeErasure.getDisplayString();

  static bool _isDateTime(DartType type) =>
      type is InterfaceType &&
      type.element.name == 'DateTime' &&
      type.element.library.isDartCore;

  static DartType? _listItemType(DartType type) => switch (type) {
    InterfaceType(isDartCoreList: true, typeArguments: [final item]) => item,
    _ => null,
  };

  static String _oneOf(DartType type) => switch (type) {
    InterfaceType(element: EnumElement(:final constants)) =>
      ', oneOf: [${constants.map((constant) => '.${constant.name}').join(', ')}]',
    _ => '',
  };

  InvalidGenerationSource _cannot(String verb, DartType type, String path) =>
      _error(
        'The agent cannot $verb ${type.getDisplayString()} at $path. It can '
        '$verb String, int, double, num, bool, DateTime, enums, lists and '
        'plain classes',
      );

  InvalidGenerationSource _error(String message) =>
      InvalidGenerationSource('$message.', element: _element);
}

typedef _Field = ({FormalParameterElement parameter, GetterElement getter});

/// The doc comment of [element] without the slashes, or null for none. The
/// getter of a field has the field's comment.
String? documentationOf(Element? element) {
  final comment = switch (element) {
    GetterElement(isOriginVariable: true, :final variable) =>
      variable.documentationComment,
    _ => element?.documentationComment,
  };

  return comment
      ?.split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^\s*/// ?'), ''))
      .join('\n')
      .trim();
}

/// [value], a JSON value, as Dart code. `jsonEncode` escapes the strings,
/// which then take the quotes the lints ask for: single, or double when that
/// saves escaping a `'`.
String dartJsonLiteral(Object? value) =>
    jsonEncode(value)
        .replaceAllMapped(_jsonString, (match) => _dartString(match[1] ?? ''));

final _jsonString = RegExp(r'"((?:[^"\\]|\\.)*)"');

String _dartString(String escaped) {
  final contents = escaped.replaceAll(r'$', r'\$');

  return contents.contains("'") && !contents.contains(r'\"')
      ? '"$contents"'
      : "'${contents.replaceAll(r'\"', '"').replaceAll("'", r"\'")}'";
}
