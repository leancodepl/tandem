import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/genui/agent_catalog.dart';
import 'package:tandem/src/genui/view_check.dart';

/// The description of `tandem_show_view` for a run that sees [listing]: the
/// components of [catalog], the names and forms of their types, the data
/// and methods a view may bind, the rules, and the catalog's guidelines and
/// example.
String viewDescription(AgentCatalog catalog, AgentListing listing) {
  final types = _Types([
    for (final component in catalog.components)
      for (final property in component.properties)
        if (property
            case ValueProperty(:final type) || FieldProperty(:final type))
          type,
    for (final MapEntry(:value) in listing.roots.entries) value.type,
    for (final name in listing.toolNames)
      for (final parameter
          in listing.toolNamed(name)?.parameters ?? const <Never>[])
        parameter.type,
  ]);
  final components = [
    for (final component in catalog.components)
      '- ${component.name}: ${[for (final property in component.properties) _property(property, types)].join(', ')}. ${component.description}',
  ];
  final data = [
    for (final MapEntry(key: name, value: root) in listing.roots.entries)
      '- /$name: ${types.label(root.type)}',
  ];
  final methods = [
    for (final name in listing.toolNames) _method(name, listing, types),
  ];
  final names = [
    for (final MapEntry(key: label, value: type) in types.listed.entries)
      if (type.choices case final choices?) '- $label: ${choices.join(' | ')}',
  ];
  final classes = [
    for (final MapEntry(key: label, value: type) in types.listed.entries)
      if (type.fieldNames.isNotEmpty) '- $label: {${_fields(type, types)}}',
  ];
  final forms = [
    for (final MapEntry(key: label, value: type) in types.listed.entries)
      if (type.form case final form?)
        ['- $label: ${types.label(form)}.', ?type.description].join(' '),
  ];

  return '''
Shows a view on the user's screen, drawn with the app's components below. Each call replaces the whole view.

Pass "components": a flat list. Each component has a unique "id", a "component" from the list below and its properties. One has the id "root", and a parent names its children by id.

Components ("?" may be left out; an action calls a method, a field is an action with what the user enters):
${components.join('\n')}
${_block('Names (write one)', names)}${_block('Forms', forms)}${_block('Classes', classes)}
Data, by path:
${data.isEmpty ? '- none' : data.join('\n')}

Methods an action may call:
${methods.isEmpty ? '- none' : methods.join('\n')}

Rules:
- A property takes a value of its type, or {"path": "/order/total"} into the data, so that the view follows the screen. Write the screen's data by path, and a literal only for text the data does not have.
- A property of a class takes only a path, never the object.
- "children": a list of ids, or {"componentId": <id>, "path": <path of a list>} to draw one component for every item. Below it, a path without a leading "/" starts at the item, and {"path": ""} is the item itself.
- An action: {"action": {"event": {"name": <method>, "context": {<parameter>: <value or path>}}}}. A field writes {"input": true} where the entry goes, and calls only a method that needs no approval. When the user acts, the method runs in the app, and app_notes tells you what it answered.
- Draw at most ${ViewCheck.maxComponents} components, counting every repeated item and nested component.

${catalog.guidelines}

Example:
${jsonEncode(catalog.example)}''';
}

String _property(AgentProperty property, _Types types) {
  final optional = property.required ? '' : '?';
  final kind = switch (property) {
    ValueProperty(:final type) => types.property(type),
    ChildProperty() => 'component',
    ChildrenProperty() => 'components',
    PressProperty() => 'action',
    FieldProperty(:final type) => 'field: ${types.property(type)}',
  };
  return '"${property.name}"$optional ($kind)';
}

String _fields(AgentType<Object?> type, _Types types) => [
  for (final field in type.fieldNames)
    if (type.typeAt(field) case final fieldType?)
      '$field: ${types.label(fieldType)}',
].join(', ');

String _method(String name, AgentListing listing, _Types types) {
  final tool = listing.toolNamed(name);
  final parameters = [
    for (final parameter in tool?.parameters ?? const <Never>[])
      '${parameter.name}: ${types.label(parameter.type)}',
  ].join(', ');
  final approval = listing.listedWithApproval(name) ? ' (needs approval)' : '';
  return '- $name($parameters)$approval';
}

String _block(String title, List<String> lines) =>
    lines.isEmpty ? '' : '\n$title:\n${lines.join('\n')}\n';

/// The types a description names. It lists each enum, token class, class
/// and converted type once, by its name, or by its id without `package:`
/// when another type has the same name.
final class _Types(Iterable<AgentType<Object?>> types) {
  this {
    types.forEach(_collect);
  }

  final _byId = <String, AgentType<Object?>>{};

  late final _sharedNames = {
    for (final type in _byId.values)
      if (_byId.values.where((other) => other.name == type.name).length > 1)
        type.name,
  };

  /// The listed types by label.
  late final listed = {for (final type in _byId.values) _labelOf(type): type};

  /// [type] as the description names it, such as `Status[]`.
  String label(AgentType<Object?> type) {
    if (type.isNullable) return '${label(type.nonNull)}?';
    if (type.itemType case final item?) return '${label(item)}[]';
    return _labelOf(type);
  }

  /// [type] as a property names it: a class takes a path.
  String property(AgentType<Object?> type) =>
      type.isObject ? '${label(type)}, by path' : label(type);

  String _labelOf(AgentType<Object?> type) => _sharedNames.contains(type.name)
      ? type.id.replaceAll('package:', '')
      : type.name;

  void _collect(AgentType<Object?> type) {
    final wrapper = type.isNullable || type.itemType != null;
    final listsOnce =
        type.choices != null || type.form != null || type.isObject;
    if (!wrapper && listsOnce) {
      if (_byId.containsKey(type.id)) return;
      _byId[type.id] = type;
    }
    type.parts.forEach(_collect);
  }
}
