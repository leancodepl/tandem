import 'package:a2ui_core/a2ui_core.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The A2UI version that Tandem's catalog speaks.
const a2uiVersion = 'v0.9.1';

/// The id of Tandem's catalog, which `createSurface` names.
const tandemCatalogId =
    'https://pub.dev/packages/tandem/a2ui/v0_9_1/catalog.json';

/// The one function a view may call: `formatString`, which puts screen data
/// into a text.
const formatString = 'formatString';

/// The components an agent draws with. None writes data: a button calls a
/// method of the screen.
enum CatalogComponent(
  /// The component's name in A2UI messages.
  final String wireName,
) {
  text('Text'),
  column('Column'),
  row('Row'),
  list('List'),
  card('Card'),
  divider('Divider'),
  button('Button');

  /// The component named [wireName], or null for one outside the catalog.
  static CatalogComponent? named(String wireName) =>
      values.where((component) => component.wireName == wireName).firstOrNull;

  JsonObject get _schema {
    final (:properties, :required) = _definition;
    return {
      'type': 'object',
      'not': {
        'required': [A2uiFields.accessibility],
      },
      'allOf': [
        {r'$ref': '$_common/ComponentCommon'},
        {
          'type': 'object',
          'properties': {
            A2uiFields.component: {'const': wireName},
            ...properties,
          },
          'required': [A2uiFields.component, ...required],
        },
      ],
      'unevaluatedProperties': false,
    };
  }

  ({JsonObject properties, List<String> required}) get _definition =>
      switch (this) {
        text => (
          properties: {
            A2uiFields.text: {r'$ref': '$_common/DynamicString'},
            A2uiFields.variant: _enum([
              for (final variant in TextVariant.values) variant.name,
            ]),
          },
          required: [A2uiFields.text],
        ),
        column || row || list => (
          properties: {
            A2uiFields.children: {r'$ref': '$_common/ChildList'},
          },
          required: [A2uiFields.children],
        ),
        card => (properties: _child, required: [A2uiFields.child]),
        divider => (properties: {}, required: []),
        button => (
          properties: {
            ..._child,
            A2uiFields.variant: _enum([
              for (final variant in ButtonVariant.values) variant.wireName,
            ]),
            A2uiFields.action: {r'$ref': '$_common/Action'},
          },
          required: [A2uiFields.child, A2uiFields.action],
        ),
      };
}

/// How a Text looks, by its `variant`, named as in A2UI.
enum TextVariant() {
  h1,
  h2,
  h3,
  h4,
  h5,
  caption,
  body;

  /// The variant named [wireName], or [body].
  static TextVariant named(Object? wireName) =>
      values.asNameMap()[wireName] ?? body;
}

/// How a Button looks, by its `variant`.
enum ButtonVariant(final String wireName) {
  outlined('default'),
  primary('primary'),
  borderless('borderless');

  /// The variant named [wireName], or the default one.
  static ButtonVariant named(Object? wireName) =>
      values.where((variant) => variant.wireName == wireName).firstOrNull ??
      outlined;
}

/// A processor that takes only `createSurface` and `updateComponents` of
/// Tandem's catalog, and checks them strictly.
MessageProcessor<ComponentApi> tandemProcessor() => MessageProcessor(
  catalogs: [_catalog],
  defaultVersion: .v0_9_1,
  validationConfig: const ValidationConfig(
    targetVersion: .v0_9_1,
    allowedMessages: [A2uiFields.createSurface, A2uiFields.updateComponents],
  ),
);

final _catalog = Catalog.fromJson({
  r'$schema': Catalog.jsonSchemaDialect,
  A2uiFields.catalogId: tandemCatalogId,
  'protocolVersion': a2uiVersion,
  A2uiFields.components: {
    for (final component in CatalogComponent.values)
      component.wireName: component._schema,
  },
}).withFunctions([FormatStringFunction()]);

const _common = r'https://a2ui.org/specification/v0_9/common_types.json#/$defs';

const _child = {
  A2uiFields.child: {r'$ref': '$_common/ComponentId'},
};

JsonObject _enum(List<String> values) => {'type': 'string', 'enum': values};
