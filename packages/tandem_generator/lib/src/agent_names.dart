/// The start of the names of the tools that Tandem offers itself.
const tandemToolPrefix = 'tandem_';

/// The member of a class's enum of tool names for the method [name].
String toolEnumMemberName(String name) => _withoutPrivacy(name);

/// Names that an enum declares itself or takes from `Object`.
const reservedToolEnumMemberNames = {
  'values',
  'index',
  'value',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
};

/// The name the agent gets for a getter or a method: [name] in snake_case.
String agentName(String name) => _withoutPrivacy(name)
    .replaceAllMapped(RegExp('(?<=[a-z0-9])[A-Z]'), (match) => '_${match[0]}')
    .toLowerCase();

String _withoutPrivacy(String name) => name.replaceFirst(RegExp('^_+'), '');
