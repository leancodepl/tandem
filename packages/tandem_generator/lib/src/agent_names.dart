/// The name the agent gets for a getter or a method: [name] in snake_case.
String agentName(String name) => name
    .replaceFirst(RegExp('^_+'), '')
    .replaceAllMapped(RegExp('(?<=[a-z0-9])[A-Z]'), (match) => '_${match[0]}')
    .toLowerCase();
