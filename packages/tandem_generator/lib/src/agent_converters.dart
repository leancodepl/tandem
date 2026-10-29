import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tandem_generator/src/agent_generation_error.dart';
import 'package:tandem_generator/src/agent_type_error.dart';
import 'package:tandem_generator/src/agent_types.dart';

/// The `JsonConverter`s that an annotation lists in `converters:`, by the
/// type each converts, and the declaration of the list that the generated
/// code reads them from.
final class const AgentConverters._(
  final Map<DartType, AgentConverter> _byType, {

  /// A top-level constant of the generated code: the annotation's list as
  /// it is written, or empty when it lists none.
  required final String declaration,
}) {
  const new none() : this._(const {}, declaration: '');

  static const _jsonConverter = TypeChecker.typeNamedLiterally(
    'JsonConverter',
    inPackage: 'json_annotation',
  );

  /// Reads `converters:` of [annotation] on [type], whose generated code
  /// names the list [listName].
  static Future<AgentConverters> read(
    ConstantReader annotation,
    ClassElement type, {
    required String listName,
    required BuildStep buildStep,
  }) async {
    final values = annotation.peek('converters')?.listValue ?? const [];

    if (values.isEmpty) return const .none();

    final byType = <DartType, AgentConverter>{};

    for (final (index, value) in values.indexed) {
      final converter = _read(value, code: '$listName[$index]', type: type);
      final converted = converter.converted;

      if (byType[converted] case final other?) {
        throw AgentTypeError.twoConverters(
          type,
          converted: converted,
          first: other.className,
          second: converter.className,
        );
      }

      byType[converted] = converter;
    }

    final source = await _listSource(type, buildStep);

    return ._(byType, declaration: 'const List<Object> $listName = $source;');
  }

  /// The converter for exactly [type], without `?`.
  AgentConverter? operator [](DartType type) => _byType[type];

  static AgentConverter _read(
    DartObject value, {
    required String code,
    required ClassElement type,
  }) {
    final converterType = value.type;
    final supertype = switch (converterType) {
      InterfaceType(:final allSupertypes) =>
        allSupertypes.where(_jsonConverter.isExactlyType).firstOrNull,
      _ => null,
    };

    if (converterType is! InterfaceType || supertype == null) {
      throw AgentTypeError.notConverter(type, value: value);
    }

    final [converted, json] = supertype.typeArguments;

    if (converted.nullabilitySuffix != .none) {
      throw AgentTypeError.nullableConverter(
        type,
        className: converterType.element.displayName,
        converted: converted,
        nonNull: type.library.typeSystem.promoteToNonNull(converted),
        json: json,
      );
    }

    return (
      code: code,
      converted: converted,
      json: json,
      id: '${AgentTypes.idOf(converterType)}(${_fields(value)})',
      className: converterType.element.displayName,
      element: converterType.element,
    );
  }

  static Future<String> _listSource(
    ClassElement type,
    BuildStep buildStep,
  ) async {
    final source = await buildStep.resolver.astNodeFor(
      type.firstFragment,
      resolve: true,
    );
    final metadata = switch (source) {
      ClassDeclaration(:final metadata) => metadata,
      _ => const <Annotation>[],
    };

    for (final annotation in metadata) {
      for (final argument in annotation.arguments?.arguments ?? const []) {
        if (argument case NamedArgument(:final name, :final argumentExpression)
            when name.lexeme == 'converters') {
          return argumentExpression.toSource();
        }
      }
    }

    throw AgentGenerationError.missingConverterSource(type);
  }

  /// The constant fields of a converter and of its superclasses, so that two
  /// converters of one class with another configuration differ.
  static String _fields(DartObject value) => _fieldValues(value).join(', ');

  static List<String> _fieldValues(DartObject value) => [
    if (value.type case InterfaceType(:final element))
      for (final field in element.fields)
        if (!field.isStatic &&
            (field.isOriginDeclaration ||
                field.isOriginDeclaringFormalParameter))
          '${field.displayName}: ${_constant(value.getField(field.displayName))}',
    // The analyzer keeps the object the superclass constructor built here.
    if (value.getField('(super)') case final superclass?)
      ..._fieldValues(superclass),
  ];

  static String _constant(DartObject? value) {
    if (value == null || value.isNull) return 'null';

    if (value.toStringValue() case final string?) return jsonEncode(string);

    final literal =
        value.toBoolValue() ?? value.toIntValue() ?? value.toDoubleValue();

    if (literal != null) return '$literal';

    if (value.toListValue() case final items?) {
      return '[${items.map(_constant).join(', ')}]';
    }

    if (value.toSetValue() case final items?) {
      return '{${items.map(_constant).join(', ')}}';
    }

    if (value.toMapValue() case final entries?) {
      final pairs = [
        for (final MapEntry(:key, :value) in entries.entries)
          '${_constant(key)}: ${_constant(value)}',
      ];

      return '{${pairs.join(', ')}}';
    }

    if (value.toRecordValue() case (:final positional, :final named)?) {
      final fields = [
        ...positional.map(_constant),
        for (final MapEntry(:key, :value) in named.entries)
          '$key: ${_constant(value)}',
      ];

      return '(${fields.join(', ')})';
    }

    if (value.toTypeValue() case final type?) return AgentTypes.idOf(type);

    if (value.toSymbolValue() case final symbol?) return '#$symbol';

    if (value.toFunctionValue() case final function?) {
      final owner = switch (function.enclosingElement) {
        InterfaceElement(:final displayName) => '$displayName.',
        _ => '',
      };

      return '${function.library.uri}#$owner${function.displayName}';
    }

    return switch (value.type) {
      InterfaceType(:final EnumElement element) =>
        '${element.displayName}.${element.constants[value.getField('index')?.toIntValue() ?? 0].name}',
      final InterfaceType type => '${AgentTypes.idOf(type)}(${_fields(value)})',
      _ => '$value',
    };
  }
}

/// One `JsonConverter<T, S>`: its code in the generated code, `T` as
/// `converted`, `S` as `json`, and an id with its configuration.
typedef AgentConverter = ({
  String code,
  DartType converted,
  DartType json,
  String id,
  String className,
  InterfaceElement element,
});
