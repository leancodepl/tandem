// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'greenhouse_catalog.dart';

// **************************************************************************
// CatalogGenerator
// **************************************************************************

mixin _$GreenhouseCatalog implements AgentCatalog {
  @override
  String get guidelines =>
      'Start with a KitStack. Show each plant of /plants as a PlantRow whose onPick picks it, and the pots the user wants as a PotMeter below them.';

  @override
  List<Map<String, Object?>> get example => const [
    {
      'id': 'root',
      'component': 'KitStack',
      'children': ['title', 'rows', 'pots'],
    },
    {
      'id': 'title',
      'component': 'KitText',
      'style': 'heading',
      'value': 'Greenhouse',
    },
    {
      'id': 'rows',
      'component': 'KitStack',
      'children': {'componentId': 'row', 'path': '/plants'},
    },
    {
      'id': 'row',
      'component': 'PlantRow',
      'plant': {'path': ''},
      'onPick': {
        'action': {
          'event': {
            'name': 'pick',
            'context': {
              'plant': {'path': ''},
            },
          },
        },
      },
    },
    {
      'id': 'pots',
      'component': 'PotMeter',
      'pots': {'path': '/wanted'},
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
    AgentComponent<PlantRow>.of(
      name: 'PlantRow',
      description:
          'A plant by its label and the light it wants. A tap picks it.',
      properties: (property) => [
        property.press('onPick'),
        property('plant', (widget) => widget.plant).value(
          .object(
            id: 'package:greenhouse_app/contracts.dart#PlantDTO',
            description:
                "A plant of the nursery's stock, as the backend sends it.",
            fields: (field) => [
              field('sku', (value) => value.sku).as(.string),
              field('label', (value) => value.label).as(.string),
              field('light', (value) => value.light).as(
                .enumeration(
                  [.shade, .partShade, .brightIndirect, .fullSun],
                  id: 'package:greenhouse_app/contracts.dart#LightDTO',
                  description: 'How much light a plant wants.',
                ),
              ),
              field('sizes', (value) => value.sizes).as(
                .list(
                  .object(
                    id: 'package:greenhouse_app/contracts.dart#PotDTO',
                    description: 'A pot size a plant is sold in.',
                    fields: (field) => [
                      field(
                        'diameterCm',
                        (value) => value.diameterCm,
                      ).as(.integer),
                      field('liters', (value) => value.liters).as(.number),
                      field('glazed', (value) => value.glazed).as(.boolean),
                    ],
                    build: (values) => .new(
                      diameterCm: values('diameterCm'),
                      liters: values('liters'),
                      glazed: values('glazed'),
                    ),
                  ),
                ),
              ),
              field(
                'pottedOn',
                (value) => value.pottedOn,
                description: 'The day it went into its first pot.',
              ).as(.dateTime),
              field(
                'careSheet',
                (value) => value.careSheet,
                description: 'A page to print on how to keep it.',
              ).as(.uri),
            ],
            build: (values) => .new(
              sku: values('sku'),
              label: values('label'),
              light: values('light'),
              sizes: values('sizes'),
              pottedOn: values('pottedOn'),
              careSheet: values('careSheet'),
            ),
          ),
        ),
      ],
      build: (args) =>
          PlantRow(onPick: args.press('onPick'), plant: args.value('plant')),
    ),
    AgentComponent<PotMeter>.of(
      name: 'PotMeter',
      description: 'How many pots the user wants, drawn as [gauge] says.',
      properties: (property) => [
        property('pots', (widget) => widget.pots).value(.integer),
        property('gauge', (widget) => widget.gauge).value(
          .enumeration(
            [.dots, .bar, .digits],
            id: 'package:greenhouse_app/plant_widgets.dart#Gauge',
            description: 'How a meter draws its count.',
          ),
          required: false,
        ),
      ],
      build: (args) => PotMeter(
        pots: args.value('pots'),
        gauge: args.valueOr('gauge', .dots),
      ),
    ),
    AgentComponent<UndoBar>.of(
      name: 'UndoBar',
      description: 'A message about what the user just did, with a button that undoes it while the screen can.',
      properties: (property) => [
        property('message', (widget) => widget.message).value(.string),
        property.press('onUndo', required: false),
      ],
      build: (args) => UndoBar(
        message: args.value('message'),
        onUndo: args.pressOrNull('onUndo'),
      ),
    ),
    AgentComponent<PotsField>.of(
      name: 'PotsField',
      description: 'A field for the number of pots.',
      properties: (property) => [
        property('pots', (widget) => widget.pots).value(.integer),
        property
            .field('onPots', (widget) => widget.onPots)
            .as(.integer, required: false),
      ],
      build: (args) => PotsField(
        pots: args.value('pots'),
        onPots: args.fieldOrNull('onPots'),
      ),
    ),
    AgentComponent<SideBySide>.of(
      name: 'SideBySide',
      description: 'The plants side by side, by label.',
      properties: (property) => [
        property('plants', (widget) => widget.plants).value(
          .list(
            .object(
              id: 'package:greenhouse_app/contracts.dart#PlantDTO',
              description:
                  "A plant of the nursery's stock, as the backend sends it.",
              fields: (field) => [
                field('sku', (value) => value.sku).as(.string),
                field('label', (value) => value.label).as(.string),
                field('light', (value) => value.light).as(
                  .enumeration(
                    [.shade, .partShade, .brightIndirect, .fullSun],
                    id: 'package:greenhouse_app/contracts.dart#LightDTO',
                    description: 'How much light a plant wants.',
                  ),
                ),
                field('sizes', (value) => value.sizes).as(
                  .list(
                    .object(
                      id: 'package:greenhouse_app/contracts.dart#PotDTO',
                      description: 'A pot size a plant is sold in.',
                      fields: (field) => [
                        field(
                          'diameterCm',
                          (value) => value.diameterCm,
                        ).as(.integer),
                        field('liters', (value) => value.liters).as(.number),
                        field('glazed', (value) => value.glazed).as(.boolean),
                      ],
                      build: (values) => .new(
                        diameterCm: values('diameterCm'),
                        liters: values('liters'),
                        glazed: values('glazed'),
                      ),
                    ),
                  ),
                ),
                field(
                  'pottedOn',
                  (value) => value.pottedOn,
                  description: 'The day it went into its first pot.',
                ).as(.dateTime),
                field(
                  'careSheet',
                  (value) => value.careSheet,
                  description: 'A page to print on how to keep it.',
                ).as(.uri),
              ],
              build: (values) => .new(
                sku: values('sku'),
                label: values('label'),
                light: values('light'),
                sizes: values('sizes'),
                pottedOn: values('pottedOn'),
                careSheet: values('careSheet'),
              ),
            ),
          ),
        ),
      ],
      build: (args) => SideBySide(plants: args.value('plants')),
    ),
    AgentComponent<PageNumber>.of(
      name: 'PageNumber',
      description: 'Which page of labels this is, on a page whose hidden labels are null.',
      properties: (property) => [
        property('page', (widget) => widget.page).value(
          .object(
            id: 'package:greenhouse_app/contracts.dart#Page<dart:core#String?>',
            description: 'One page of results.',
            fields: (field) => [
              field(
                'items',
                (value) => value.items,
              ).as(.list(.nullable(.string))),
              field(
                'number',
                (value) => value.number,
                description: 'Which page this is, from 1.',
              ).as(.integer),
            ],
            build: (values) =>
                .new(items: values('items'), number: values('number')),
          ),
        ),
      ],
      build: (args) => PageNumber(page: args.value('page')),
    ),
  ];
}
