import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

part 'reply_cubit.g.dart';

class const ReplyState({final String text = '', final bool sent = false});

@TandemAgent()
class ReplyCubit() extends Cubit<ReplyState> with _$ReplyCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(reply),
    .calls(setReply),
    if (reply.isNotEmpty && !sent) .callsWithApproval(send),
  ];

  @override
  Stream<Object?> get changes => stream;

  /// The reply to the customer as the user sees it.
  String get reply => state.text;

  bool get sent => state.sent;

  /// Replaces the whole reply with [text].
  void setReply(String text) => emit(.new(text: text));

  /// Sends the reply to the customer by e-mail.
  void send() => emit(.new(text: reply, sent: true));
}
