import 'dart:async';

import 'package:tandem/src/tools/tool_args.dart';

/// A function of the app that the agent may call. It runs in the app.
///
/// The agent decides when to call it, from its [name], [description] and
/// [params]. When the agent's run ends, the session runs the tool and sends
/// the result back to the agent in an automatic follow-up run.
///
/// With [needsApproval] the call becomes an approval request in the timeline
/// instead, and the tool runs only after the user approves that exact call
/// while the shared state is unchanged.
///
/// Agent tools, the functions the agent runs on its own side, are never
/// declared here; their activity shows up in the timeline on its own.
///
/// ```dart
/// Tool('search_catalog', 'Find products matching free text.',
///     params: {'query': const Param.string('For example "HDMI cable 2m"')},
///     run: (call) => catalog.search(call.read('query')))
/// ```
final class Tool<S> {
  /// Creates a tool.
  ///
  /// [name] must be unique among a session's tools and match
  /// `[a-zA-Z0-9_-]{1,64}`, the rule of the model providers; the session
  /// throws an [ArgumentError] otherwise.
  Tool(
    this.name,
    this.description, {
    required FutureOr<Object?> Function(ToolCall<S> call) run,
    this.params = const {},
    this.needsApproval = false,
    this.label,
  }) : _run = run;

  /// The name the agent calls.
  final String name;

  /// What the tool does, for the model. A clear description is what makes
  /// the agent use the tool at the right moment.
  final String description;

  /// The arguments, by name. They become the JSON Schema the agent sees, and
  /// the session checks the agent's arguments against them before [run] is
  /// called; a mismatch goes back to the agent as an error and [run] is not
  /// called.
  final Map<String, Param> params;

  /// Whether the user must approve each call before it runs.
  final bool needsApproval;

  /// The text for the timeline, such as "Searching the catalog". Defaults to
  /// the [name] in words ("Search catalog").
  final String? label;

  // Only read through `this` in [run], where S is the tool's own type, so the
  // unsafe read that this lint warns about cannot happen. The function has to
  // be stored to keep the design's `Tool(..., run: ...)` constructor.
  // ignore: unsafe_variance
  final FutureOr<Object?> Function(ToolCall<S> call) _run;

  /// Runs the app function given as `run`. Called by the session; public so
  /// a tool can be unit-tested on its own.
  ///
  /// The return value goes back to the agent as
  /// `{"status": "ok", "result": <value>}`, encoded with `jsonEncode`, so
  /// anything with a `toJson()` method works. If it throws, the agent gets
  /// `{"status": "error", "error": "<message>"}`, the timeline shows the call
  /// as failed, and the session goes on.
  FutureOr<Object?> run(ToolCall<S> call) => _run(call);
}

/// One argument of a [Tool]. It becomes part of the JSON Schema the agent
/// sees. Required unless `optional` is true.
final class Param {
  /// A string. With `oneOf` it must be one of these values.
  const Param.string(
    this.description, {
    this.optional = false,
    List<String>? oneOf,
  }) : _type = 'string',
       _oneOf = oneOf,
       _items = null,
       _fields = null;

  /// A whole number. `40` and `40.0` are both accepted.
  const Param.integer(this.description, {this.optional = false})
    : _type = 'integer',
      _oneOf = null,
      _items = null,
      _fields = null;

  /// Any number.
  const Param.number(this.description, {this.optional = false})
    : _type = 'number',
      _oneOf = null,
      _items = null,
      _fields = null;

  /// `true` or `false`.
  const Param.boolean(this.description, {this.optional = false})
    : _type = 'boolean',
      _oneOf = null,
      _items = null,
      _fields = null;

  /// A list whose every item is described by `items`.
  const Param.list(Param items, this.description, {this.optional = false})
    : _type = 'array',
      _oneOf = null,
      _items = items,
      _fields = null;

  /// An object with the given `fields`.
  const Param.object(
    Map<String, Param> fields,
    this.description, {
    this.optional = false,
  }) : _type = 'object',
       _oneOf = null,
       _items = null,
       _fields = fields;

  /// What the argument means, for the model.
  final String description;

  /// Whether the agent may leave the argument out.
  final bool optional;

  final String _type;
  final List<String>? _oneOf;
  final Param? _items;
  final Map<String, Param>? _fields;

  /// The JSON Schema of this argument.
  ///
  /// It never contains `additionalProperties`, which Gemini rejects. An
  /// object lists its non-optional fields under `required`.
  Map<String, Object?> toJsonSchema() {
    final oneOf = _oneOf;
    final items = _items;
    final fields = _fields;
    return {
      'type': _type,
      'description': description,
      'enum': ?oneOf,
      if (items != null) 'items': items.toJsonSchema(),
      if (fields != null) ..._objectSchema(fields),
    };
  }

