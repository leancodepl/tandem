import 'package:firebase_ai/firebase_ai.dart';
import 'package:tandem_firebase_ai/src/ag_ui_ids.dart';
import 'package:tandem_firebase_ai/src/firebase_answer.dart';
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/json_object.dart';

/// Collects the chunks of one generation into Gemini's answer.
///
/// Tandem gets no call before [complete]: a later chunk can still block the
/// answer, and the calls of an answer are handed over together or not at
/// all.
final class FirebaseResponse() {
  final _parts = <_AnswerPart>[];
  var _finished = false;

  /// Adds the parts of [chunk]. The answer is finished while its last chunk
  /// with content has the finish reason `STOP`: some models put the reason
  /// on every chunk, and content without it after a `STOP` is not an end.
  void add(ResponseChunk chunk) {
    _parts.addAll(chunk._parts);
    _finished = chunk._finishesAnswer || (_finished && chunk._parts.isEmpty);
  }

  /// The whole answer. Throws a [FirebaseFailure] when the stream ended
  /// before the answer finished, when Tandem cannot run every call of the
  /// answer, or when the answer has neither text nor calls.
  FirebaseAnswer complete({required Set<ToolName> offeredTools}) {
    if (!_finished) throw FirebaseFailure.unfinished();

    final calls = [for (final part in _parts) ?part.proposedCall];
    if (_hasUnusableCall(calls, offeredTools)) {
      throw FirebaseFailure.unusableCalls();
    }

    final text = _parts.map((part) => part.visibleText).join();
    if (text.isEmpty && calls.isEmpty) throw FirebaseFailure.emptyAnswer();

    return FirebaseAnswer(
      text: text,
      calls: [for (final call in calls) .of(call)],
      parts: [for (final part in _parts) part.json],
    );
  }
}

/// One chunk of the stream, as far as this connection delivers it: a single
/// candidate of text and function calls.
final class ResponseChunk._(
  final List<_AnswerPart> _parts, {
  required final bool _finishesAnswer,
}) {
  /// Throws a [FirebaseFailure] for a blocked prompt, a finish reason other
  /// than `STOP` and content this connection does not deliver.
  factory read(GenerateContentResponse response) {
    final feedback = response.promptFeedback;
    if (feedback?.blockReason != null) {
      throw FirebaseFailure.promptBlocked(feedback?.blockReasonMessage);
    }

    return switch (response.candidates) {
      [] => ._(const [], finishesAnswer: false),
      [final candidate] => ._of(candidate),
      _ => throw FirebaseFailure.severalCandidates(),
    };
  }

  factory _of(Candidate candidate) {
    final reason = candidate.finishReason;
    if (reason != null && reason != .stop) {
      throw FirebaseFailure.incompleteAnswer(reason, candidate.finishMessage);
    }
    if (candidate.groundingMetadata != null ||
        candidate.urlContextMetadata != null) {
      throw FirebaseFailure.groundedAnswer();
    }

    final parts = candidate.content.parts.map(_AnswerPart.read);
    return ._([
      for (final part in parts)
        if (part.goesBack) part,
    ], finishesAnswer: reason == .stop);
  }

  String get visibleText => _parts.map((part) => part.visibleText).join();
}

/// A text or function-call part of the answer. [json] is what Firebase gets
/// back: it has the thought signature, which the SDK's types hide.
final class _AnswerPart._(final Part _part, final JsonObject json) {
  /// Throws a [FirebaseFailure] for any other kind of part.
  factory read(Part part) => switch (part) {
    // The SDK types `toJson` as `Object`. Both kinds write a JSON object.
    TextPart() || FunctionCall() => ._(part, part.toJson() as JsonObject),
    _ => throw FirebaseFailure.unsupportedPart(),
  };

  String get visibleText => switch (_part) {
    TextPart(isThought: true) => '',
    TextPart(:final text) => text,
    _ => '',
  };

  /// The call this part proposes. A function call marked as a thought is
  /// not proposed, as in the SDK's own `functionCalls`.
  FunctionCall? get proposedCall => switch (_part) {
    FunctionCall(isThought: true) => null,
    final FunctionCall call => call,
    _ => null,
  };

  /// Whether Firebase gets the part back with the answer. The SDK's
  /// `ChatSession` drops empty text parts, but an empty part can carry a
  /// thought signature.
  bool get goesBack => switch (_part) {
    TextPart(text: '') => json.containsKey('thoughtSignature'),
    _ => true,
  };
}

/// One unusable call means the batch was read wrong, and Tandem gets none
/// of it.
bool _hasUnusableCall(List<FunctionCall> calls, Set<ToolName> offeredTools) {
  final ids = [for (final call in calls) ?call.id];
  final callsUnknownTool = calls.any(
    (call) => !offeredTools.contains(ToolName(call.name)),
  );
  final hasEmptyId = ids.contains('');
  final repeatsId = ids.toSet().length < ids.length;
  return callsUnknownTool || hasEmptyId || repeatsId;
}
