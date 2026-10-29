// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$StockCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as StockCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.plants).as(
          'plants',
          'The plants in stock, by label.',
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
        AgentView.of(() => surface.page).as(
          'page',
          'The first page of the stock.',
          .object(
            id: 'package:greenhouse_app/contracts.dart#Page<package:greenhouse_app/contracts.dart#PlantDTO>',
            description: 'One page of results.',
            fields: (field) => [
              field('items', (value) => value.items).as(
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
        AgentView.of(() => surface.titleStyle).as(
          'title_style',
          "The style of the screen's title.",
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
      ],
      calls: [
        AgentTool(
          surface.restock,
          name: 'restock',
          description: 'Orders [count] more pots of [sku] from the grower.',
          parameters: [
            AgentParameter<Sku>(
              'sku',
              .extension(
                .string,
                (value) => .new(value),
                id: 'package:greenhouse_app/contracts.dart#Sku',
              ),
            ),
            const AgentParameter<int>('count', .integer),
          ],
          invoke: (args) {
            surface.restock(args.read('sku'), args.read('count'));
            return null;
          },
        ),
        AgentTool(
          surface.group,
          name: 'group',
          description: 'Files the stock under [names] and sets it out on [benches], null for the floor.',
          parameters: [
            AgentParameter<Set<String>>('names', .set(.string)),
            AgentParameter<List<int?>>('benches', .list(.nullable(.integer))),
          ],
          invoke: (args) {
            surface.group(args.read('names'), args.read('benches'));
            return null;
          },
        ),
      ],
    );
  }
}
