import 'package:analyzer/dart/ast/token.dart';

/// The start of the names of the tools that Tandem offers itself.
const tandemToolPrefix = 'tandem_';

/// [name] without its privacy as the member of an enum: after a `$` where it
/// starts with a digit, and before a trailing underscore where it is a reserved
/// word or a member of the enum.
String enumMemberName(String name) {
  final member = _withoutPrivacy(name);

  if (member.startsWith(RegExp('[0-9]'))) return '\$$member';

  final isReserved =
      (Keyword.keywords[member]?.isReservedWord ?? false) ||
      _reservedToolEnumMemberNames.contains(member);

  return isReserved ? '${member}_' : member;
}

const _reservedToolEnumMemberNames = {
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
