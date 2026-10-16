import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

/// How the types around one method or getter of an agent list map to JSON.
///
/// The agent sends and sees `String`, `int`, `double`, `num`, `bool`,
/// `DateTime` as ISO 8601, enums by name, extension types over the first five,
/// lists, and plain classes. A plain class is a non-generic class outside the
/// SDK whose public unnamed constructor takes only parameters named like its
/// getters, all of them named but at most one. Tandem builds it with that
/// constructor and writes it as an object of those getters, so it needs
/// neither `fromJson` nor `toJson`.
///
/// The generated code names only core types: it builds classes and extension
/// types with `.new` and enum values with `.name`, so it compiles without
/// imports of the libraries that declare them.
final class AgentTypes(
  /// The method or getter, where build errors point.
  final Element _element,
) {
  /// The types around [_element].
  this;

  final _open = <ClassElement>{};

  /// The JSON Schema of an object with a property for each of [parameters],
  /// which the agent sends at [prefix] and the parameter's name. [owner] is
  /// the class whose constructor takes them, or null for a method.
  Map<String, Object?> object(
    List<FormalParameterElement> parameters,
    String prefix, {
    InterfaceType? owner,
  }) {
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final parameter in parameters) {
      final name = parameter.name!;
      final type = parameter.type;
      if (type.nullabilitySuffix == .none &&
          !_origin(parameter).hasDefaultValue) {
        required.add(name);
      } else if (_item(type) != null) {
        throw _error(
          '$prefix$name is a list, so the agent must send it: drop the ? and '
          'the default value',
        );
      }
      properties[name] = {
        ...schema(type, '$prefix$name'),
        'description': ?_doc(parameter, owner),
      };
    }
    return {
      'type': 'object',
      'description': ?docText(owner?.element.documentationComment),
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  /// The JSON Schema of [type], which the agent sends at [path].
  Map<String, Object?> schema(DartType type, String path) {
    if (_scalar(type) case final scalar?) {
      if (_isExtension(type) && !_hasPublicConstructor(type)) {
        throw _error(
          '$path: Tandem builds ${type.getDisplayString()} with its unnamed '
          'constructor, and it has no public one',
        );
      }
      return scalar;
    }
    if (_item(type) case final item?) {
      if (item.nullabilitySuffix != .none || _item(item) != null) {
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
        '${parameter.name}: ${_read(parameter, args)}'
      else
        _read(parameter, args),
  ].join(', ');

  /// Code that writes [value], an expression of [type] that the agent sees
  /// at [path], as JSON.
  String write(DartType type, String value, String path) {
    final nullable = type.nullabilitySuffix != .none;
    if (_scalar(type) != null) {
      final dot = nullable ? '?.' : '.';
      return switch (type) {
        _ when _isDateTime(type) => '$value${dot}toIso8601String()',
        InterfaceType(element: EnumElement()) => '$value${dot}name',
        _ => value,
      };
    }
    if (nullable) {
      final name = value.split('.').last;
      final nonNull = _element.library!.typeSystem.promoteToNonNull(type);
      final written = write(nonNull, name, path);
      return written == name
          ? value
          : 'switch ($value) { null => null, final $name => $written }';
    }
    if (_item(type) case final item?) {
      final written = write(item, 'item', '$path[]');
      return written == 'item'
          ? value
          : '[for (final item in $value) $written]';
    }
    return _plain(type, 'see', path, (_, fields) {
      String entry(_Field field) {
        final name = field.parameter.name!;
        final written = write(
          field.getter.returnType,
          '$value.$name',
          '$path.$name',
        );
        return '${literal(name)}: $written';
      }

      return '{${fields.map(entry).join(', ')}}';
    });
  }

  String _read(FormalParameterElement parameter, String args) {
    final name = parameter.name!;
    final key = literal(name);
    final type = parameter.type;
    final code = switch (_item(type)) {
      final item? when _isExtension(item) =>
        '[for (final item in $args.readList<${_erasure(item)}>($key)) '
            '.new(item)]',
      final item? when _scalar(item) == null =>
        '$args.readObjects($key, (item) => .new(${_build(item, 'item')}))',
      final item? => '$args.readList($key${_oneOf(item)})',
      null when _isExtension(type) && type.nullabilitySuffix == .none =>
        '.new($args.read($key))',
      null when _isExtension(type) =>
        'switch ($args.read<${_erasure(type)}?>($key)) '
            '{ null => null, final $name => .new($name) }',
      null when _scalar(type) == null =>
        '$args.readObject($key, ($name) => .new(${_build(type, name)}))',
      null => '$args.read($key${_oneOf(type)})',
    };
    return switch (_default(parameter)) {
      final fallback? => '$code ?? $fallback',
      null => code,
    };
  }

  String _build(DartType type, String args) {
    final element = (type as InterfaceType).element as ClassElement;
    return arguments(element.unnamedConstructor!.formalParameters, args);
  }

  /// Runs [body] with the constructor parameters of [type], which must be a
  /// plain class, and the getters that read them back.
  T _plain<T>(
    DartType type,
    String verb,
    String path,
    T Function(InterfaceType type, List<_Field> fields) body,
  ) {
    if (type case InterfaceType(:final ClassElement element, typeArguments: [])
        when element.isPublic && !element.library.isInSdk) {
      final name = element.name;
      final constructor = element.unnamedConstructor;
      if (constructor == null ||
          !constructor.isPublic ||
          element.isAbstract && !constructor.isFactory) {
        throw _error(
          '$path: Tandem builds $name with its unnamed constructor, and it '
          'has no public one',
        );
      }
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
              parameter.name!,
              element.library,
            )) {
              final getter? when !getter.isStatic && parameter.isPublic =>
                getter,
              _ => throw _error(
                '$path: Tandem writes $name through the getters named like '
                'its constructor parameters, and it has no getter '
                '${parameter.name}',
              ),
            },
          ),
      ];
      if (!_open.add(element)) {
        throw _error('$path: $name contains itself');
      }
      try {
        return body(type, fields);
      } finally {
        _open.remove(element);
      }
    }
    throw _cannot(verb, type, path);
  }

  /// The default value of [parameter] as code, or null for none or `null`.
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
        return literal(text);
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
      'Make ${parameter.name} required or nullable instead',
    );
  }

  /// The parameter that holds the default value of [parameter]: a
  /// redirecting factory, as freezed writes, keeps it on its target.
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

  /// The doc comment of the getter of [owner] behind [parameter], or of the
  /// parameter itself.
  static String? _doc(FormalParameterElement parameter, InterfaceType? owner) {
    final getter = owner?.lookUpGetter(parameter.name!, owner.element.library);
    final comment = switch (getter) {
      GetterElement(isOriginVariable: true, :final variable) =>
        variable.documentationComment,
      _ => getter?.documentationComment,
    };
    return docText(comment) ?? docText(parameter.documentationComment);
  }

  static Map<String, Object?>? _scalar(DartType type) => switch (type) {
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
        _scalar(erasure),
      _ => null,
    },
    _ => null,
  };

  static bool _isExtension(DartType type) =>
      type is InterfaceType && type.element is ExtensionTypeElement;

  static bool _hasPublicConstructor(DartType type) =>
      (type as InterfaceType).element.unnamedConstructor?.isPublic ?? false;

  /// The core type behind the extension type [type], as code.
  static String _erasure(DartType type) =>
      (type as InterfaceType).extensionTypeErasure.element!.name!;

  static bool _isDateTime(DartType type) =>
      type is InterfaceType &&
      type.element.name == 'DateTime' &&
      type.element.library.isDartCore;

  static DartType? _item(DartType type) => switch (type) {
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

/// A constructor parameter of a plain class and the getter that reads it
/// back.
typedef _Field = ({FormalParameterElement parameter, GetterElement getter});

/// [comment] without the slashes, or null for none.
String? docText(String? comment) => comment
    ?.split('\n')
    .map((line) => line.replaceFirst(RegExp(r'^\s*/// ?'), ''))
    .join('\n')
    .trim();

/// [value], a string or a JSON structure of strings, as Dart code.
String literal(Object? value) => switch (value) {
  String() => _string(value),
  List<Object?>() => '[${value.map(literal).join(', ')}]',
  Map<String, Object?>() =>
    '{${[for (final MapEntry(:key, :value) in value.entries) '${literal(key)}: ${literal(value)}'].join(', ')}}',
  _ => '$value',
};

/// [text] as a Dart string literal, in double quotes when that saves escapes.
String _string(String text) {
  final quote = text.contains("'") && !text.contains('"') ? '"' : "'";
  final escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll(quote, '\\$quote')
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return '$quote$escaped$quote';
}
