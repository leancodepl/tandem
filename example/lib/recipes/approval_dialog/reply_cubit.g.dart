// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reply_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ReplyCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ReplyCubit;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.reply,
          'reply',
          'The reply to the customer as the user sees it.',
          (reply) => reply,
        ),
      ],
      calls: [
        AgentTool(
          surface.setReply,
          name: 'set_reply',
          description: 'Replaces the whole reply with [text].',
          parameters: const {
            'type': 'object',
            'properties': {
              'text': {'type': 'string'},
            },
            'required': ['text'],
          },
          invoke: (args) {
            surface.setReply(args.read('text'));
            return null;
          },
        ),
        AgentTool(
          surface.send,
          name: 'send',
          description: 'Sends the reply to the customer by e-mail.',
          parameters: const {'type': 'object', 'properties': {}},
          invoke: (args) {
            surface.send();
            return null;
          },
        ),
      ],
    );
  }
}
