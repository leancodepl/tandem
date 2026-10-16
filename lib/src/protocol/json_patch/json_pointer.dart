// Internal: not exported. Shared by JSON Patch, the session (agent marks,
// reported user edits) and the scripted agent.

/// The reference tokens of an RFC 6901 JSON Pointer, unescaped.
///
/// `''` is the whole document and gives `[]`; `'/order/lines/0'` gives
/// `['order', 'lines', '0']`; `'/a~1b/m~0n'` gives `['a/b', 'm~n']`. Throws
/// [FormatException] when [pointer] is not empty and does not start with
/// `/`, or when a `~` is not followed by `0` or `1`.
List<String> parseJsonPointer(String pointer) {
  if (pointer.isEmpty) {
    return const [];
  }
  if (!pointer.startsWith('/')) {
    throw FormatException('A JSON Pointer must start with "/".', pointer);
  }
  final invalidEscape = _invalidEscape.firstMatch(pointer);
  if (invalidEscape != null) {
    throw FormatException(
      'In a JSON Pointer, "~" must be followed by "0" or "1".',
      pointer,
      invalidEscape.start,
    );
  }
  return [
    for (final token in pointer.substring(1).split('/'))
      token.replaceAll('~1', '/').replaceAll('~0', '~'),
  ];
}

/// The RFC 6901 JSON Pointer for [tokens], escaping `~` and `/`.
///
/// `[]` gives `''`; `['order', 'lines', '0']` gives `'/order/lines/0'`.
String formatJsonPointer(Iterable<String> tokens) => tokens
    .map((token) => '/${token.replaceAll('~', '~0').replaceAll('/', '~1')}')
    .join();

/// A `~` that is not the start of `~0` or `~1`.
final _invalidEscape = RegExp('~(?![01])');
