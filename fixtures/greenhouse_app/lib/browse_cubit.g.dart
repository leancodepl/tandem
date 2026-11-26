// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browse_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$BrowseCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as BrowseCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.plants).as(
          'plants',
          'The plants of the greenhouse, by label.',
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
        AgentView.of(() => surface.shelves).as(
          'shelves',
          'The shelves of the shop.',
          .list(
            .object(
              id: 'package:greenhouse_app/browse_cubit.dart#Shelf',
              description: 'A shelf of a shop, with the names of its items.',
              fields: (field) => [
                field('name', (value) => value.name).as(.string),
                field('items', (value) => value.items).as(.list(.string)),
              ],
              build: (values) =>
                  .new(name: values('name'), items: values('items')),
            ),
          ),
        ),
        AgentView.of(() => surface.featured).as(
          'featured',
          'The shelf the shop puts first, null without one.',
          .nullable(
            .object(
              id: 'package:greenhouse_app/browse_cubit.dart#Shelf',
              description: 'A shelf of a shop, with the names of its items.',
              fields: (field) => [
                field('name', (value) => value.name).as(.string),
                field('items', (value) => value.items).as(.list(.string)),
              ],
              build: (values) =>
                  .new(name: values('name'), items: values('items')),
            ),
          ),
        ),
        AgentView.of(() => surface.pairs).as(
          'pairs',
          'The plants two by two, for the user to compare.',
          .list(
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
        ),
        AgentView.of(() => surface.wanted)
            .as('wanted', 'How many pots the user wants.', .integer),
        AgentView.of(() => surface.labels).as(
          'labels',
          'The labels of the plants, on one page.',
          .object(
            id: 'package:greenhouse_app/contracts.dart#Page<dart:core#String>',
            description: 'One page of results.',
            fields: (field) => [
              field('items', (value) => value.items).as(.list(.string)),
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
        AgentView.of(() => surface.note).as(
          'note',
          "The user's note on the plants, null without one.",
          .nullable(.string),
        ),
      ],
      calls: [
        AgentTool(
          surface.pick,
          name: BrowseCubitTool.pick,
          description: 'Picks [plant].',
          parameters: [
            AgentParameter<PlantDTO>(
              'plant',
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
          invoke: (args) {
            surface.pick(args.read('plant'));
            return null;
          },
        ),
        AgentTool(
          surface.putBackPlant,
          name: BrowseCubitTool.putBackPlant,
          description: 'Puts [plant] back on its bench.',
          parameters: [
            AgentParameter<PlantDTO>(
              'plant',
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
          invoke: (args) {
            surface.putBackPlant(args.read('plant'));
            return null;
          },
        ),
        AgentTool(
          surface.setPots,
          name: BrowseCubitTool.setPots,
          description: 'Sets how many pots the user wants.',
          parameters: [const AgentParameter<int>('pots', .integer)],
          invoke: (args) {
            surface.setPots(args.read('pots'));
            return null;
          },
        ),
        AgentTool(
          surface.setNote,
          name: BrowseCubitTool.setNote,
          description: 'Sets the note, or clears it with null.',
          parameters: [
            AgentParameter<String?>(
              'note',
              .nullable(.string),
              required: false,
            ),
          ],
          invoke: (args) {
            surface.setNote(args.read('note'));
            return null;
          },
        ),
        AgentTool(
          surface.keepNote,
          name: BrowseCubitTool.keepNote,
          description: 'Keeps [note].',
          parameters: [const AgentParameter<String>('note', .string)],
          invoke: (args) {
            surface.keepNote(args.read('note'));
            return null;
          },
        ),
        AgentTool(
          surface.attach,
          name: BrowseCubitTool.attach,
          description: 'Attaches [file] to the note.',
          parameters: [
            AgentParameter<Attachment>(
              'file',
              .object(
                id: 'package:greenhouse_app/browse_cubit.dart#Attachment',
                description: 'A file the user attaches to the note.',
                fields: (field) => [
                  field('path', (value) => value.path).as(.string),
                  field('title', (value) => value.title).as(.string),
                ],
                build: (values) =>
                    .new(path: values('path'), title: values('title')),
              ),
              input: true,
            ),
          ],
          invoke: (args) {
            surface.attach(args.read('file'));
            return null;
          },
        ),
        AgentTool(
          surface.compare,
          name: BrowseCubitTool.compare,
          description: 'Compares the plants of each pair of [pairs].',
          parameters: [
            AgentParameter<List<List<PlantDTO>>>(
              'pairs',
              .list(
                .list(
                  .object(
                    id: 'package:greenhouse_app/contracts.dart#PlantDTO',
                    description: "A plant of the nursery's stock, as the backend sends it.",
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
                              field(
                                'liters',
                                (value) => value.liters,
                              ).as(.number),
                              field(
                                'glazed',
                                (value) => value.glazed,
                              ).as(.boolean),
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
            ),
          ],
          invoke: (args) {
            surface.compare(args.read('pairs'));
            return null;
          },
        ),
        AgentTool(
          surface.compost,
          name: BrowseCubitTool.compost,
          description: 'Composts [plant], which cannot be undone.',
          parameters: [
            AgentParameter<PlantDTO>(
              'plant',
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
          invoke: (args) {
            surface.compost(args.read('plant'));
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

/// The names the agent knows the methods of [BrowseCubit] by.
// `enum BrowseCubitTool()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum BrowseCubitTool implements ToolName {
  pick,
  putBackPlant,
  setPots,
  setNote,
  keepNote,
  attach,
  compare,
  compost;

  @override
  String get value => switch (this) {
    pick => 'pick',
    putBackPlant => 'put_back_plant',
    setPots => 'set_pots',
    setNote => 'set_note',
    keepNote => 'keep_note',
    attach => 'attach',
    compare => 'compare',
    compost => 'compost',
  };

  @override
  String toString() => value;
}

extension on BrowseCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('plants', plants),
    .seesAs('shelves', shelves),
    .seesAs('featured', featured),
    .seesAs('pairs', pairs),
    .seesAs('wanted', wanted),
    .seesAs('labels', labels),
    if (showsNote) .seesAs('note', note),
    if (canPick) .calls(pick),
    if (canPutBack) .calls(putBackPlant),
    .calls(setPots),
    .calls(setNote),
    .calls(keepNote),
    .calls(attach),
    .calls(compare),
    .callsWithApproval(compost),
  ];
}
