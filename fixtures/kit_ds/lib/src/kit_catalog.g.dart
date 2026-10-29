// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kit_catalog.dart';

// **************************************************************************
// CatalogGenerator
// **************************************************************************

mixin _$KitCatalog implements AgentCatalog {
  @override
  String get guidelines =>
      'Draw a stack of a heading, a chip that says what is in stock, and a button for the action the user asked for.';

  @override
  List<Map<String, Object?>> get example => const [
    {
      'id': 'root',
      'component': 'KitStack',
      'children': ['title', 'stock'],
    },
    {
      'id': 'title',
      'component': 'KitText',
      'style': 'heading',
      'value': 'Greenhouse',
    },
    {
      'id': 'stock',
      'component': 'KitChip',
      'fill': '#2E7D32',
      'text': 'In stock',
    },
  ];

  @override
  List<AgentComponent> get components => [
    AgentComponent<KitText>.of(
      name: 'KitText',
      description: "A run of text in one of the kit's styles.",
      properties: (property) => [
        property('style', (widget) => widget.style).value(
          .token(
            {
              'banner': .banner,
              'heading': .heading,
              'plain': .plain,
              'fine': .fine,
            },
            id: 'package:kit_ds/src/kit_style.dart#KitStyle',
            description: 'A text style of the kit, named for where it goes.',
          ),
        ),
        property('value', (widget) => widget.value).value(.string),
        property('align', (widget) => widget.align).value(
          .nullable(
            .enumeration([
              .left,
              .right,
              .center,
              .justify,
              .start,
              .end,
            ], id: 'dart:ui#TextAlign'),
          ),
          required: false,
        ),
      ],
      build: (args) => KitText(
        style: args.value('style'),
        value: args.value('value'),
        align: args.value('align'),
      ),
    ),
    AgentComponent<KitNote>.of(
      name: 'KitNote',
      description: 'A remark set apart from the text around it.',
      properties: (property) => [
        property('body', (widget) => widget.body).value(.string),
        property('slant', (widget) => widget.slant).value(
          .enumeration([.normal, .italic], id: 'dart:ui#FontStyle'),
          required: false,
        ),
      ],
      build: (args) =>
          KitNote(args.value('body'), slant: args.valueOr('slant', .italic)),
    ),
    AgentComponent<KitStack>.of(
      name: 'KitStack',
      description:
          'Items one below another, the first [limit] of them when it is set.',
      properties: (property) => [
        property(
          'limit',
          (widget) => widget.limit,
        ).value(.nullable(.integer), required: false),
        property(
          'divided',
          (widget) => widget.divided,
        ).value(.boolean, required: false),
        property.children('children'),
      ],
      build: (args) => KitStack(
        limit: args.value('limit'),
        divided: args.valueOr('divided', false),
        children: args.children('children'),
      ),
    ),
    AgentComponent<KitButton>.of(
      name: 'KitButton',
      description: 'A label to tap.',
      properties: (property) => [
        property('label', (widget) => widget.label).value(.string),
        property.press('onPressed', required: false),
      ],
      build: (args) => KitButton(
        label: args.value('label'),
        onPressed: args.pressOrNull('onPressed'),
      ),
    ),
    AgentComponent<KitChip>.of(
      name: 'KitChip',
      description: 'A word or two on a colored fill, such as "In stock".',
      properties: (property) => [
        property('fill', (widget) => widget.fill).value(.color),
        property('text', (widget) => widget.text).value(.string),
      ],
      build: (args) =>
          KitChip(fill: args.value('fill'), text: args.value('text')),
    ),
  ];
}
