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
  final prefix = RegExp(r'^\s*/// ?');
  // As in Markdown: a single line break is a space, a blank line a paragraph.
  final wrap = RegExp(r'(?<!\n)\n(?!\n)');

  return comment
      ?.split(Tokens.newLine)
      .map((line) => line.replaceFirst(prefix, ''))
      .join(Tokens.newLine)
      .trim()
      .replaceAll(wrap, ' ');
}
