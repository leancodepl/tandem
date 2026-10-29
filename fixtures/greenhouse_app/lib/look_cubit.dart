import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:greenhouse_app/icons.dart';
import 'package:kit_ds/kit_ds.dart';
import 'package:tandem/tandem.dart';

part 'look_cubit.g.dart';

@TandemAgent(converters: [...Kit.converters, IconNameConverter()])
final class LookCubit() with _$LookCubit {
  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(accent),
    .calls(setPadding),
    .calls(setIcon),
    .calls(setInk),
  ];

  @override
  Stream<Object?> get changes => const Stream.empty();

  /// The accent color of the screen.
  Color get accent => const Color(0x802E7D32);

  EdgeInsetsDirectional padding = .zero;
  IconData? icon;
  KitInk? ink;

  /// Sets the padding of the plant's label.
  void setPadding(EdgeInsetsDirectional padding) => this.padding = padding;

  /// Sets the icon of the plant's label.
  void setIcon(IconData icon) => this.icon = icon;

  /// Sets the ink of the plant's label.
  void setInk(KitInk ink) => this.ink = ink;
}
