import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:tandem_generator/tandem_generator.dart';
import 'package:test/test.dart';

void main() {
  test('.sees inside if fails the build', () async {
    expect(
      await _buildErrors('''
class AuditCubit() {
  bool get isAdmin => true;

  /// The audit log.
  List<String> get log => [];

  List<AgentCapability> get agent => [if (isAdmin) .sees(log)];
}
'''),
      [contains('.sees must be an item of the list after get agent =>')],
    );
  });

  test('a method without a doc comment fails the build', () async {
    expect(
      await _buildErrors('''
class OrderCubit() {
  List<AgentCapability> get agent => [.calls(placeOrder)];

  void placeOrder() {}
}
'''),
      [contains('Add a doc comment to placeOrder')],
    );
  });

  test('a class Tandem cannot build fails the build', () async {
    expect(
      await _buildErrors('''
class Slot {
  Slot(int hours) : minutes = hours * 60;

  final int minutes;
}

class DeliveryCubit() {
  List<AgentCapability> get agent => [.calls(book)];

  /// Books a delivery slot.
  void book(Slot slot) {}
}
'''),
      [
        contains(
          'slot: Tandem writes Slot through the getters named like its constructor parameters, and it has no getter hours',
        ),
      ],
    );
  });

  test('a result the agent cannot see fails the build', () async {
    expect(
      await _buildErrors('''
class OrderCubit() {
  List<AgentCapability> get agent => [.calls(placeOrder)];

  /// Places the order.
  Future<Object> placeOrder() async => Object();
}
'''),
      [contains('The agent cannot see Object at the result of placeOrder')],
    );
  });
}

/// The errors of building [source], a library that imports `tandem`.
Future<List<String>> _buildErrors(String source) async {
  final result = await testBuilder(
    tandemBuilder(BuilderOptions.empty),
    {
      'tandem|lib/tandem.dart': '''
sealed class AgentCapability {
  factory AgentCapability.sees(Object? value) => throw UnimplementedError();
  factory AgentCapability.calls(Function method) => throw UnimplementedError();
  factory AgentCapability.callsWithApproval(Function method) =>
      throw UnimplementedError();
}
''',
      'app|lib/screen.dart': "import 'package:tandem/tandem.dart';\n\n$source",
    },
    rootPackage: 'app',
    generateFor: {'app|lib/screen.dart'},
  );
  return result.errors.toList();
}
