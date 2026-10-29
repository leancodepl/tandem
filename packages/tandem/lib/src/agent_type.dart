import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/src/converters.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// What Tandem knows of one Dart type: how a value looks as JSON to the
/// agent, how a value the agent wrote is read back, its JSON Schema, and the
/// type of each value inside it. `tandem_generator` writes one for every type
/// a surface or a catalog uses; an app does not write them.
///
/// Two descriptions of one Dart type, from separate builds, have the same
/// [id]. Their [fingerprint] differs when they read or write it differently,
/// such as with another `JsonConverter`.
sealed class const AgentType<T>() {
  static const AgentType<String> string = _Scalar('string', 'String');
  static const AgentType<int> integer = _Scalar('integer', 'int');
  static const AgentType<double> number = _Scalar('number', 'double');
  static const AgentType<num> numeric = _Scalar('number', 'num');
  static const AgentType<bool> boolean = _Scalar('boolean', 'bool');
  static const AgentType<DateTime> dateTime = _DateTime();
  static const AgentType<Uri> uri = _Uri();

  static const AgentType<Color> color = _Converted(
    'dart:ui#Color',
    ColorConverter(),
    string,
    converterId: '$_converters#ColorConverter()',
    description:
        'A color as #RRGGBB, or #RRGGBBAA with its opacity, as in CSS.',
  );

  static const AgentType<EdgeInsetsGeometry> edgeInsetsGeometry = _Converted(
    '$_edgeInsets#EdgeInsetsGeometry',
    EdgeInsetsGeometryConverter(),
    string,
    converterId: '$_converters#EdgeInsetsGeometryConverter()',
    description:
        'Insets in logical pixels: one number for every side, as "16"; two '
        'for top and bottom, then left and right, as "8 16"; or sides by '
        'name, as "top 8 start 16 end 16". start and end follow the reading '
        'direction, left and right do not, and one value names only one '
        'kind.',
  );

  static const AgentType<EdgeInsets> edgeInsets = _Converted(
    '$_edgeInsets#EdgeInsets',
    EdgeInsetsConverter(),
    string,
    converterId: '$_converters#EdgeInsetsConverter()',
    description:
        'Insets in logical pixels: one number for every side, as "16"; two '
        'for top and bottom, then left and right, as "8 16"; or sides by '
        'name, as "top 8 left 16". Only left and right, which do not follow '
        'the reading direction.',
  );

  static const AgentType<EdgeInsetsDirectional> edgeInsetsDirectional =
      _Converted(
        '$_edgeInsets#EdgeInsetsDirectional',
        EdgeInsetsDirectionalConverter(),
        string,
        converterId: '$_converters#EdgeInsetsDirectionalConverter()',
        description:
            'Insets in logical pixels that follow the reading direction: one '
            'number for every side, as "16"; two for top and bottom, then '
            'start and end, as "8 16"; or sides by name, as "top 8 start 16".',
      );

  static const AgentType<AlignmentGeometry> alignmentGeometry = _Converted(
    '$_alignment#AlignmentGeometry',
    AlignmentGeometryConverter(),
    string,
    converterId: '$_converters#AlignmentGeometryConverter()',
    description:
        'A place in a box by name: topLeft, topCenter, topRight, centerLeft, '
        'center, centerRight, bottomLeft, bottomCenter or bottomRight; or, to '
        'follow the reading direction, topStart, topEnd, centerStart, '
        'centerEnd, bottomStart or bottomEnd.',
  );

  static const AgentType<Alignment> alignment = _Converted(
    '$_alignment#Alignment',
    AlignmentConverter(),
    string,
    converterId: '$_converters#AlignmentConverter()',
    description:
        'A place in a box by name: topLeft, topCenter, topRight, centerLeft, '
        'center, centerRight, bottomLeft, bottomCenter or bottomRight.',
  );

  static const AgentType<AlignmentDirectional> alignmentDirectional =
      _Converted(
        '$_alignment#AlignmentDirectional',
        AlignmentDirectionalConverter(),
        string,
        converterId: '$_converters#AlignmentDirectionalConverter()',
        description:
            'A place in a box that follows the reading direction, by name: '
            'topStart, topCenter, topEnd, centerStart, center, centerEnd, '
            'bottomStart, bottomCenter or bottomEnd.',
      );

