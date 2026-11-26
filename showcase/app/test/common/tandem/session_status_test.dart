import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/tandem/session_status.dart';

void main() {
  test('the agent works while it thinks or a method runs', () {
    expect(const Thinking().isWorking, isTrue);
    expect(const Calling(_Tool.book, approved: true).isWorking, isTrue);
    expect(const Idle().isWorking, isFalse);
    expect(const Stopping().isWorking, isFalse);
  });

  test('a run that stops still runs, and one that waits does not', () {
    final request = ApprovalRequest(
      tool: _Tool.book,
      description: 'Books every change.',
      arguments: {},
    );

    expect(const Stopping().isRunning, isTrue);
    expect(const Calling(_Tool.book, approved: false).isRunning, isTrue);
    expect(const Idle().isRunning, isFalse);
    expect(AwaitingApproval(request).isRunning, isFalse);
  });

  test('a call the traveller approved cannot be stopped', () {
    expect(const Thinking().isStoppable, isTrue);
    expect(const Calling(_Tool.book, approved: false).isStoppable, isTrue);
    expect(const Calling(_Tool.book, approved: true).isStoppable, isFalse);
    expect(const Idle().isStoppable, isFalse);
  });
}

enum _Tool(@override final String value) implements ToolName {
  book('book'),
}
