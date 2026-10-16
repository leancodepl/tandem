import 'dart:convert';
import 'dart:io';

/// Real event streams from ag-ui-adk 0.9.0 (protocol 1.0), captured with
/// curl on 2026-10-16 from a local ADK app driven by a scripted fake model.
///
/// Each `.sse` file is one run exactly as the server sent it. Together they
/// cover backend tools with `STATE_DELTA`, frontend tool calls with the
/// `STATE_SNAPSHOT` between `TOOL_CALL_ARGS` and `TOOL_CALL_END`, calls
/// without arguments, `RUN_ERROR` with and without `RUN_STARTED`, a
/// `RUN_FINISHED` with an interrupt `outcome`, empty retry runs, and a slow
/// run with ag-ui-adk's CRLF keep-alive comment (`slow.sse`).
abstract final class AgUiAdkTranscripts {
  /// Where the transcripts are, relative to the package root, which is the
  /// working directory of `flutter test`.
  static const directory = 'test/protocol/fixtures/ag_ui_adk';

  /// The names of all transcripts, such as `A1`, sorted.
  static List<String> get names {
    final names = [
      for (final file in Directory(directory).listSync())
        if (file is File && file.path.endsWith('.sse'))
          file.uri.pathSegments.last.replaceAll('.sse', ''),
    ]..sort();
    return names;
  }

  /// The raw bytes of transcript [name].
  static List<int> bytes(String name) =>
      File('$directory/$name.sse').readAsBytesSync();

  /// The JSON of every `data:` frame of transcript [name], in order.
  ///
  /// A plain reference reading: in these transcripts every frame is one
  /// `data: ` line followed by a blank line.
  static List<Map<String, Object?>> frames(String name) => [
    for (final line in const LineSplitter().convert(utf8.decode(bytes(name))))
      if (line.startsWith('data: '))
        jsonDecode(line.substring('data: '.length)) as Map<String, Object?>,
  ];
}