  static const _converters = 'package:tandem/src/converters.dart';
  static const _edgeInsets = 'package:flutter/src/painting/edge_insets.dart';
  static const _alignment = 'package:flutter/src/painting/alignment.dart';

  /// Gives a description the type [T] when Dart cannot infer it, as for the
  /// representation of a converter.
  static AgentType<T> typed<T>(AgentType<T> type) => type;

  /// An enum, read and written by the names of [values].
  static AgentType<T> enumeration<T extends Enum>(
    List<T> values, {
    required String id,
    String? description,
  }) => _Choice(id, {
    for (final value in values) value.name: value,
  }, description: description);

  /// A class whose values are its own `static const` members, read and
  /// written by their names.
  static AgentType<T> token<T>(
    Map<String, T> byName, {
    required String id,
    String? description,
  }) => _Choice(id, byName, description: description);

  /// An extension type over a type of [representation], built with [wrap].
  static AgentType<T> extension<T, R>(
    AgentType<R> representation,
    T Function(R value) wrap, {
    required String id,
  }) => _Extension(id, representation, wrap);

  static AgentType<T?> nullable<T>(AgentType<T> type) => _Nullable(type);

  static AgentType<List<T>> list<T>(AgentType<T> item) => _List(item);

  static AgentType<Set<T>> set<T>(AgentType<T> item) => _Set(item);

  /// A class read through its constructor, whose [fields] are its
  /// parameters, each with a getter of the same name.
  static AgentType<T> object<T>({
    required String id,
    String? description,
    required List<AgentField<T>> Function(AgentFields<T> field) fields,
    required T Function(AgentFieldValues values) build,
  }) =>
      _Object(id, fields(AgentFields<T>._()), build, description: description);

  /// A type that [converter], a `JsonConverter<T, S>`, writes as [json].
  /// [converter] names the converter and its configuration. With [object],
  /// the type is a class that the agent points at by path, and writes as
  /// [json] only where it writes the object.
  static AgentType<T> converted<T, S>(
    Object converter,
    AgentType<S> json, {
    required String id,
    required String converterId,
    String? description,
    bool object = false,
  }) => _Converted(
    id,
    converter as JsonConverter<T, S>,
    json,
    converterId: converterId,
    description: description,
    isObject: object,
  );

  /// Names the Dart type across builds: the library's URI, `#` and the
  /// type's name, with the type arguments of a generic class.
  String get id;

  /// The type as the agent reads it in a description, such as `string`,
  /// `Customer` or `Customer[]`.
  String get name;

  /// What the type is, from its doc comment.
  String? get description => null;

  /// The description, with the type's own parts, that two builds must agree
  /// on: the same [id] with another fingerprint is a mistake in the app.
  String get fingerprint;

  /// [value] as JSON.
  Object? write(T value);

  /// The [json] that the agent wrote at [reading]'s path, as [T]. Throws a
  /// [ToolCallRefused] that says what to fix.
  T read(Object? json, AgentReading reading);

  /// The JSON Schema of what the agent writes, inline.
  JsonObject schema(AgentObjects objects);

  /// The type of the value at [segment] inside a value of this type, such as
  /// a field or an item, or null when there is none.
  AgentType<Object?>? typeAt(String segment) => null;

  /// The value at [segment] inside [value], or [AgentType.absent].
  Object? valueAt(T value, String segment) => absent;

  /// The types that [name] mentions and a description lists once each, such
  /// as the enums and classes inside it.
  Iterable<AgentType<Object?>> get parts => const [];

  /// Whether this is a class that the agent points at by path.
  bool get isObject => false;

  /// Whether a value of [other], or a non-null value of it, can stand where
  /// this type is expected.
  bool accepts(AgentType<Object?> other) => _nonNull(other).id == id;

  /// No value: past the end of a list, or below a null.
  static const Object absent = _Absent();

  /// [json] as a `{"path": ...}` to a value of this type, which [reading]
  /// resolves where it takes paths.
  T _resolve(Object? json, AgentReading reading) => switch ((json, reading)) {
    (
      {'path': final String path},
      AgentReading(objects: .paths, paths: final paths?),
    )
        when json is Map && json.length == 1 =>
      paths.resolve(path, this, at: reading.path),
    _ => throw reading.refuse(
      'write a path to a $name in the data, as {"path": "/..."}, not an object',
    ),
  };

