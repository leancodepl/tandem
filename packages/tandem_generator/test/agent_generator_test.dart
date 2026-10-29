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

  test('the list is copied with each .sees named by its getter', () async {
    final result = await _build('''
@TandemAgent()
class AuditCubit() {
  static const admin = 'admin';
  String role = admin;

  /// The audit log.
  List<String> get log => [];

  List<AgentCapability> get agentCapabilities => [if (role == admin) .sees(log)];
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      contains("if (role == AuditCubit.admin) .seesAs('log', log),"),
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
      [
        allOf(
          contains('the result of placeOrder: Tandem has no form for Object.'),
          contains(
            'A JsonConverter<Object, S> in converters: gives it a form.',
          ),
        ),
      ],
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

  test('a converter id has the configuration its superclass holds', () async {
    final result = await _build('''
enum Style { plain, bold }

class Format {
  const Format(this.style);

  final Style style;
}

abstract class PrefixConverter {
  const PrefixConverter(this.prefix, this.format);

  final String prefix;
  final Format format;
}

final class CodeConverter extends PrefixConverter
    implements JsonConverter<Code, String> {
  const CodeConverter(super.prefix, super.format);
}

final class const Code();

@TandemAgent(converters: [CodeConverter('a:', Format(Style.bold))])
class CodeCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(code)];

  /// The code.
  Code get code => const Code();
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      contains(
        'package:app/screen.dart#CodeConverter(prefix: "a:", '
        'format: package:app/screen.dart#Format(style: Style.bold))',
      ),
    );
  });

  test(
    'a converter id has the fields its primary constructor declares',
    () async {
      final result = await _build('''
final class const SlugConverter(final String separator)
    implements JsonConverter<Slug, String>;

final class const Slug();

@TandemAgent(converters: [SlugConverter('-')])
class SlugCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(slug)];

  /// The slug.
  Slug get slug => const Slug();
}
''');

      expect(result.errors, isEmpty);
      expect(
        result.readerWriter.testing.readString(
          .parse('app|lib/screen.tandem.g.part'),
        ),
        contains('package:app/screen.dart#SlugConverter(separator: "-")'),
      );
    },
  );

  test('a converter id has the content of its maps, sets, types, symbols, '
      'records and functions', () async {
    final result = await _build('''
enum Style { plain, bold }

final class const Format(final Style style);

String shout(String text) => text;

final class const CodeConverter(
  final Map<String, Format?> labels,
  final Set<Object> tags,
  final Type kind,
  final Symbol key,
  final (int, {Format format}) layout,
  final String Function(String) transform,
) implements JsonConverter<Code, String>;

final class const Code();

@TandemAgent(
  converters: [
    CodeConverter(
      {'k': Format(Style.bold), 'n': null},
      {1, Style.plain},
      Map<String, int>,
      #key,
      (1, format: Format(Style.plain)),
      shout,
    ),
  ],
)
class CodeCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(code)];

  /// The code.
  Code get code => const Code();
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      contains(
        'package:app/screen.dart#CodeConverter('
        'labels: {"k": package:app/screen.dart#Format(style: Style.bold), '
        '"n": null}, '
        'tags: {1, Style.plain}, '
        'kind: dart:core#Map<dart:core#String,dart:core#int>, '
        'key: #key, '
        'layout: (1, format: package:app/screen.dart#Format(style: '
        'Style.plain)), '
        'transform: package:app/screen.dart#shout)',
      ),
    );
  });

  test('a converter id quotes its strings, so that a string does not read as '
      'another value', () async {
    final result = await _build('''
final class const CodeConverter(final List<Object?> parts)
    implements JsonConverter<Code, String>;

final class const Code();

@TandemAgent(converters: [CodeConverter(['a, b', '1', 'null'])])
class CodeCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(code)];

  /// The code.
  Code get code => const Code();
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      contains(
        'package:app/screen.dart#CodeConverter(parts: ["a, b", "1", "null"])',
      ),
    );
  });

  test('a converter id has the type arguments of the converter and of its '
      'configuration', () async {
    final result = await _build('''
final class const Prefix<T>();

final class const CodeConverter<T>(final Prefix<Object> prefix)
    implements JsonConverter<Code, String>;

final class const Code();

@TandemAgent(converters: [CodeConverter<int>(Prefix<String>())])
class CodeCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(code)];

  /// The code.
  Code get code => const Code();
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      contains(
        'package:app/screen.dart#CodeConverter<dart:core#int>(prefix: '
        'package:app/screen.dart#Prefix<dart:core#String>())',
      ),
    );
  });

  test('a converter of a nullable type fails the build', () async {
    expect(
      await _buildErrors('''
final class const LinkConverter() implements JsonConverter<Uri?, String?> {}

@TandemAgent(converters: [LinkConverter()])
class LinkCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(open)];

  /// Opens the link.
  void open(Uri? link) {}
}
'''),
      [
        contains(
          'converters: LinkConverter converts Uri?, and a converter matches '
          'the type without ?: Tandem handles null. Make it a '
          'JsonConverter<Uri, String?>.',
        ),
      ],
    );
  });

  test('a class with a converter that Tandem could build is an object, and '
      'one with a private constructor a value', () async {
    final result = await _build('''
final class const Grower(final String code);
final class const Ink._(final String name);

final class const GrowerConverter() implements JsonConverter<Grower, String> {}
final class const InkConverter() implements JsonConverter<Ink, String> {}

@TandemAgent(converters: [GrowerConverter(), InkConverter()])
class NurseryCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(assign)];

  /// Assigns [grower] in [ink].
  void assign(Grower grower, Ink ink) {}
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      allOf(
        contains(RegExp(r"#GrowerConverter\(\)',\s*object: true")),
        isNot(contains(RegExp(r"#InkConverter\(\)',\s*object: true"))),
      ),
    );
  });

  test('a class with a converter that Tandem cannot read is a value', () async {
    final result = await _build('''
final class const Version(final int major, final int minor);

final class const VersionConverter()
    implements JsonConverter<Version, String> {}

@TandemAgent(converters: [VersionConverter()])
class NurseryCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(pin)];

  /// Pins [version].
  void pin(Version version) {}
}
''');

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      allOf(contains('#VersionConverter()'), isNot(contains('object:'))),
    );
  });

  test('two converters for one type fail the build', () async {
    expect(
      await _buildErrors('''
final class const HexIcon() implements JsonConverter<Icon, String> {}
final class const NamedIcon() implements JsonConverter<Icon, String> {}

@TandemAgent(converters: [HexIcon(), NamedIcon()])
class IconCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(setIcon)];

  /// Sets the icon.
  void setIcon(Icon icon) {}
}
'''),
      [contains('converters: has two for Icon, HexIcon and NamedIcon.')],
    );
  });

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
import 'package:json_annotation/json_annotation.dart';

final class const TandemAgent({
  final List<JsonConverter<Object?, Object?>> converters = const [],
});

sealed class AgentCapability {
  factory AgentCapability.sees(Object? value) => throw UnimplementedError();
  factory AgentCapability.seesAs(String name, Object? value) =>
      throw UnimplementedError();
  factory AgentCapability.calls(Function method) => throw UnimplementedError();
}
''',
    'json_annotation|lib/json_annotation.dart': '''
abstract interface class JsonConverter<T, S> {}
''',
    'app|lib/screen.dart':
        "import 'package:json_annotation/json_annotation.dart';\n"
        "import 'package:tandem/tandem.dart';\n\n"
        'class Icon();\n\n$source',
  },
  rootPackage: 'app',
  generateFor: {'app|lib/screen.dart'},
  flattenOutput: true,
);
