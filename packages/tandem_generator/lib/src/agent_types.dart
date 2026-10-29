import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:tandem_generator/src/agent_class.dart';
import 'package:tandem_generator/src/agent_converters.dart';
import 'package:tandem_generator/src/agent_type_error.dart';
import 'package:tandem_generator/src/dart_literal.dart';
import 'package:tandem_generator/src/source_documentation.dart';
import 'package:tandem_generator/src/type_names.dart';

/// Writes the `AgentType` of a Dart type as an expression of the generated
/// code, such as `.list(.object(...))`. The expression names no type: Dart
/// infers each from where it stands, a getter or a parameter, so a library
/// needs no import for the types inside the ones it declares.
final class AgentTypes(
  final Element _source, {
  final AgentConverters _converters = const .none(),
}) {
  final _visiting = <String>{};
  final _converting = <DartType>{};

  TypeSystem get _typeSystem => _library.typeSystem;

  LibraryElement get _library => switch (_source.library) {
    final library? => library,
    null => throw StateError('${_source.displayName} has no library.'),
  };

  /// The expression of the `AgentType` of [type], which is at [path] for the
  /// messages of a failed build.
  String describe(DartType type, {required String path}) {
    if (type.isNullable) {
      final value = describe(_typeSystem.promoteToNonNull(type), path: path);

      return '.nullable($value)';
    }

    if (_converters[type] case final converter?) {
      return _converted(converter, path: path);
    }

    if (_builtIns[idOf(type)] case final builtIn?) return builtIn;

    if (_scalars[_scalarName(type)] case final scalar?) return scalar;

    if (type is InterfaceType) {
      if (type.isDartCoreList) {
        return '.list(${describe(type.typeArguments.single, path: '$path[]')})';
      }

      if (type.isDartCoreSet) {
        return '.set(${describe(type.typeArguments.single, path: '$path[]')})';
      }

      switch (type.element) {
        case final EnumElement element:
          return _enum(element);
        case final ExtensionTypeElement element:
          return _extension(type, element, path: path);
        case final ClassElement element when _tokenNames(element).isNotEmpty:
          return _token(element);
        case ClassElement():
          return _object(type, path: path);
        default:
      }
    }

    throw AgentTypeError.unsupported(_source, type: type, path: path);
  }

  /// The id of [type], as `AgentType.id` gives it at runtime.
  static String idOf(DartType type) {
    final nullable = type.isNullable ? '?' : '';

    if (type case InterfaceType(isDartCoreList: true, :final typeArguments)) {
      return 'List<${idOf(typeArguments.single)}>$nullable';
    }

    if (type case InterfaceType(isDartCoreSet: true, :final typeArguments)) {
      return 'Set<${idOf(typeArguments.single)}>$nullable';
    }

    final element = type.element;
    final name = element?.displayName ?? type.getDisplayString();
    final library = element?.library?.uri ?? Uri();
    final arguments = switch (type) {
      InterfaceType(:final typeArguments) when typeArguments.isNotEmpty =>
        '<${typeArguments.map(idOf).join(',')}>',
      _ => '',
    };

    return '$library#$name$arguments$nullable';
  }

  String _converted(AgentConverter converter, {required String path}) {
    final (:code, :converted, :json, :id, :className, :element) = converter;

    if (!_converting.add(converted)) {
      throw AgentTypeError.converterCycle(
        _source,
        className: className,
        path: path,
      );
    }

    try {
      var jsonCode = describe(json, path: path);

      if (!_isContextFree(json)) {
        final name = TypeNames(_library).name(json);

        if (name == null) {
          throw AgentTypeError.unnamedJson(
            _source,
            className: className,
            json: json,
            path: path,
          );
        }

        jsonCode = '.typed<$name>($jsonCode)';
      }

      final typeId = DartLiteral.json(idOf(converted));
      final description = _describedBy(element);
      final object = converted.isAgentClass ? ', object: true' : '';

      return '.converted($code, $jsonCode, id: $typeId, '
          'converterId: ${DartLiteral.json(id)}$description$object)';
    } finally {
      _converting.remove(converted);
    }
  }

  /// Whether the description of [type] has its type without a context, so
  /// Dart infers `S` of a converter from it.
  bool _isContextFree(DartType type) {
    final nonNull = _typeSystem.promoteToNonNull(type);

    if (_converters[nonNull] != null) return false;

    if (_builtIns.containsKey(idOf(nonNull))) return true;

    if (_scalars.containsKey(_scalarName(nonNull))) return true;

    return switch (nonNull) {
      InterfaceType(isDartCoreList: true, :final typeArguments) ||
      InterfaceType(
        isDartCoreSet: true,
        :final typeArguments,
      ) => _isContextFree(typeArguments.single),
      _ => false,
    };
  }

  String _enum(EnumElement element) {
    final values = [
      for (final constant in element.constants) '.${constant.name}',
    ].join(', ');
    final id = DartLiteral.json(idOf(element.thisType));
    final description = _describedBy(element);

    return '.enumeration([$values], id: $id$description)';
  }

  String _token(ClassElement element) {
    final members = [
      for (final name in _tokenNames(element))
        '${DartLiteral.json(name)}: .$name',
    ].join(', ');
    final id = DartLiteral.json(idOf(element.thisType));
    final description = _describedBy(element);

    return '.token({$members}, id: $id$description)';
  }

  String _extension(
    InterfaceType type,
    ExtensionTypeElement element, {
    required String path,
  }) {
    final representation = _typeSystem.promoteToNonNull(element.typeErasure);
    final value = _scalars[_scalarName(representation)];
    final constructor = element.unnamedConstructor;

    if (value == null) {
      throw AgentTypeError.unsupported(_source, type: type, path: path);
    }

    if (constructor == null || !constructor.acceptsValue(representation)) {
      throw AgentTypeError.invalidValueConstructor(
        _source,
        className: element.displayName,
        valueType: representation,
        path: path,
      );
    }

    final id = DartLiteral.json(idOf(type));

    return '.extension($value, (value) => .new(value), id: $id)';
  }

  String _object(InterfaceType type, {required String path}) {
    final id = idOf(type);

    if (!_visiting.add(id)) {
      throw AgentTypeError.recursiveClass(
        _source,
        className: type.element.displayName,
        path: path,
      );
    }

    try {
      final object = AgentClass.read(type, source: _source, path: path);
      final fields = [
        for (final field in object.fields) _field(field, path: path),
      ].join(', ');
      final arguments = constructorArguments(
        [for (final field in object.fields) field.parameter],
        from: 'values',
        read: (name) => "values('$name')",
      );
      final description = _describedBy(type.element);

      return '.object(id: ${DartLiteral.json(id)}$description, '
          'fields: (field) => [$fields], '
          'build: (values) => .new($arguments))';
    } finally {
      _visiting.remove(id);
    }
  }

  String _field(AgentField field, {required String path}) {
    final name = field.parameter.displayName;
    final type = describe(field.parameter.type, path: '$path.$name');
    final documentation =
        documentationOf(field.getter) ?? documentationOf(field.parameter);
    final description = switch (documentation) {
      final text? => ', description: ${DartLiteral.json(text)}',
      null => '',
    };
    final optional = field.parameter.isOptionalForAgent
        ? ', required: false'
        : '';

    return "field('$name', (value) => value.$name$description$optional)"
        '.as($type)';
  }

  /// The arguments of a constructor or a method with [parameters], each
  /// read by [read] from its name, and a parameter the agent may leave out
  /// keeping its default.
  String constructorArguments(
    List<FormalParameterElement> parameters, {
    required String from,
    required String Function(String name) read,
  }) {
    final arguments = <String>[];

    for (final parameter in parameters) {
      final name = parameter.displayName;
      final value = read(name);
      final fallback = defaultValue(parameter);
      final argument = switch (fallback) {
        final fallback? => "$from.has('$name') ? $value : $fallback",
        null => value,
      };

      arguments.add(parameter.isNamed ? '$name: $argument' : argument);
    }

    return arguments.join(', ');
  }

  /// The default value of [parameter] as code, or null when it has none
  /// other than null. Throws when it has one that Tandem cannot copy.
  String? defaultValue(FormalParameterElement parameter) {
    final origin = parameter.defaultValueOrigin;

    if (!origin.hasDefaultValue) return null;

    if (copyDefault(origin) case (:final code)) return code;

    throw AgentTypeError.unsupportedDefault(
      _source,
      parameterName: parameter.displayName,
    );
  }

  /// The default value of [parameter] as code: null for none or null, and a
  /// null record when Tandem cannot copy it.
  ({String? code})? copyDefault(FormalParameterElement parameter) {
    final value = parameter.computeConstantValue();

    if (value == null || value.isNull) return (code: null);

    final literal = value.toBoolValue() ?? value.toIntValue();

    if (literal != null) return (code: '$literal');

    final number = value.toDoubleValue();

    if (number != null && number.isFinite) return (code: '$number');

    final text = value.toStringValue();

    if (text != null) return (code: DartLiteral.json(text));

    final type = value.type;

    if (type is InterfaceType && type.element is ExtensionTypeElement) {
      return null;
    }

    if (type case InterfaceType(:final EnumElement element)) {
      final index = value.getField('index')?.toIntValue();

      if (index != null) return (code: '.${element.constants[index].name}');
    }

    if (type case InterfaceType(:final ClassElement element)) {
      for (final name in _tokenNames(element)) {
        if (element.getField(name)?.computeConstantValue() == value) {
          return (code: '.$name');
        }
      }
    }

    return null;
  }

  String _describedBy(Element element) => switch (documentationOf(element)) {
    final text? => ', description: ${DartLiteral.json(text)}',
    null => '',
  };

  /// The names of the public `static const` members of [element] that are of
  /// its own type, in order, when it has no public constructor: a token
  /// class, such as a design system's text styles.
  static List<String> _tokenNames(ClassElement element) {
    if (element.constructors.any((c) => c.isPublic)) return const [];

    return [
      for (final field in element.fields)
        if (field.isStatic &&
            field.isConst &&
            field.isPublic &&
            field.type == element.thisType)
          field.displayName,
    ];
  }

  /// Whether [code], an expression of [describe], is a constant.
  static bool isConstant(String code) =>
      _scalars.containsValue(code) || _builtIns.containsValue(code);

  static const _builtIns = {
    'dart:ui#Color': '.color',
    '$_edgeInsets#EdgeInsetsGeometry': '.edgeInsetsGeometry',
    '$_edgeInsets#EdgeInsets': '.edgeInsets',
    '$_edgeInsets#EdgeInsetsDirectional': '.edgeInsetsDirectional',
    '$_alignment#AlignmentGeometry': '.alignmentGeometry',
    '$_alignment#Alignment': '.alignment',
    '$_alignment#AlignmentDirectional': '.alignmentDirectional',
  };

  static const _edgeInsets = 'package:flutter/src/painting/edge_insets.dart';
  static const _alignment = 'package:flutter/src/painting/alignment.dart';

  static const _scalars = {
    'String': '.string',
    'int': '.integer',
    'double': '.number',
    'num': '.numeric',
    'bool': '.boolean',
    'DateTime': '.dateTime',
    'Uri': '.uri',
  };

  static String? _scalarName(DartType type) {
    if (type is! InterfaceType || type.isNullable) return null;

    final element = type.element;
    final library = element.library;

    if (library.uri.toString() != 'dart:core') return null;

    return element.displayName;
  }
}

extension on DartType {
  bool get isNullable => nullabilitySuffix != .none;
}

extension AgentParameterRules on FormalParameterElement {
  /// Whether the agent may leave the parameter out: it is nullable or has a
  /// default value.
  bool get isOptionalForAgent =>
      type.nullabilitySuffix != .none || defaultValueOrigin.hasDefaultValue;

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

extension on ConstructorElement {
  bool acceptsValue(DartType valueType) {
    if (!isPublic || formalParameters.length != 1) return false;

    final parameter = formalParameters.single;

    return parameter.isPositional && parameter.type == valueType;
  }
}