  /// The JSON Schema of a path to a value of this type.
  JsonObject get _pathSchema => {
    'type': 'object',
    'description': 'The path of a $name in the data you see, such as /name/0.',
    'properties': {
      'path': {'type': 'string'},
    },
    'required': ['path'],
  };

  /// The Dart name in [id], with the names of its type arguments and
  /// without libraries, such as `Page<Customer>`.
  String get _declaredName =>
      id.replaceAll(RegExp('[^<>,]*#'), '').replaceAll(',', ', ');
}

/// Where a value of [AgentType.read] is in the arguments, and what a class
/// inside it may be.
final class const AgentReading(
  /// As in `lines[0].quantity`; empty for the arguments themselves.
  final String path, {
  required final AgentObjects objects,

  /// What a `{"path": ...}` reads, when [objects] is
  /// [AgentObjects.paths].
  final AgentPaths? paths,
}) {
  AgentReading at(String name) =>
      .new(path.isEmpty ? name : '$path.$name', objects: objects, paths: paths);

  AgentReading item(int index) =>
      .new('$path[$index]', objects: objects, paths: paths);

  /// Inside a value of a converter or of a class the agent writes, every
  /// class is written too.
  AgentReading get constructing =>
      .new(path, objects: AgentObjects.fields, paths: paths);

  ToolCallRefused refuse(String problem) =>
      ToolCallRefused(path.isEmpty ? problem : '$path: $problem');
}

/// What the agent writes for a value of a class.
enum AgentObjects() {
  /// `{"path": ...}` to one the screen lists, as for a method's parameter.
  paths,

  /// The object itself, field by field or in its converter's form, as for
  /// `@TandemInput()`.
  fields,

  /// Nothing: a literal in a view, where a class takes only a path, which
  /// the view reads.
  refused,
}

/// What a `{"path": ...}` in the arguments points at.
abstract interface class AgentPaths() {
  /// The value at [path] as [type]. Throws a [ToolCallRefused], with [at]
  /// where the path is in the arguments, when there is none or it changed.
  T resolve<T>(String path, AgentType<T> type, {required String at});
}

/// Makes the fields of an [AgentType.object]: `field('name', (v) => v.name)`
/// gives the field its getter, and `.as(type)` its type.
final class AgentFields<O>._() {
  AgentFieldOf<O, F> call<F>(
    String name,
    F Function(O value) get, {
    String? description,
    bool required = true,
  }) => ._(name, get, description, required: required);
}

/// A field of [O] with its getter, waiting for its type.
final class AgentFieldOf<O, F>._(
  final String _name,
  final F Function(O value) _get,
  final String? _description, {
  required final bool required,
}) {
  AgentField<O> as(AgentType<F> type) =>
      _Field(_name, _get, type, _description, required: required);
}

/// A field of a class: a constructor parameter with its getter.
sealed class const AgentField<O>() {
  String get name;
  String? get description;

  /// Whether the agent must write it when it writes the object.
  bool get required;
  AgentType<Object?> get type;
  Object? valueOf(O object);
  Object? write(O object);
}

final class const _Field<O, F>(
  @override final String name,
  final F Function(O value) _get,
  @override final AgentType<F> type,
  @override final String? description, {
  @override required final bool required,
}) extends AgentField<O> {
  @override
  Object? valueOf(O object) => _get(object);

  @override
  Object? write(O object) => type.write(_get(object));
}

/// The values of the fields that the agent wrote, read as their types, for
/// the constructor of an [AgentType.object].
final class AgentFieldValues._(final Map<String, Object?> _values) {
  T call<T>(String name) => _values[name] as T;

  /// Whether the agent wrote [name], so the constructor's default stays
  /// otherwise.
  bool has(String name) => _values.containsKey(name);
}

final class const _Absent();

