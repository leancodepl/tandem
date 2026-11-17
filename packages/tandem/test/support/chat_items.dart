import 'package:tandem/tandem.dart';

/// What the chat shows: each item as a short record, a notice as its kind.
List<Object> summaryOf(List<ChatItem> items) => [
  for (final item in items)
    switch (item) {
      UserMessage(:final text) => ('user', text),
      AgentMessage(:final text, :final stopped) => ('agent', text, stopped),
      ChatNotice(:final kind) => kind,
      ApprovalRequest(:final tool, :final status) => (tool, status),
    },
];
