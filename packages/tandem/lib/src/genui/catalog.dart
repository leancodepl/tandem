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
  final JsonObject _properties, {
  final List<String> required = const [],
}) {
  text(
    'Text',
    {
      A2uiFields.text: {r'$ref': '$_common/DynamicString'},
      A2uiFields.variant: {
        'type': 'string',
        'enum': ['h1', 'h2', 'h3', 'h4', 'h5', 'caption', 'body'],
      },
    },
    required: [A2uiFields.text],
  ),
  column('Column', _children, required: [A2uiFields.children]),
  row('Row', _children, required: [A2uiFields.children]),
  list('List', _children, required: [A2uiFields.children]),
  card('Card', _child, required: [A2uiFields.child]),
  divider('Divider', {}),
  button(
    'Button',
    {
      ..._child,
      A2uiFields.variant: {
        'type': 'string',
        'enum': ['default', 'primary', 'borderless'],
      },
      A2uiFields.action: {r'$ref': '$_common/Action'},
    },
    required: [A2uiFields.child, A2uiFields.action],
  );

  /// The component named [wireName], or null for one outside the catalog.
  static CatalogComponent? named(String wireName) =>
      values.where((component) => component.wireName == wireName).firstOrNull;

  JsonObject get _schema => {
    'type': 'object',
    'allOf': [
      {r'$ref': '$_common/ComponentCommon'},
      {
        'type': 'object',
        'properties': {
          A2uiFields.component: {'const': wireName},
          ..._properties,
        },
        'required': [A2uiFields.component, ...required],
      },
    ],
    'unevaluatedProperties': false,
  };
}

/// A processor that takes only `createSurface` and `updateComponents` of
/// Tandem's catalog, and checks them strictly. [onAction] hears every press
/// of a button.
MessageProcessor<ComponentApi> tandemProcessor({
  void Function(A2uiRendererAction action)? onAction,
}) => MessageProcessor(
  catalogs: [_catalog],
  defaultVersion: .v0_9_1,
  validationConfig: const ValidationConfig(
    targetVersion: .v0_9_1,
    allowedMessages: [A2uiFields.createSurface, A2uiFields.updateComponents],
  ),
  onAction: onAction,
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

const _children = {
  A2uiFields.children: {r'$ref': '$_common/ChildList'},
};
