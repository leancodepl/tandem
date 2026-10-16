/// Reads typed values out of decoded AG-UI JSON without ever throwing.
///
/// AG-UI servers write camelCase keys; some write snake_case. Every read
/// takes the camelCase key and, optionally, the snake_case one, which is
/// used when the camelCase key is absent.
final class JsonReader {
  /// Wraps [json].
  const JsonReader(this.json);

  /// The JSON object being read.
  final Map<String, Object?> json;

  /// The raw value under [key], or under [alternative] when [key] is absent.
  Object? value(String key, [String? alternative]) {
    if (json.containsKey(key) || alternative == null) {
      return json[key];
    }
    return json[alternative];
  }

  /// The value as a string, or `null` when it is missing or not a string.
  String? string(String key, [String? alternative]) =>
      switch (value(key, alternative)) {
        final String text => text,
        _ => null,
      };

  /// The value as a JSON object, or `null` when it is missing or not one.
  Map<String, Object?>? map(String key, [String? alternative]) =>
      switch (value(key, alternative)) {
        final Map<String, Object?> object => object,
        _ => null,
      };

  /// The value as a JSON array, or `null` when it is missing or not one.
  List<Object?>? list(String key, [String? alternative]) =>
      switch (value(key, alternative)) {
        final List<Object?> array => array,
        _ => null,
      };
}

/// The text of an AG-UI message `content`.
///
/// Content is usually a string. Protocol 1.0 also allows a list of parts;
/// then the `text` of every text part is joined. Returns `null` for anything
/// else, including a missing content.
String? contentText(Object? content) {
  switch (content) {
    case final String text:
      return text;
    case final List<Object?> parts:
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part case {'type': 'text', 'text': final String text}) {
          buffer.write(text);
        }
      }
      return buffer.toString();
    default:
      return null;
  }
}
