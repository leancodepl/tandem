// Written the way leancode_contracts generates DTOs, with their annotations.
// ignore_for_file: unnecessary_type_name_in_constructor, use_primary_constructors

import 'package:json_annotation/json_annotation.dart';

/// How much light a plant wants.
enum LightDTO {
  @JsonValue(1)
  shade,
  @JsonValue(2)
  partShade,
  @JsonValue(3)
  brightIndirect,
  @JsonValue(4)
  fullSun,
}

/// A pot size a plant is sold in.
class PotDTO {
  PotDTO({
    required this.diameterCm,
    required this.liters,
    required this.glazed,
  });

  factory PotDTO.fromJson(Map<String, dynamic> json) => PotDTO(
    diameterCm: json['DiameterCm'] as int,
    liters: (json['Liters'] as num).toDouble(),
    glazed: json['Glazed'] as bool,
  );

  @JsonKey(name: 'DiameterCm')
  final int diameterCm;

  @JsonKey(name: 'Liters')
  final double liters;

  @JsonKey(name: 'Glazed')
  final bool glazed;

  Map<String, dynamic> toJson() => {
    'DiameterCm': diameterCm,
    'Liters': liters,
    'Glazed': glazed,
  };
}

/// A plant of the nursery's stock, as the backend sends it.
class PlantDTO {
  PlantDTO({
    required this.sku,
    required this.label,
    required this.light,
    required this.sizes,
    required this.pottedOn,
    required this.careSheet,
  });

  final String sku;
  final String label;
  final LightDTO light;
  final List<PotDTO> sizes;

  /// The day it went into its first pot.
  final DateTime pottedOn;

  /// A page to print on how to keep it.
  final Uri careSheet;

  Map<String, dynamic> toJson() => {'Sku': sku};
}

/// One page of results.
class Page<T> {
  Page({required this.items, required this.number});

  final List<T> items;

  /// Which page this is, from 1.
  final int number;
}

/// The stock keeping unit of a plant.
extension type const Sku(String value);