final class const _Scalar<T>(final String _jsonType, final String _dartName)
    extends AgentType<T> {
  @override
  String get id => 'dart:core#$_dartName';

  @override
  String get name => _jsonType;

  @override
  String get fingerprint => id;

  @override
  Object? write(T value) => value;

  @override
  T read(Object? json, AgentReading reading) {
    // JSON does not tell 15 from 15.0. Past 2^53 - 1 a whole double may not be
    // the number the agent wrote, and on the web `T()` would take it as an int.
    return switch (json) {
      double() when 0 is T && 0.5 is! T && json.abs() > _maxExactInteger =>
        throw _wrongType(json, reading),
      T() => json,
      double() when json == json.truncateToDouble() && 0 is T =>
        json.toInt() as T,
      int() when 0.5 is T => json.toDouble() as T,
      _ => throw _wrongType(json, reading),
    };
  }

  @override
  JsonObject schema(AgentObjects objects) => {'type': _jsonType};

  @override
  bool accepts(AgentType<Object?> other) => switch ((this, _nonNull(other))) {
    (_, final other) when other.id == id => true,
    (AgentType<num>(), AgentType<num>()) when 0.5 is T => true,
    _ => false,
  };

  ToolCallRefused _wrongType(Object? json, AgentReading reading) =>
      reading.refuse('expected $_dartName, got ${jsonEncode(json)}');

  static const _maxExactInteger = 9007199254740991;
}

final class const _DateTime() extends AgentType<DateTime> {
  @override
  String get id => 'dart:core#DateTime';

  @override
  String get name => 'date-time';

  @override
  String get fingerprint => id;

  @override
  Object? write(DateTime value) => value.toIso8601String();

  @override
  DateTime read(Object? json, AgentReading reading) => switch (json) {
    final String text? => switch (DateTime.tryParse(text)) {
      final date? => date,
      null => throw reading.refuse(
        'expected an ISO 8601 date, got ${jsonEncode(json)}',
      ),
    },
    _ => throw reading.refuse(
      'expected an ISO 8601 date, got ${jsonEncode(json)}',
    ),
  };

  @override
  JsonObject schema(AgentObjects objects) => {
    'type': 'string',
    'format': 'date-time',
  };
}

final class const _Uri() extends AgentType<Uri> {
  @override
  String get id => 'dart:core#Uri';

  @override
  String get name => 'uri';

  @override
  String get fingerprint => id;

  @override
  Object? write(Uri value) => value.toString();

  @override
  Uri read(Object? json, AgentReading reading) => switch (json) {
    final String text? => switch (Uri.tryParse(text)) {
      final uri? => uri,
      null => throw reading.refuse('expected a URI, got ${jsonEncode(json)}'),
    },
    _ => throw reading.refuse('expected a URI, got ${jsonEncode(json)}'),
  };

  @override
  JsonObject schema(AgentObjects objects) => {
    'type': 'string',
    'format': 'uri',
  };
}

final class const _Choice<T>(
  @override final String id,
  final Map<String, T> _byName, {
  @override final String? description,
}) extends AgentType<T> {
  @override
  String get name => _declaredName;

  @override
  String get fingerprint => '$id[${_byName.keys.join('|')}]';

  @override
  Object? write(T value) {
    for (final MapEntry(key: name, value: member) in _byName.entries) {
      if (member == value) return name;
    }
    throw StateError('$value is none of the named values of $name.');
  }

  @override
  T read(Object? json, AgentReading reading) => switch (_byName[json]) {
    final T value when json is String => value,
    _ => throw reading.refuse(
      'expected one of ${_byName.keys.join(', ')}, got ${jsonEncode(json)}',
    ),
  };

  @override
  JsonObject schema(AgentObjects objects) => {
    'type': 'string',
    'enum': [..._byName.keys],
    'description': ?description,
  };

  /// The names the agent may write, for a description.
  Iterable<String> get names => _byName.keys;
}

final class const _Extension<T, R>(
  @override final String id,
  final AgentType<R> _representation,
  final T Function(R value) _wrap,
) extends AgentType<T> {
  @override
  String get name => _representation.name;

  @override
  String get fingerprint => '$id(${_representation.fingerprint})';

  // An extension type is its representation at runtime.
  @override
  Object? write(T value) => _representation.write(value as R);

  @override
  T read(Object? json, AgentReading reading) =>
      _wrap(_representation.read(json, reading));

  @override
  JsonObject schema(AgentObjects objects) => _representation.schema(objects);
}

final class const _Nullable<T>(final AgentType<T> _type) extends AgentType<T?> {
  @override
  String get id => '${_type.id}?';

  @override
  String get name => '${_type.name}?';

  @override
  String? get description => _type.description;

  @override
  String get fingerprint => '${_type.fingerprint}?';

  @override
  Object? write(T? value) => switch (value) {
    null => null,
    final T value => _type.write(value),
  };

