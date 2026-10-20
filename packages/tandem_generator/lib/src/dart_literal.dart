import 'dart:convert';

abstract final class DartLiteral._() {
  static final _jsonString = RegExp(r'"((?:[^"\\]|\\.)*)"');

  /// A JSON value as Dart code, with interpolation escaped and Dart quotes.
  static String json(Object? value) {
    final encoded = jsonEncode(value);

    return encoded.replaceAllMapped(
      _jsonString,
      (match) => _string(match[1] ?? ''),
    );
  }

  static String _string(String escaped) {
    final contents = escaped.replaceAll(r'$', r'\$');

    if (contents.contains("'") && !contents.contains(r'\"')) {
      return '"$contents"';
    }

    final singleQuoted = contents.replaceAll(r'\"', '"').replaceAll("'", r"\'");

    return "'$singleQuoted'";
  }
}
