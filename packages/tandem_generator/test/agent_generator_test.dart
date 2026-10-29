import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:tandem_generator/tandem_generator.dart';
import 'package:test/test.dart';

void main() {
  test('@TandemAgent() without agentCapabilities fails the build', () async {
    expect(
      await _buildErrors('''
@TandemAgent()
class OrderCubit() {
  /// Places the order.
  void placeOrder() {}
}
'''),
      [
        contains(
          'Add @override List<AgentCapability> get agentCapabilities => [...] '
          'to OrderCubit',
        ),
      ],
    );
  });

  test('a class without @TandemAgent() gets no code', () async {
    final result = await _build('''
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(placeOrder)];

  /// Places the order.
  void placeOrder() {}
}
''');

    expect(result.errors, isEmpty);
    expect(result.outputs, isEmpty);
  });

  test('.sees inside if fails the build', () async {
    expect(
      await _buildErrors('''
@TandemAgent()
class AuditCubit() {
  bool get isAdmin => true;

  /// The audit log.
  List<String> get log => [];

  List<AgentCapability> get agentCapabilities => [if (isAdmin) .sees(log)];
}
'''),
      [
        contains(
          '.sees must be an item of the list after get agentCapabilities =>',
        ),
      ],
    );
  });

  test('a method without a doc comment fails the build', () async {
    expect(
      await _buildErrors('''
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(placeOrder)];

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

@TandemAgent()
class DeliveryCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(book)];

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
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(placeOrder)];

  /// Places the order.
  Future<Object> placeOrder() async => Object();
}
'''),
      [contains('the result of placeOrder: Tandem has no form for Object.')],
    );
  });

  test('a class with a public named constructor is no token class', () async {
    expect(
      await _buildErrors('''
class const Radius.circular(final double x) {
  static const zero = Radius.circular(0);
}

@TandemAgent()
class CardCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(round)];

  /// Rounds the corners by [radius].
  void round(Radius radius) {}
}
'''),
      [contains('radius: Tandem builds Radius with its unnamed constructor')],
    );
  });

  test('a class without a public constructor is a token class', () async {
    final result = await _build('''
final class const Weight._(final int value) {
  static const regular = Weight._(400);
  static const bold = Weight._(700);
}

@TandemAgent()
class TextCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(emphasize)];

  /// Sets the weight of the text.
  void emphasize(Weight weight) {}
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      allOf(contains('.token('), contains("'bold': .bold")),
    );
  });

  for (final (shape, constructor) in [
    ('a named parameter', 'Coupon({required String code}) : this._(code);'),
    ('another type', r"Coupon(int code) : this._('$code');"),
    ('a nullable value', "Coupon(String? code) : this._(code ?? '');"),
  ]) {
    test(
      'an extension type whose constructor takes $shape fails the build',
      () async {
        expect(
          await _buildErrors('''
extension type Coupon._(String code) {
  $constructor
}

@TandemAgent()
class CartCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(redeem)];

  /// Redeems [coupon].
  void redeem(Coupon coupon) {}
}
'''),
          [
            contains(
              'coupon: Tandem builds Coupon as Coupon(value), so its unnamed constructor must be public and take only the value: one positional, non-null String.',
            ),
          ],
        );
      },
    );
  }

  test('a generic class has the nullability of its type arguments in its id, '
      'as AgentType.id writes it', () async {
    final result = await _build('''
class const Page<T>({required final List<T> items});

@TandemAgent()
class SearchCubit() {
  List<AgentCapability> get agentCapabilities => [
    .sees(names),
    .sees(hidden),
    .sees(groups),
  ];

  /// The names found.
  Page<String> get names => const Page(items: []);

  /// The names found, null for a hidden one.
  Page<String?> get hidden => const Page(items: []);

  /// The names found in groups.
  Page<List<String?>?> get groups => const Page(items: []);
}
''');

    expect(result.errors, isEmpty);
    final output = result.readerWriter.testing.readString(
      .parse('app|lib/screen.tandem.g.part'),
    );
    for (final id in [
      'package:app/screen.dart#Page<dart:core#String>',
      'package:app/screen.dart#Page<dart:core#String?>',
      'package:app/screen.dart#Page<List<dart:core#String?>?>',
    ]) {
      expect(output, contains("id: '$id'"));
    }
  });

  test(
    'a doc comment keeps its paragraphs but not its wrapped lines',
    () async {
      final result = await _build('''
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(placeOrder)];

  /// Places the order exactly as it is
  /// on the screen.
  ///
  /// Needs approval.
  void placeOrder() {}
}
''');

      expect(result.errors, isEmpty);
      expect(
        result.readerWriter.testing.readString(
          .parse('app|lib/screen.tandem.g.part'),
        ),
        contains(
          r"'Places the order exactly as it is on the screen.\n\nNeeds approval.'",
        ),
      );
    },
  );

  test('a default with control characters becomes a valid literal', () async {
    final result = await _build(r'''
@TandemAgent()
class NoteCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(write)];

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

Future<List<String>> _buildErrors(String source) async =>
    (await _build(source)).errors.toList();

Future<TestBuilderResult> _build(String source) => testBuilder(
  tandemBuilder(BuilderOptions.empty),
  {
    'tandem|lib/tandem.dart': '''
final class const TandemAgent();

sealed class AgentCapability {
  factory AgentCapability.sees(Object? value) => throw UnimplementedError();
  factory AgentCapability.calls(Function method) => throw UnimplementedError();
}
''',
    'app|lib/screen.dart': "import 'package:tandem/tandem.dart';\n\n$source",
  },
  rootPackage: 'app',
  generateFor: {'app|lib/screen.dart'},
  flattenOutput: true,
);
