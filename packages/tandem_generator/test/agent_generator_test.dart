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

  test(
    'an extension type with a named constructor parameter fails the build',
    () async {
      expect(
        await _buildErrors('''
extension type Coupon._(String code) {
  Coupon({required String code}) : this._(code);
}

class CartCubit() {
  List<AgentCapability> get agent => [.calls(redeem)];

  /// Redeems [coupon].
  void redeem(Coupon coupon) {}
}
'''),
        [
          contains(
            'coupon: Tandem builds Coupon as Coupon(value), so its unnamed constructor must be public and take the value as its only parameter, a positional one',
          ),
        ],
      );
    },
  );

  test('a default with control characters becomes a valid literal', () async {
    final result = await _build(r'''
class NoteCubit() {
  List<AgentCapability> get agent => [.calls(write)];

  /// Writes [text] and a line break.
  void write(String text, {String lineBreak = '\r\n'}) {}
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      contains(r": '\r\n'"),
    );
  });
}

/// The errors of building [source].
Future<List<String>> _buildErrors(String source) async =>
    (await _build(source)).errors.toList();

/// Builds [source], a library that imports `tandem`.
Future<TestBuilderResult> _build(String source) => testBuilder(
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
  flattenOutput: true,
);
