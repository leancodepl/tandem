// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'look_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$LookCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as LookCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.accent)
            .as('accent', 'The accent color of the screen.', .color),
      ],
      calls: [
        AgentTool(
          surface.setPadding,
          name: LookCubitTool.setPadding,
          description: "Sets the padding of the plant's label.",
          parameters: [
            const AgentParameter<EdgeInsetsDirectional>(
              'padding',
              .edgeInsetsDirectional,
            ),
          ],
          invoke: (args) {
            surface.setPadding(args.read('padding'));
            return null;
          },
        ),
        AgentTool(
          surface.setIcon,
          name: LookCubitTool.setIcon,
          description: "Sets the icon of the plant's label.",
          parameters: [
            AgentParameter<IconData>(
              'icon',
              .converted(
                _$LookCubitConverters[1],
                .string,
                id: 'package:flutter/src/widgets/icon_data.dart#IconData',
                converterId:
                    'package:greenhouse_app/icons.dart#IconNameConverter()',
                description: 'An icon by name: leaf, drop or sun.',
              ),
            ),
          ],
          invoke: (args) {
            surface.setIcon(args.read('icon'));
            return null;
          },
        ),
        AgentTool(
          surface.setInk,
          name: LookCubitTool.setInk,
          description: "Sets the ink of the plant's label.",
          parameters: [
            AgentParameter<KitInk>(
              'ink',
              .converted(
                _$LookCubitConverters[0],
                .typed<InkName>(
                  .enumeration(
                    [.ocean, .ember, .slate],
                    id: 'package:kit_ds/src/kit_ink.dart#InkName',
                    description: "The names of the kit's inks.",
                  ),
                ),
                id: 'package:kit_ds/src/kit_ink.dart#KitInk',
                converterId: 'package:kit_ds/src/kit_ink.dart#InkConverter()',
                description: 'An ink by its name.',
              ),
            ),
          ],
          invoke: (args) {
            surface.setInk(args.read('ink'));
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

/// The names the agent knows the methods of [LookCubit] by.
// `enum LookCubitTool()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum LookCubitTool implements ToolName {
  setPadding,
  setIcon,
  setInk;

  @override
  String get value => switch (this) {
    setPadding => 'set_padding',
    setIcon => 'set_icon',
    setInk => 'set_ink',
  };

  @override
  String toString() => value;
}

extension on LookCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('accent', accent),
    .calls(setPadding),
    .calls(setIcon),
    .calls(setInk),
  ];
}

const List<Object> _$LookCubitConverters = [
  ...Kit.converters,
  IconNameConverter(),
];
