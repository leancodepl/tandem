import 'package:analyzer/dart/element/element.dart';
import 'package:tandem_generator/src/tokens.dart';

/// The doc comment without the slashes, with its wrapped lines joined. Field
/// getters use the field's comment.
String? documentationOf(Element? element) {
  final comment = switch (element) {
    GetterElement(isOriginVariable: true, :final variable) =>
      variable.documentationComment,
    _ => element?.documentationComment,
  };

  if (comment == null) return null;

  return joinWrappedLines(withoutSlashes(comment));
}

/// [comment], a `///` doc comment, without its slashes.
String withoutSlashes(String comment) => comment
    .split(Tokens.newLine)
    .map((line) => line.replaceFirst(_slashes, ''))
    .join(Tokens.newLine);

/// [text] with its wrapped lines joined, as Markdown reads them: a line break
/// is a space, but a list item, a code block and a blank line stay on lines
/// of their own.
String joinWrappedLines(String text) {
  final lines = <String>[];
  var inCode = false;
  var continues = false;

  for (final line in text.split(Tokens.newLine)) {
    final isFence = line.trimLeft().startsWith('```');

    if (isFence || inCode) {
      if (isFence) inCode = !inCode;
      lines.add(line);
      continues = false;
    } else if (line.trim().isEmpty) {
      if (lines.lastOrNull?.isNotEmpty ?? false) lines.add('');
      continues = false;
    } else if (continues && !_listItem.hasMatch(line)) {
      lines.last = '${lines.last} ${line.trim()}';
    } else {
      lines.add(line);
      continues = true;
    }
  }

  return lines.join(Tokens.newLine).trim();
}

final _slashes = RegExp(r'^\s*/// ?');
final _listItem = RegExp(r'^\s*([-*+]|\d+[.)])\s');
