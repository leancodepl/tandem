import 'package:a2ui_core/a2ui_core.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/genui/a2ui_tree.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// What an agent may draw on a screen: A2UI v0.9.1 with Tandem's catalog,
/// data only by path from what the screen lists with `.sees`, and buttons
/// only for the methods it lists now, with their parameters.
final class ViewCheck(final AgentListing _listing) {
  /// Why [messages] may not draw, written for the agent to fix them, or
  /// nothing when they may. Stops at the first of three checks that finds a
  /// problem: the messages Tandem allows, the catalog, then the data and
  /// methods they bind.
  List<String> problems(List<Object?> messages) {
    final allowed = _messageProblems(messages);
    if (allowed.isNotEmpty) {
      return allowed;
    }
    if (_catalogProblem(messages) case final problem?) {
      return [problem];
    }
    return _bindingProblems(componentsOf(messages));
  }

  List<String> _messageProblems(List<Object?> messages) => [
    for (final message in messages)
      if (_messageProblem(message) case final problem?)
        problem
      else
        for (final component in componentsIn(message))
          ..._componentProblems(component),
    if (_surfaceIds(messages).length > 1)
      'Draw one surface: give every message the same surfaceId.',
  ];

  static String? _messageProblem(Object? message) => switch (message) {
    {A2uiFields.version: final version} when version != a2uiVersion =>
      'Every message needs "version": "$a2uiVersion", not $version.',
    {A2uiFields.updateDataModel: _} =>
      'Screen data comes only from what the screen lists. Bind it with '
          '{"path": ...} instead of updateDataModel.',
    final JsonObject json when _kind(json) == null =>
      'Only ${allowedA2uiMessages.join(', ')} messages are allowed.',
    _ => null,
  };

  List<String> _componentProblems(JsonObject component) {
    final id = component[A2uiFields.id];
    return [
      for (final function in functionsOf(component))
        if (function != formatString) '$id calls $function, not allowed.',
      if (hasFunctionCall(component))
        '$id has a functionCall action. Actions must be events.',
      for (final event in eventsOf(component))
        if (event[A2uiFields.name] case final name
            when name is! String || !_listing.lists(name))
          _unknownMethod(id, name),
    ];
  }

  String _unknownMethod(Object? id, Object? name) =>
      '$id calls $name, which is not a method of the screen. Methods: '
      '${_listing.toolNames.join(', ')}.';

  static String? _catalogProblem(List<Object?> messages) {
    final processor = tandemProcessor();
    try {
      processor.processMessages(messages);
      return null;
    } on A2uiError catch (error) {
      return '$error';
    } finally {
      processor.dispose();
    }
  }

  List<String> _bindingProblems(Map<String, JsonObject> components) {
    final bases = templateBases(components);
    return [
      for (final MapEntry(key: id, value: component) in components.entries) ...[
        for (final path in pathsOf(component))
          if (whyUnresolved(path, base: bases[id], data: _listing.seen)
              case final problem?)
            '$id: $problem',
        for (final event in eventsOf(component))
          ..._argumentProblems(id, event),
      ],
    ];
  }

  List<String> _argumentProblems(String id, JsonObject event) {
    final name = event[A2uiFields.name];
    final schema = _ArgumentSchema(
      name is String ? _listing.parameters(name) : null,
    );
    final given = switch (event[A2uiFields.context]) {
      final JsonObject context => context.keys.toSet(),
      _ => const <String>{},
    };
    final unknown = given.difference(schema.names);
    return [
      if (unknown.isNotEmpty) _unknownParameters(id, name, unknown, schema),
      for (final key in schema.required.difference(given))
        '$id: $name needs $key.',
    ];
  }

  static String _unknownParameters(
    String id,
    Object? name,
    Set<String> unknown,
    _ArgumentSchema schema,
  ) =>
      '$id: $name has no parameter ${unknown.join(', ')}. Parameters: '
      '${schema.names.join(', ')}.';

  static String? _kind(JsonObject message) =>
      allowedA2uiMessages.where(message.containsKey).singleOrNull;

  static Set<Object?> _surfaceIds(List<Object?> messages) => {
    for (final message in messages.whereType<JsonObject>())
      for (final kind in allowedA2uiMessages)
        if (message[kind] case {A2uiFields.surfaceId: final id}) id,
  };
}

/// The JSON Schema of a method's arguments, as far as a button needs it.
extension type const _ArgumentSchema(JsonObject? _schema) {
  Set<String> get names => switch (_schema) {
    {'properties': final JsonObject properties} => properties.keys.toSet(),
    _ => const {},
  };

  Set<Object?> get required => switch (_schema) {
    {'required': final List<Object?> required} => required.toSet(),
    _ => const {},
  };
}
