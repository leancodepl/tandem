import 'package:example/desk/catalog.dart';

const products = <Product>[
  .new(
    sku: 'VC-HDMI-2M',
    name: 'HDMI 2.1 cable, 2 m',
    description: 'Braided cable for 8K video',
    price: 29,
  ),
  .new(
    sku: 'VM-27Q',
    name: 'Voltra ProView 27Q, 27" QHD monitor',
    description: '27-inch QHD monitor, 2560 x 1440, IPS',
    price: 1249,
  ),
  .new(
    sku: 'VM-27U',
    name: 'Voltra ProView 27U, 27" 4K monitor',
    description: '27-inch 4K monitor, 3840 x 2160, IPS',
    price: 1699,
  ),
  .new(
    sku: 'VD-USBC',
    name: 'USB-C docking station',
    description: 'Two HDMI ports, gigabit Ethernet, 90 W charging',
    price: 549,
  ),
];