  /// The problem with [value] as this argument at [path], or `null` when it
  /// fits. [value] is not `null`.
  ToolArgumentError? _check(String path, Object value) {
    final items = _items;
    final fields = _fields;
    final oneOf = _oneOf;
    switch (_type) {
      case 'string' when value is! String:
      case 'integer' when !_isWholeNumber(value):
      case 'number' when value is! num:
      case 'boolean' when value is! bool:
      case 'array' when value is! List<Object?>:
      case 'object' when value is! Map<String, Object?>:
        return ToolArgumentError(
          path,
          'must be ${_describeType()}, not ${_describeValue(value)}',
        );
    }
    if (oneOf != null && !oneOf.contains(value)) {
      return ToolArgumentError(
        path,
        'must be one of ${oneOf.map((option) => '"$option"').join(', ')}, '
        'not "$value"',
      );
    }
    if (items != null && value is List<Object?>) {
      for (final (index, item) in value.indexed) {
        final problem = items._checkPresent('$path[$index]', item);
        if (problem != null) {
          return problem;
        }
      }
    }
    if (fields != null && value is Map<String, Object?>) {
      return _checkFields(fields, value, prefix: '$path.');
    }
    return null;
  }

  /// Like [_check], for a value that may be missing or `null`.
  ToolArgumentError? _checkPresent(
    String path,
    Object? value, {
    bool isMissing = false,
  }) {
    if (value != null) {
      return _check(path, value);
    }
    if (optional) {
      return null;
    }
    return ToolArgumentError(
      path,
      isMissing ? 'is missing' : 'must not be null',
    );
  }

  String _describeType() => switch (_type) {
    'string' => 'a string',
    'integer' => 'a whole number',
    'number' => 'a number',
    'boolean' => 'true or false',
    'array' => 'a list',
    _ => 'an object',
  };

  static bool _isWholeNumber(Object value) =>
      value is int || (value is double && value == value.truncateToDouble());

  static String _describeValue(Object value) => switch (value) {
    String() => 'a string',
    int() => 'a whole number',
    double() => 'a number',
    bool() => 'a boolean',
    List<Object?>() => 'a list',
    Map<Object?, Object?>() => 'an object',
    _ => 'another value',
  };
}

/// The JSON Schema of an object with [fields], without a description.
Map<String, Object?> _objectSchema(Map<String, Param> fields) {
  final required = [
    for (final MapEntry(:key, :value) in fields.entries)
      if (!value.optional) key,
  ];
  return {
    'properties': {
      for (final MapEntry(:key, :value) in fields.entries)
        key: value.toJsonSchema(),
    },
    if (required.isNotEmpty) 'required': required,
  };
}

/// The first problem of [json] as an object with [fields].
ToolArgumentError? _checkFields(
  Map<String, Param> fields,
  Map<String, Object?> json, {
  String prefix = '',
}) {
  for (final MapEntry(key: name, value: param) in fields.entries) {
    final problem = param._checkPresent(
      '$prefix$name',
      json[name],
      isMissing: !json.containsKey(name),
    );
    if (problem != null) {
      return problem;
    }
  }
  return null;
}

/// The JSON Schema of [tool]'s arguments, as AG-UI declares them: an object
/// whose properties are [Tool.params], without `additionalProperties`.
///
/// Internal: not exported.
Map<String, Object?> parametersSchemaOf(Tool<Object?> tool) => {
  'type': 'object',
  ..._objectSchema(tool.params),
};

/// The first way in which the agent's [arguments] do not match
/// [Tool.params] of [tool], or `null` when they match. Arguments the tool
/// does not declare are allowed.
///
/// Internal: not exported.
ToolArgumentError? checkArguments(
  Tool<Object?> tool,
  Map<String, Object?> arguments,
) => _checkFields(tool.params, arguments);

/// Whether [name] is a valid tool name: `[a-zA-Z0-9_-]{1,64}`, the rule of
/// the model providers.
///
/// Internal: not exported.
bool isValidToolName(String name) => _toolName.hasMatch(name);

final _toolName = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

/// A tool name in words for the timeline: `search_catalog` and
/// `searchCatalog` become "Search catalog".
///
/// Internal: not exported.
String nameInWords(String name) {
  final words = name
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.toLowerCase())
      .toList();
  if (words.isEmpty) {
    return name;
  }
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
