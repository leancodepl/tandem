import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/tandem/session_status.dart';

void main() {
  test('the agent works while it thinks or a method runs', () {
    expect(const Thinking().isWorking, isTrue);
    expect(const Calling('book_changes', approved: true).isWorking, isTrue);
    expect(const Idle().isWorking, isFalse);
    expect(const Stopping().isWorking, isFalse);
  });

  test('a run that stops still runs, and one that waits does not', () {
    expect(const Stopping().isRunning, isTrue);
    expect(const Calling('find_flights', approved: false).isRunning, isTrue);
    expect(const Idle().isRunning, isFalse);
    expect(
      const AwaitingApproval(
        ApprovalRequest(
          toolCallId: 'call-1',
          tool: 'book_changes',
          description: 'Books every change.',
          argumentsJson: '{}',
        ),
      ).isRunning,
      isFalse,
    );
  });

  test('a call the traveller approved cannot be stopped', () {
    expect(const Thinking().isStoppable, isTrue);
    expect(const Calling('find_flights', approved: false).isStoppable, isTrue);
    expect(const Calling('book_changes', approved: true).isStoppable, isFalse);
    expect(const Idle().isStoppable, isFalse);
  });
}
