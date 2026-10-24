import 'package:a2ui_core/a2ui_core.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The id of Tandem's catalog in `createSurface`.
const tandemCatalogId =
    'https://pub.dev/packages/tandem/a2ui/v0_9_1/catalog.json';

const _common = r'https://a2ui.org/specification/v0_9/common_types.json#/$defs';

/// The components an agent may draw with. None writes the data model: a
/// button calls a method of the screen through its `action`.
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
        'enum': TextVariant.values,
        'default': TextVariant.body,
      },
    },
    required: [A2uiFields.text],
  ),
  column('Column', _childList, required: [A2uiFields.children]),
  row('Row', _childList, required: [A2uiFields.children]),
  list('List', _childList, required: [A2uiFields.children]),
  card(
    'Card',
    {
      A2uiFields.child: {r'$ref': '$_common/ComponentId'},
    },
    required: [A2uiFields.child],
  ),
  divider('Divider', {}),
  button(
    'Button',
    {
      A2uiFields.child: {r'$ref': '$_common/ComponentId'},
      A2uiFields.variant: {
        'type': 'string',
        'enum': ButtonVariant.values,
        'default': ButtonVariant.outlined,
      },
      A2uiFields.action: {r'$ref': '$_common/Action'},
    },
    required: [A2uiFields.child, A2uiFields.action],
  );

  /// The component of [wireName], null for one outside the catalog.
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

/// How a Text looks.
extension type const TextVariant._(String _name) implements String {
  static const h1 = TextVariant._('h1');
  static const h2 = TextVariant._('h2');
  static const h3 = TextVariant._('h3');
  static const caption = TextVariant._('caption');
  static const body = TextVariant._('body');

  static const values = [h1, h2, h3, caption, body];
}

/// How a Button looks.
extension type const ButtonVariant._(String _name) implements String {
  static const outlined = ButtonVariant._('default');
  static const primary = ButtonVariant._('primary');
  static const borderless = ButtonVariant._('borderless');

  static const values = [outlined, primary, borderless];
}

const _childList = {
  A2uiFields.children: {r'$ref': '$_common/ChildList'},
};

/// The one function an agent may call: interpolating screen data into text.
const formatString = 'formatString';

/// The catalog a processor checks and draws messages with: the components
/// of [CatalogComponent] and `formatString` of the basic catalog.
Catalog<ComponentApi, FunctionImplementation> tandemCatalog() {
  final basic = BasicCatalog.v0_9();
  final implementation = basic.functions[formatString];
  if (implementation == null) {
    throw StateError('The basic catalog of a2ui_core has no $formatString.');
  }
  return Catalog.fromJson(_document)
      .withFunctions(<FunctionImplementation>[implementation]);
}

JsonObject get _document => {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  r'$id': tandemCatalogId,
  A2uiFields.catalogId: tandemCatalogId,
  A2uiFields.protocolVersion: a2uiVersion.replaceFirst('v', ''),
  'title': 'Tandem catalog',
  A2uiFields.components: {
    for (final component in CatalogComponent.values)
      component.wireName: component._schema,
  },
  A2uiFields.functions: {
    formatString: {
      'type': 'object',
      'description':
          r'Interpolates `${/absolute/path}` or `${relative/path}` into text.',
      'properties': {
        A2uiFields.call: {'const': formatString},
        A2uiFields.args: {
          'type': 'object',
          'properties': {
            A2uiFields.value: {r'$ref': '$_common/DynamicString'},
          },
          'required': [A2uiFields.value],
          'unevaluatedProperties': false,
        },
        A2uiFields.returnType: {'const': 'string'},
      },
      'required': [A2uiFields.call, A2uiFields.args],
      'unevaluatedProperties': false,
    },
  },
};

/// A processor that takes only A2UI v0.9.1 with Tandem's catalog, fully
/// checked. [onAction] gets every press of a button.
MessageProcessor<ComponentApi> tandemProcessor({
  void Function(A2uiRendererAction action)? onAction,
}) => MessageProcessor(
  catalogs: [tandemCatalog()],
  defaultVersion: .v0_9_1,
  validationConfig: const ValidationConfig(
    targetVersion: .v0_9_1,
    allowedMessages: allowedA2uiMessages,
  ),
  onAction: onAction,
);
