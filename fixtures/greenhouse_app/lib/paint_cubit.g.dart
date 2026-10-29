// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paint_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$PaintCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as PaintCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.brand).as(
          'brand',
          'The brand color of the greenhouse.',
          .converted(
            _$PaintCubitConverters[0],
            .integer,
            id: 'dart:ui#Color',
            converterId: 'package:greenhouse_app/paint_cubit.dart#ColorNumberConverter()',
            description:
                "A color as an ARGB number, as this app's backend writes it.",
          ),
        ),
      ],
      calls: const [],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on PaintCubit {
  List<AgentCapability> get _$agentCapabilities => [.seesAs('brand', brand)];
}

const List<Object> _$PaintCubitConverters = [ColorNumberConverter()];
