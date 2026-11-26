import 'package:analyzer/dart/analysis/results.dart';
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

  test('two methods of one agent name fail the build', () async {
    expect(
      await _buildErrors('''
@TandemAgent()
class LinkCubit() {
  List<AgentCapability> get agentCapabilities => [
    .calls(setUrl),
    .calls(setURL),
  ];

  /// Sets the link.
  void setUrl(String url) {}

  /// Sets the link and opens it.
  void setURL(String url) {}
}
'''),
      [contains('Rename setUrl or setURL: the agent knows both as set_url.')],
    );
  });

  test('a method named like a tool of Tandem fails the build', () async {
    expect(
      await _buildErrors('''
@TandemAgent()
class ViewCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(tandemShowView)];

  /// Shows the view.
  void tandemShowView() {}
}
'''),
      [
        contains(
          'Rename tandemShowView: the agent knows it as tandem_show_view',
        ),
      ],
    );
  });

  test('a private method names its tool with a public enum member that '
      'compiles, and the name on the wire stays', () async {
    final code = await _compile('''
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [
    .calls(_refresh),
    .calls(_switch),
    .calls(_index),
    .calls(_2fa),
    .calls(_OrderCubitTool),
    .calls(_String),
    .calls(_as),
    .calls(_when),
  ];

  /// Loads the order again.
  void _refresh() {}

  /// Switches the delivery mode.
  void _switch() {}

  /// Opens the index of orders.
  void _index() {}

  /// Asks for the second factor.
  void _2fa() {}

  /// Opens the tools of the order.
  void _OrderCubitTool() {}

  /// Copies the order as text.
  void _String() {}

  /// Saves the order as a draft.
  void _as() {}

  /// Plans when to deliver.
  void _when() {}
}
''');

    expect(
      code,
      allOf([
        contains('enum OrderCubitTool implements ToolName {'),
        contains("refresh => 'refresh',"),
        contains('name: OrderCubitTool.refresh,'),
        contains("switch_ => 'switch',"),
        contains("index_ => 'index',"),
        contains(r"$2fa => '2fa',"),
        contains("OrderCubitTool_ => 'order_cubit_tool',"),
        contains("String_ => 'string',"),
      ]),
    );
  });

  test('two methods of one enum member fail the build', () async {
    final errors = await _buildErrors('''
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [
    .calls(_switch),
    .calls(switch_),
  ];

  /// Switches the delivery mode.
  void _switch() {}

  /// Switches the delivery mode back.
  void switch_() {}
}
''');

    expect(errors, [
      contains('Rename _switch or switch_: both would be switch_ in'),
    ]);
  });

  test('a declaration named like the tool enum fails the build', () async {
    expect(
      await _buildErrors('''
final class NameTool();

@TandemAgent()
class Name() {
  List<AgentCapability> get agentCapabilities => [.calls(placeOrder)];

  /// Places the order.
  void placeOrder() {}
}
'''),
      [contains('Rename NameTool or Name: ')],
    );
  });

  for (final (capability, message) in [
    ('.sees(draft.length)', '.sees takes a getter of NoteCubit'),
    ('.calls(() => save())', '.calls takes a method of NoteCubit'),
  ]) {
    test('$capability fails the build', () async {
      expect(
        await _buildErrors('''
@TandemAgent()
class NoteCubit() {
  List<AgentCapability> get agentCapabilities => [$capability];

  /// The draft of the note.
  String get draft => '';

  /// Saves the note.
  void save() {}
}
'''),
        [contains(message)],
      );
    });
  }

  test('agentCapabilities that reads super fails the build', () async {
    expect(
      await _buildErrors('''
abstract class BaseCubit {
  List<AgentCapability> get agentCapabilities => [];
}

@TandemAgent()
class OrderCubit extends BaseCubit {
  @override
  List<AgentCapability> get agentCapabilities => [
    ...super.agentCapabilities,
    .calls(placeOrder),
  ];

  /// Places the order.
  void placeOrder() {}
}
'''),
      [contains('agentCapabilities cannot use super')],
    );
  });

  test('an optional list parameter fails the build', () async {
    expect(
      await _buildErrors('''
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(tag)];

  /// Tags the order.
  void tag({List<String> tags = const []}) {}
}
'''),
      [contains('tags is a list, so the agent must send it')],
    );
  });

  test('a class that contains itself fails the build', () async {
    expect(
      await _buildErrors('''
class const Category({
  required final String name,
  required final List<Category> children,
});

@TandemAgent()
class ShopCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(categories)];

  /// The categories of the shop.
  List<Category> get categories => const [];
}
'''),
      [contains('Category contains itself.')],
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

  test('a doc comment keeps its paragraphs and list items but not its wrapped '
      'lines', () async {
    expect(
      await _generate('''
@TandemAgent()
class OrderCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(placeOrder)];

  /// Places the order exactly as it is
  /// on the screen. Call it when:
  /// - the cart is full
  /// - the user confirmed
  ///
  /// Needs approval.
  void placeOrder() {}
}
'''),
      contains(
        r"'Places the order exactly as it is on the screen. Call it when:\n"
        r"- the cart is full\n- the user confirmed\n\nNeeds approval.'",
      ),
    );
  });

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

  test('a converter that writes a map fails the build and names the '
      'converter', () async {
    expect(
      await _buildErrors('''
final class const Money();

final class const MoneyConverter()
    implements JsonConverter<Money, Map<String, dynamic>> {}

@TandemAgent(converters: [MoneyConverter()])
class PriceCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(price)];

  /// The price.
  Money get price => const Money();
}
'''),
      [
        contains(
          'price: MoneyConverter writes Map<String, dynamic>, which Tandem has '
          'no form for.',
        ),
      ],
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

  test('converters: comes from @TandemAgent, not from another annotation '
      'that takes it', () async {
    expect(
      await _generate('''
final class const Serializable({final List<Object> converters = const []});

final class const Code();
final class const CodeConverter() implements JsonConverter<Code, String> {}
final class const EpochConverter() implements JsonConverter<DateTime, int> {}

@Serializable(converters: [EpochConverter()])
@TandemAgent(converters: [CodeConverter()])
class CodeCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(code)];

  /// The code.
  Code get code => const Code();
}
'''),
      contains(r'_$CodeCubitConverters = [CodeConverter()];'),
    );
  });

  test('a required parameter without a form stops the catalog', () async {
    expect(
      await _buildErrors('''
class const Version(final int major, final int minor);

/// The notes of a release.
final class const ReleaseNotes({
  required final String title,
  required final Version version,
}) extends StatelessWidget;

/// Draw release notes.
///
/// ```json
/// [{"id": "root", "component": "ReleaseNotes", "title": "What is new"}]
/// ```
@TandemCatalog([ReleaseNotes])
final class const ShopCatalog();
'''),
      [
        contains(
          'ReleaseNotes.version: Version has no form. Add a '
          'JsonConverter<Version, S> to converters:, or leave ReleaseNotes '
          'out.',
        ),
      ],
    );
  });

  test('the converter that a required parameter needs keeps the ? inside its '
      'type, and a callback names the type it passes', () async {
    String catalogWith(String parameter) =>
        '''
class Unknown();
class const Box<T>({required final T value});

/// The notes of a release.
final class const ReleaseNotes({
  required final String title,
  $parameter,
}) extends StatelessWidget;

/// Draw release notes.
///
/// ```json
/// [{"id": "root", "component": "ReleaseNotes", "title": "What is new"}]
/// ```
@TandemCatalog([ReleaseNotes])
final class const ShopCatalog();
''';

    expect(
      await _buildErrors(catalogWith('required final Box<Unknown?> box')),
      [contains('Add a JsonConverter<Box<Unknown?>, S> to converters:')],
    );
    expect(
      await _buildErrors(
        catalogWith('required final ValueChanged<Unknown?> onPick'),
      ),
      [contains('Add a JsonConverter<Unknown, S> to converters:')],
    );
  });

  test('a widget without a doc comment stops the catalog', () async {
    expect(
      await _buildErrors('''
final class const StockBadge({required final String label}) extends StatelessWidget;

/// Mark the plants that run low.
///
/// ```json
/// [{"id": "root", "component": "StockBadge", "label": "Low"}]
/// ```
@TandemCatalog([StockBadge])
final class const ShopCatalog();
'''),
      [contains('Add a doc comment to StockBadge')],
    );
  });

  test('converters that convert into each other fail the build', () async {
    expect(
      await _buildErrors('''
class const Ink();
class const Shade();
final class const InkConverter() implements JsonConverter<Ink, Shade> {}
final class const ShadeConverter() implements JsonConverter<Shade, Ink> {}

@TandemAgent(converters: [InkConverter(), ShadeConverter()])
class PaintCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(paint)];

  /// Paints with [ink].
  void paint(Ink ink) {}
}
'''),
      [contains('writes a type that converts back into the one it converts')],
    );
  });

  test('an example that names another component stops the catalog', () async {
    expect(
      await _buildErrors('''
/// A word on how much of a plant is left, such as "Low".
final class const StockBadge({required final String label}) extends StatelessWidget;

/// Mark the plants that run low.
///
/// ```json
/// [{"id": "root", "component": "Badge", "label": "Low"}]
/// ```
@TandemCatalog([StockBadge])
final class const ShopCatalog();
'''),
      [contains('root has no component Badge. Components: StockBadge.')],
    );
  });

  test('an example that sets a property the widget lacks stops the '
      'catalog', () async {
    expect(
      await _buildErrors('''
/// A word on how much of a plant is left, such as "Low".
final class const StockBadge({required final String label}) extends StatelessWidget;

/// Mark the plants that run low.
///
/// ```json
/// [{"id": "root", "component": "StockBadge", "text": "Low"}]
/// ```
@TandemCatalog([StockBadge])
final class const ShopCatalog();
'''),
      [contains('root: StockBadge has no "text". Properties: label.')],
    );
  });

  test('two widgets of one name stop the catalog', () async {
    const card = '''
import 'package:flutter/widgets.dart';

/// A card.
final class const Card({required final String label}) extends StatelessWidget;
''';
    final result = await _build(
      '''
import 'first.dart' as first;
import 'second.dart' as second;

/// Draw cards.
///
/// ```json
/// [{"id": "root", "component": "Card", "label": "Hello"}]
/// ```
@TandemCatalog([first.Card, second.Card])
final class const ShopCatalog();
''',
      libraries: {'first.dart': card, 'second.dart': card},
    );

    expect(result.errors, [
      contains(
        'ShopCatalog lists two widgets named Card, '
        'package:app/first.dart#Card and package:app/second.dart#Card. The '
        'agent names a component by its class: leave one out or rename it.',
      ),
    ]);
  });

  test('a callback with a default is still an action the widget needs, and '
      'an optional field without a form is left out', () async {
    final output = await _generate('''
class const Moment();

/// A player.
final class const Player({
  final VoidCallback onPlay = _ignore,
  final ValueChanged<Moment>? onSeek,
}) extends StatelessWidget;

void _ignore() {}

/// Draw a player.
///
/// ```json
/// [{"id": "root", "component": "Player", "onPlay": {"action": {"event": {"name": "play"}}}}]
/// ```
@TandemCatalog([Player])
final class const PlayerCatalog();
''');

    expect(output, contains("property.press('onPlay')"));
    expect(output, isNot(contains('onSeek')));
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
      contains(r"args.readOr('lineBreak', '\r\n')"),
    );
  });

  test(
    'a freezed class and inherited fields are read by their getters',
    () async {
      expect(
        await _generate(r"""
mixin _$Person {
  String get name;
}

abstract class Person with _$Person {
  const factory Person({required String name}) = _Person;
}

final class _Person implements Person {
  const _Person({required this.name});

  @override
  final String name;
}

class const Party({required final String id});

class Customer extends Party {
  Customer({required super.id});
}

@TandemAgent()
class PeopleCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(person), .sees(customer)];

  /// The person.
  Person get person => const Person(name: 'Ada');

  /// The customer.
  Customer get customer => Customer(id: '1');
}
"""),
        allOf(
          contains("field('name', (value) => value.name)"),
          contains("field('id', (value) => value.id)"),
        ),
      );
    },
  );

  test('a member that a library name hides is read through this', () async {
    expect(
      await _generate('''
void log(String message) {}

@TandemAgent()
class AuditCubit() {
  List<AgentCapability> get agentCapabilities => [.sees(log)];

  /// The audit log.
  List<String> get log => [];
}
'''),
      contains("seesAs('log', this.log)"),
    );
  });

  test('a default of an extension type fails the build', () async {
    expect(
      await _buildErrors('''
extension type const ProductId(int value) {}

@TandemAgent()
class CartCubit() {
  List<AgentCapability> get agentCapabilities => [.calls(add)];

  /// Adds [product].
  void add({ProductId product = const ProductId(7)}) {}
}
'''),
      [contains('Make product required or nullable instead.')],
    );
  });

  test('a default that is a static const member of its class is copied, '
      'named by the class when the parameter has another type', () async {
    expect(
      await _generate('''
/// A box that places its child.
final class const Box({
  final Alignment alignment = Alignment.topLeft,
  final AlignmentGeometry origin = Alignment.center,
}) extends StatelessWidget;

/// Draw boxes.
///
/// ```json
/// [{"id": "root", "component": "Box"}]
/// ```
@TandemCatalog([Box])
final class const ShopCatalog();
'''),
      allOf(
        contains("args.valueOr('alignment', .topLeft)"),
        contains("args.valueOr('origin', Alignment.center)"),
      ),
    );
  });

  test("a default the generated code cannot write keeps the widget's "
      'default, with one line in the build', () async {
    final log = <String>[];
    final result = await _build(
      '''
import 'box.dart' show Box;

/// Draw boxes.
///
/// ```json
/// [{"id": "root", "component": "Box"}]
/// ```
@TandemCatalog([Box])
final class const ShopCatalog();
''',
      libraries: {
        'box.dart': '''
import 'package:flutter/widgets.dart';

class const Corner() extends AlignmentGeometry {
  static const middle = Corner();
}

/// A box that places its child.
final class const Box({
  final Alignment tilt = const Alignment(0.5, 0),
  final AlignmentGeometry corner = Corner.middle,
}) extends StatelessWidget;
''',
      },
      onLog: log.add,
    );

    expect(result.errors, isEmpty);
    expect(
      log,
      containsAllInOrder([
        endsWith(
          'Box.tilt keeps its default: Tandem copies only literals, enum '
          "values and the static const members of the value's class.",
        ),
        endsWith(
          'Box.corner: this library does not import Corner, so the generated '
          'code cannot copy the default Corner.middle. Import it.',
        ),
      ]),
    );
  });

  test('a child with a default keeps it, with one line in the build, and an '
      'empty list of children stays settable', () async {
    final log = <String>[];
    final result = await _build('''
/// A chevron.
final class const Chevron() extends StatelessWidget;

/// A tile.
final class const Tile({
  final Widget trailing = const Chevron(),
  final List<Widget> footer = const [],
}) extends StatelessWidget;

/// Draw tiles.
///
/// ```json
/// [{"id": "root", "component": "Tile"}]
/// ```
@TandemCatalog([Chevron, Tile])
final class const ShopCatalog();
''', onLog: log.add);

    expect(result.errors, isEmpty);
    expect(
      result.readerWriter.testing.readString(
        .parse('app|lib/screen.tandem.g.part'),
      ),
      allOf(isNot(contains("'trailing'")), contains("args.children('footer')")),
    );
    expect(
      log,
      contains(
        endsWith(
          'Tile.trailing keeps its default: Tandem cannot copy a widget, so '
          'the agent cannot set it.',
        ),
      ),
    );
  });

  test('a getter of another type names the type of its property', () async {
    expect(
      await _generate("""
/// A label with a hint.
final class Label extends StatelessWidget {
  const Label({String? hint}) : hint = hint ?? '';

  final String hint;
}

/// Draw labels.
///
/// ```json
/// [{"id": "root", "component": "Label"}]
/// ```
@TandemCatalog([Label])
final class const ShopCatalog();
"""),
      contains(
        "property<String?>('hint').value(.nullable(.string), required: false)",
      ),
    );
  });

  test('a parameter of a widget subtype stops the catalog', () async {
    expect(
      await _buildErrors('''
/// A glyph.
final class const Glyph() extends StatelessWidget;

/// A tile with a glyph.
final class const GlyphTile({required final Glyph glyph}) extends StatelessWidget;

/// Draw tiles.
///
/// ```json
/// [{"id": "root", "component": "GlyphTile"}]
/// ```
@TandemCatalog([Glyph, GlyphTile])
final class const ShopCatalog();
'''),
      [
        contains(
          'GlyphTile.glyph: the agent sets a child as Widget or List<Widget>, '
          'and Glyph is neither.',
        ),
      ],
    );
  });

  test(
    'an inherited method names its types as the surface imports them',
    () async {
      expect(
        await _generate(
          '''
import 'base.dart';
import 'tier.dart' as t;

@TandemAgent()
class TierCubit extends BaseCubit {
  List<AgentCapability> get agentCapabilities => [.calls(setTier)];
}
''',
          libraries: {
            'tier.dart': 'enum Tier { gold, silver }',
            'base.dart': '''
import 'tier.dart' as n;

abstract class BaseCubit {
  /// Sets the tier.
  void setTier(n.Tier tier) {}
}
''',
          },
        ),
        contains('AgentParameter<t.Tier>('),
      );
    },
  );

  test(
    'a method inherited from a generic class names its type arguments',
    () async {
      final code = await _generate('''
enum Tier { gold, silver }

abstract class ValueCubit<T> {
  /// The value.
  T get value => throw UnimplementedError();

  /// Sets the value.
  void setValue(T value) {}
}

@TandemAgent()
class TierCubit extends ValueCubit<Tier> {
  List<AgentCapability> get agentCapabilities => [
    .sees(value),
    .calls(setValue),
  ];
}
''');

      expect(code, contains('AgentParameter<Tier>('));
      expect(code, isNot(contains('<T>')));
    },
  );

  test('a generic surface keeps the bounds of its type parameters', () async {
    expect(
      await _generate('''
@TandemAgent()
class ListCubit<T extends Object>() {
  List<AgentCapability> get agentCapabilities => [.sees(count)];

  /// How many items the list has.
  int get count => 0;
}
'''),
      contains('extension<T extends Object> on ListCubit<T> {'),
    );
  });

  test('a static member in a string interpolation stays in it', () async {
    expect(
      await _generate(r"""
@TandemAgent()
class ShopCubit() {
  static const label = 'shop';
  String mode = '';

  List<AgentCapability> get agentCapabilities => [
    if (mode == 'edit-$label') .calls(save),
  ];

  /// Saves the shop.
  void save() {}
}
"""),
      contains(r"'edit-${ShopCubit.label}'"),
    );
  });

  test('a required nullable parameter without a form gets null', () async {
    expect(
      await _generate('''
class const Version(final int major, final int minor);

/// The notes of a release.
final class const ReleaseNotes({
  required final String title,
  required final Version? version,
}) extends StatelessWidget;

/// Draw release notes.
///
/// ```json
/// [{"id": "root", "component": "ReleaseNotes", "title": "What is new"}]
/// ```
@TandemCatalog([ReleaseNotes])
final class const ShopCatalog();
'''),
      contains('version: null'),
    );
  });
}

Future<List<String>> _buildErrors(String source) async =>
    (await _build(source)).errors.toList();

/// The generated code of [source], in which the analyzer finds no error.
Future<String> _compile(String source) async {
  final files = (await _build(source)).readerWriter.testing;
  final screen = AssetId.parse('app|lib/screen.dart');
  final code = files.readString(.parse('app|lib/screen.tandem.g.part'));
  final errors = await resolveSources(
    {
      for (final asset in files.assets) '$asset': files.readString(asset),
      '$screen': '${files.readString(screen)}\n$code',
    },
    (resolver) async {
      final library = await resolver.libraryFor(screen);
      final analysis = await library.session.getResolvedLibraryByElement(
        library,
      ) as ResolvedLibraryResult;

      return [
        for (final diagnostic in analysis.units.single.diagnostics)
          if (diagnostic.severity == .error) diagnostic.message,
      ];
    },
  );

  expect(errors, isEmpty);

  return code;
}

/// The generated code of [source], which builds without errors.
Future<String> _generate(
  String source, {
  Map<String, String> libraries = const {},
}) async {
  final result = await _build(source, libraries: libraries);

  expect(result.errors, isEmpty);

  return result.readerWriter.testing.readString(
    .parse('app|lib/screen.tandem.g.part'),
  );
}

/// Builds `screen.dart` with [source], which may start with imports of
/// [libraries], the other files of the app.
Future<TestBuilderResult> _build(
  String source, {
  Map<String, String> libraries = const {},
  void Function(String message)? onLog,
}) => testBuilder(
  tandemBuilder(BuilderOptions.empty),
  {
    'tandem|lib/tandem.dart': '''
import 'package:json_annotation/json_annotation.dart';

final class const TandemAgent({
  final List<JsonConverter<Object?, Object?>> converters = const [],
});

final class const TandemCatalog(
  final List<Type> components, {
  final List<JsonConverter<Object?, Object?>> converters = const [],
});

sealed class AgentCapability {
  factory AgentCapability.sees(Object? value) => throw UnimplementedError();
  factory AgentCapability.seesAs(String name, Object? value) =>
      throw UnimplementedError();
  factory AgentCapability.calls(Function method) => throw UnimplementedError();
}

abstract interface class AgentSurface { Object get agentSchema; }
abstract interface class ToolName { String get value; }
final class AgentSchema({Object? sees, Object? calls, Object? capabilities});
final class AgentTool(Function method, {required ToolName name,
    Object? description, Object? parameters, Object? invoke});
''',
    'flutter|lib/widgets.dart': '''
export 'src/painting/alignment.dart';

abstract class Widget { const Widget(); }
abstract class StatelessWidget extends Widget { const StatelessWidget(); }
typedef VoidCallback = void Function();
typedef ValueChanged<T> = void Function(T value);
''',
    'flutter|lib/src/painting/alignment.dart': '''
abstract class const AlignmentGeometry();

class const Alignment(final double x, final double y) extends AlignmentGeometry {
  static const topLeft = Alignment(-1, -1);
  static const center = Alignment(0, 0);
}
''',
    'json_annotation|lib/json_annotation.dart': '''
abstract interface class JsonConverter<T, S> {}
''',
    for (final MapEntry(:key, :value) in libraries.entries)
      'app|lib/$key': value,
    'app|lib/screen.dart':
        "import 'package:flutter/widgets.dart';\n"
        "import 'package:json_annotation/json_annotation.dart';\n"
        "import 'package:tandem/tandem.dart';\n"
        '$source\n'
        'class Icon();\n',
  },
  rootPackage: 'app',
  generateFor: {'app|lib/screen.dart'},
  onLog: switch (onLog) {
    final onLog? => (record) => onLog(record.message),
    null => null,
  },
  flattenOutput: true,
);