  @override
  T? read(Object? json, AgentReading reading) =>
      json == null ? null : _type.read(json, reading);

  // Not a list of types, which ag-ui-adk 0.9.0 fails on.
  @override
  JsonObject schema(AgentObjects objects) => {
    'anyOf': [
      _type.schema(objects),
      {'type': 'null'},
    ],
  };

  @override
  AgentType<Object?>? typeAt(String segment) => _type.typeAt(segment);

  @override
  Object? valueAt(T? value, String segment) => switch (value) {
    null => AgentType.absent,
    final T value => _type.valueAt(value, segment),
  };

  @override
  Iterable<AgentType<Object?>> get parts => [_type];

  @override
  bool get isObject => _type.isObject;

  @override
  bool accepts(AgentType<Object?> other) => _type.accepts(_nonNull(other));
}

AgentType<Object?> _nonNull(AgentType<Object?> type) => switch (type) {
  _Nullable(:final _type) => _type,
  _ => type,
};

final class const _List<T>(final AgentType<T> _item)
    extends AgentType<List<T>> {
  @override
  String get id => 'List<${_item.id}>';

  @override
  String get name => '${_item.name}[]';

  @override
  String get fingerprint => 'List<${_item.fingerprint}>';

  @override
  Object? write(List<T> value) => [for (final item in value) _item.write(item)];

  @override
  List<T> read(Object? json, AgentReading reading) => switch (json) {
    final List<Object?> items => [
      for (final (index, item) in items.indexed)
        _item.read(item, reading.item(index)),
    ],
    _ => throw reading.refuse('expected a list, got ${jsonEncode(json)}'),
  };

  @override
  JsonObject schema(AgentObjects objects) => {
    'type': 'array',
    'items': _item.schema(objects),
  };

  @override
  AgentType<Object?>? typeAt(String segment) =>
      int.tryParse(segment) == null ? null : _item;

  @override
  Object? valueAt(List<T> value, String segment) =>
      switch (int.tryParse(segment)) {
        final index? when index >= 0 && index < value.length => value[index],
        _ => AgentType.absent,
      };

  @override
  Iterable<AgentType<Object?>> get parts => [_item];

  @override
  bool accepts(AgentType<Object?> other) => switch (_nonNull(other)) {
    _List(:final _item) => this._item.accepts(_item),
    _ => false,
  };

  /// The type of each item.
  AgentType<T> get item => _item;
}

final class const _Set<T>(final AgentType<T> _item) extends AgentType<Set<T>> {
  @override
  String get id => 'Set<${_item.id}>';

  @override
  String get name => '${_item.name}[]';

  @override
  String get fingerprint => 'Set<${_item.fingerprint}>';

  @override
  Object? write(Set<T> value) => [for (final item in value) _item.write(item)];

  @override
  Set<T> read(Object? json, AgentReading reading) => switch (json) {
    final List<Object?> items => {
      for (final (index, item) in items.indexed)
        _item.read(item, reading.item(index)),
    },
    _ => throw reading.refuse('expected a list, got ${jsonEncode(json)}'),
  };

  @override
  JsonObject schema(AgentObjects objects) => {
    'type': 'array',
    'items': _item.schema(objects),
    'uniqueItems': true,
  };

  @override
  AgentType<Object?>? typeAt(String segment) =>
      int.tryParse(segment) == null ? null : _item;

  @override
  Object? valueAt(Set<T> value, String segment) =>
      switch (int.tryParse(segment)) {
        final index? when index >= 0 && index < value.length => value.elementAt(
          index,
        ),
        _ => AgentType.absent,
      };

  @override
  Iterable<AgentType<Object?>> get parts => [_item];

  @override
  bool accepts(AgentType<Object?> other) => switch (_nonNull(other)) {
    _Set(:final _item) => this._item.accepts(_item),
    _ => false,
  };
}

