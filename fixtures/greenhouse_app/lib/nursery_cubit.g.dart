// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nursery_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$NurseryCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as NurseryCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.plants).as(
          'plants',
          'The plants of the nursery, by label.',
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
        AgentView.of(() => surface.trays).as(
          'trays',
          'The trays of seedlings on the benches.',
          .list(
            .object(
              id: 'package:greenhouse_app/nursery_cubit.dart#Tray',
              description:
                  'A tray of seedlings, whose count the app changes in place.',
              fields: (field) => [
                field('seedlings', (value) => value.seedlings).as(.integer),
              ],
              build: (values) => .new(seedlings: values('seedlings')),
            ),
          ),
        ),
        AgentView.of(() => surface.growers).as(
          'growers',
          'The growers of the nursery.',
          .list(
            .converted(
              _$NurseryCubitConverters[0],
              .string,
              id: 'package:greenhouse_app/nursery_cubit.dart#Grower',
              converterId:
                  'package:greenhouse_app/nursery_cubit.dart#GrowerConverter()',
              object: true,
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.openPlant,
          name: NurseryCubitTool.openPlant,
          description: 'Opens the page of [plant].',
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
            surface.openPlant(args.read('plant'));
            return null;
          },
        ),
        AgentTool(
          surface.comparePlants,
          name: NurseryCubitTool.comparePlants,
          description: 'Shows [plants] side by side.',
          parameters: [
            AgentParameter<List<PlantDTO>>(
              'plants',
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
          ],
          invoke: (args) {
            surface.comparePlants(args.read('plants'));
            return null;
          },
        ),
        AgentTool(
          surface.reversePlants,
          name: NurseryCubitTool.reversePlants,
          description: 'Lists the plants in reverse.',
          parameters: [],
          invoke: (args) {
            surface.reversePlants();
            return null;
          },
        ),
        AgentTool(
          surface.keepFirst,
          name: NurseryCubitTool.keepFirst,
          description: 'Keeps only the first plant.',
          parameters: [],
          invoke: (args) {
            surface.keepFirst();
            return null;
          },
        ),
        AgentTool(
          surface.discardTray,
          name: NurseryCubitTool.discardTray,
          description: 'Throws [tray] away.',
          parameters: [
            AgentParameter<Tray>(
              'tray',
              .object(
                id: 'package:greenhouse_app/nursery_cubit.dart#Tray',
                description: 'A tray of seedlings, whose count the app changes in place.',
                fields: (field) => [
                  field('seedlings', (value) => value.seedlings).as(.integer),
                ],
                build: (values) => .new(seedlings: values('seedlings')),
              ),
            ),
          ],
          invoke: (args) {
            surface.discardTray(args.read('tray'));
            return null;
          },
        ),
        AgentTool(
          surface.assignGrower,
          name: NurseryCubitTool.assignGrower,
          description: 'Puts [grower] in charge of the greenhouse.',
          parameters: [
            AgentParameter<Grower>(
              'grower',
              .converted(
                _$NurseryCubitConverters[0],
                .string,
                id: 'package:greenhouse_app/nursery_cubit.dart#Grower',
                converterId: 'package:greenhouse_app/nursery_cubit.dart#GrowerConverter()',
                object: true,
              ),
            ),
          ],
          invoke: (args) {
            surface.assignGrower(args.read('grower'));
            return null;
          },
        ),
        AgentTool(
          surface.addGrower,
          name: NurseryCubitTool.addGrower,
          description: 'Adds [grower], whom the nursery does not list yet.',
          parameters: [
            AgentParameter<Grower>(
              'grower',
              .converted(
                _$NurseryCubitConverters[0],
                .string,
                id: 'package:greenhouse_app/nursery_cubit.dart#Grower',
                converterId: 'package:greenhouse_app/nursery_cubit.dart#GrowerConverter()',
                object: true,
              ),
              input: true,
            ),
          ],
          invoke: (args) {
            surface.addGrower(args.read('grower'));
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

/// The names the agent knows the methods of [NurseryCubit] by.
// `enum NurseryCubitTool()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum NurseryCubitTool implements ToolName {
  openPlant,
  comparePlants,
  reversePlants,
  keepFirst,
  discardTray,
  assignGrower,
  addGrower;

  @override
  String get value => switch (this) {
    openPlant => 'open_plant',
    comparePlants => 'compare_plants',
    reversePlants => 'reverse_plants',
    keepFirst => 'keep_first',
    discardTray => 'discard_tray',
    assignGrower => 'assign_grower',
    addGrower => 'add_grower',
  };

  @override
  String toString() => value;
}

extension on NurseryCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('plants', plants),
    .seesAs('trays', trays),
    .seesAs('growers', growers),
    .calls(openPlant),
    .calls(comparePlants),
    .calls(reversePlants),
    .calls(keepFirst),
    .callsWithApproval(discardTray),
    .callsWithApproval(assignGrower),
    .calls(addGrower),
  ];
}

const List<Object> _$NurseryCubitConverters = [GrowerConverter()];
