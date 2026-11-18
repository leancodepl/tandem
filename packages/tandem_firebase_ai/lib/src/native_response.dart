import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/firebase_request.dart';
import 'package:tandem_firebase_ai/src/native_history.dart';
import 'package:uuid/uuid.dart';

final class NativeResponse() {
  final _parts = <JsonObject>[];
  var _stopped = false;
  var _hasVisibleText = false;

  String add(GenerateContentResponse response) {
    if (response.promptFeedback?.blockReason != null) {
      throw FirebaseFailure(
        FirebaseErrorCode.blocked,
        response.promptFeedback?.blockReasonMessage ??
            'Firebase blocked the prompt.',
      );
    }
    if (response.candidates.length > 1) {
      throw FirebaseFailure(
        FirebaseErrorCode.unsupportedResponse,
        'Only one response candidate is supported.',
      );
    }
    final delta = StringBuffer();
    for (final candidate in response.candidates) {
      if (candidate.finishReason case final reason?) {
        if (reason != FinishReason.stop) {
          throw _incompleteAnswer(reason, candidate.finishMessage);
        }
        _stopped = true;
      } else if (candidate.content.parts.isNotEmpty) {
        // Some models put STOP on every chunk, so content with the reason
        // may follow. Content without it is not an end.
        _stopped = false;
      }
      if (candidate.groundingMetadata != null ||
          candidate.urlContextMetadata != null) {
        throw FirebaseFailure(
          FirebaseErrorCode.unsupportedResponse,
          'Grounded responses are not supported.',
        );
      }
      for (final part in candidate.content.parts) {
        if (part is! TextPart && part is! FunctionCall) {
          throw FirebaseFailure(
            FirebaseErrorCode.unsupportedResponse,
            'Only text and function calls are supported.',
          );
        }
        final json = part.toJson();
        if (json is! JsonObject) {
          throw FirebaseFailure(
            FirebaseErrorCode.invalidResponse,
            'Invalid native content part.',
          );
        }
        // Firebase's own chat drops empty text. A signed one must go back.
        if (part case TextPart(text: '')
            when !json.containsKey('thoughtSignature')) {
          continue;
        }
        _parts.add(json);
        if (part case TextPart(:final text, :final isThought)
            when isThought != true) {
          delta.write(text);
        }
      }
    }
    final text = delta.toString();
    if (text.isNotEmpty) _hasVisibleText = true;
    return text;
  }

  NativeAnswer finish(FirebaseRequest request) {
    if (!_stopped) {
      throw FirebaseFailure(
        FirebaseErrorCode.generationFailed,
        'Firebase ended without a finish reason.',
      );
    }
    final calls = <NativeCall>[];
    final nativeIds = <String>{};
    for (final part in _parts) {
      // As the SDK's own `functionCalls`, which skips thoughts.
      if (part['functionCall'] case final JsonObject function
          when part['thought'] != true) {
        if (function
            case {'name': final String name, 'args': final JsonObject args}
            when request.toolNames.contains(name)) {
          final nativeId = function['id'];
          if (nativeId != null &&
              (nativeId is! String ||
                  nativeId.isEmpty ||
                  !nativeIds.add(nativeId))) {
            throw FirebaseFailure(
              FirebaseErrorCode.invalidResponse,
              'Invalid or duplicate native call ID.',
            );
          }
          final id = 'firebase-call-${const Uuid().v4()}';
          calls.add(
            NativeCall(id, name, jsonEncode(args), nativeId as String?),
          );
        } else {
          throw FirebaseFailure(
            FirebaseErrorCode.invalidResponse,
            'The model requested an unknown tool or invalid arguments.',
          );
        }
      }
    }
    if (!_hasVisibleText && calls.isEmpty) {
      throw FirebaseFailure(
        FirebaseErrorCode.invalidResponse,
        'Firebase returned no answer or tool calls.',
      );
    }
    final metadata = <String, Object?>{
      nativeHistoryKey: {
        'version': 1,
        'source': request.source,
        'calls': [
          for (final call in calls) {'id': call.id, 'nativeId': call.nativeId},
        ],
        'parts': _parts,
      },
    };
    return NativeAnswer(calls, metadata);
  }
}

FirebaseFailure _incompleteAnswer(FinishReason reason, String? message) {
  final code = switch (reason) {
    FinishReason.maxTokens => FirebaseErrorCode.outputLimit,
    FinishReason.safety ||
    FinishReason.recitation ||
    FinishReason.blocklist ||
    FinishReason.prohibitedContent ||
    FinishReason.spii ||
    FinishReason.imageSafety ||
    FinishReason.imageProhibitedContent ||
    FinishReason.imageRecitation => FirebaseErrorCode.blocked,
    FinishReason.malformedFunctionCall ||
    FinishReason.malformedResponse => FirebaseErrorCode.invalidResponse,
    // Firebase rejected the history, so sending it again cannot work.
    FinishReason.missingThoughtSignature =>
      FirebaseErrorCode.incompatibleHistory,
    _ => FirebaseErrorCode.generationFailed,
  };
  return FirebaseFailure(
    code,
    message ?? 'Firebase ended without a complete answer (${reason.toJson()}).',
  );
}

final class NativeAnswer(
  final List<NativeCall> calls,
  final JsonObject metadata,
);

final class NativeCall(
  final String id,
  final String name,
  final String arguments,
  final String? nativeId,
);