final class _Object<T>(
  @override final String id,
  final List<AgentField<T>> _fields,
  final T Function(AgentFieldValues values) _build, {
  @override final String? description,
}) extends AgentType<T> {
  late final _byName = {for (final field in _fields) field.name: field};

  @override
  String get name => _declaredName;

  @override
  late final String fingerprint =
      '$id{${[for (final field in _fields) '${field.name}:${field.type.fingerprint}'].join(',')}}';

  @override
  Object? write(T value) => {
    for (final field in _fields) field.name: field.write(value),
  };

  @override
  T read(Object? json, AgentReading reading) => switch (reading.objects) {
    .fields => _construct(json, reading),
    .paths || .refused => _resolve(json, reading),
  };

  @override
  JsonObject schema(AgentObjects objects) => switch (objects) {
    .fields => {
      'type': 'object',
      'description': ?description,
      'properties': {
        for (final field in _fields)
          field.name: {
            ...field.type.schema(objects),
            'description': ?field.description,
          },
      },
      'required': [
        for (final field in _fields)
          if (field.required) field.name,
      ],
    },
    .paths || .refused => {
      'type': 'object',
      'description':
          'The path of a $name in the data you see, such as /name/0.',
      'properties': {
        'path': {'type': 'string'},
      },
      'required': ['path'],
    },
  };

  @override
  AgentType<Object?>? typeAt(String segment) => _byName[segment]?.type;

  @override
  Object? valueAt(T value, String segment) => switch (_byName[segment]) {
    final field? => field.valueOf(value),
    null => AgentType.absent,
  };

  @override
  Iterable<AgentType<Object?>> get parts => [
    for (final field in _fields) field.type,
  ];

  @override
  bool get isObject => true;

  T _construct(Object? json, AgentReading reading) {
    if (json is! Map<String, Object?>) {
      throw reading.refuse('expected an object, got ${jsonEncode(json)}');
    }
    for (final key in json.keys) {
      if (!_byName.containsKey(key)) {
        throw reading
            .at(key)
            .refuse('unknown, expected one of ${_byName.keys.join(', ')}');
      }
    }
    final values = <String, Object?>{};
    for (final field in _fields) {
      final at = reading.at(field.name);
      if (json.containsKey(field.name)) {
        values[field.name] = field.type.read(json[field.name], at);
      } else if (field.required) {
        throw at.refuse('missing, expected ${field.type.expected}');
      }
    }
    return _build(AgentFieldValues._(values));
  }
}

final class const _Converted<T, S>(
  @override final String id,
  final JsonConverter<T, S> _converter,
  final AgentType<S> _json, {
  required final String converterId,
  @override final String? description,
  @override final bool isObject = false,
}) extends AgentType<T> {
  @override
  String get name => _declaredName;

  @override
  String get fingerprint => '$id via $converterId as ${_json.fingerprint}';

  @override
  Object? write(T value) => _json.write(_converter.toJson(value));

  // A converter refuses a value with a FormatException; anything else it
  // throws is a bug of the app, not the agent's mistake.
  @override
  T read(Object? json, AgentReading reading) {
    if (isObject && reading.objects != .fields) return _resolve(json, reading);
    final value = _json.read(json, reading.constructing);
    try {
      return _converter.fromJson(value);
    } on FormatException catch (error) {
      throw reading.refuse(error.message);
    }
  }

  @override
  JsonObject schema(AgentObjects objects) => switch (objects) {
    .paths || .refused when isObject => _pathSchema,
    _ => {..._json.schema(.fields), 'description': ?description},
  };

  @override
  Iterable<AgentType<Object?>> get parts => _json.parts;
}

extension AgentTypeDetails on AgentType<Object?> {
  /// The type as a refusal names it: the Dart name of a scalar.
  String get expected => switch (_nonNull(this)) {
    _Scalar(:final _dartName) => _dartName,
    final type => type.name,
  };

  /// [name], or the id without `package:` when [other] is another type of
  /// that name, so that a refusal tells the two apart.
  String nameBeside(AgentType<Object?> other) =>
      name == other.name && id != other.id
      ? id.replaceAll('package:', '')
      : name;

  /// The names an enum or a token class takes, or null for another type.
  Iterable<String>? get choices => switch (this) {
    final _Choice<Object?> choice => choice.names,
    _ => null,
  };

  /// The names of the fields of a class, empty for another type.
  Iterable<String> get fieldNames => switch (_nonNull(this)) {
    final _Object<Object?> object => object._byName.keys,
    _ => const [],
  };

  /// The type of an item of a list or a set, or null for another type.
  AgentType<Object?>? get itemType => switch (_nonNull(this)) {
    _List(:final item) => item,
    _Set(:final _item) => _item,
    _ => null,
  };
}
