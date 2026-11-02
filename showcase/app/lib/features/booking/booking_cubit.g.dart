// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'booking_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$BookingCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as BookingCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.draft).as(
          'draft',
          'The hotel booking as the traveller sees it in the form.',
          .object(
            id: 'package:waypoint/features/booking/booking_draft.dart#BookingDraft',
            description: 'A hotel booking as read from its confirmation, before it joins the trip.',
            fields: (field) => [
              field(
                'hotel',
                (value) => value.hotel,
                required: false,
              ).as(.nullable(.string)),
              field(
                'address',
                (value) => value.address,
                required: false,
              ).as(.nullable(.string)),
              field(
                'checkIn',
                (value) => value.checkIn,
                required: false,
              ).as(.nullable(.dateTime)),
              field(
                'checkOut',
                (value) => value.checkOut,
                required: false,
              ).as(.nullable(.dateTime)),
              field(
                'totalPrice',
                (value) => value.totalPrice,
                required: false,
              ).as(.nullable(.integer)),
              field(
                'confirmation',
                (value) => value.confirmation,
                required: false,
              ).as(.nullable(.string)),
            ],
            build: (values) => .new(
              hotel: values('hotel'),
              address: values('address'),
              checkIn: values('checkIn'),
              checkOut: values('checkOut'),
              totalPrice: values('totalPrice'),
              confirmation: values('confirmation'),
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.setHotel,
          name: 'set_hotel',
          description: "Sets the hotel's name.",
          parameters: [const AgentParameter<String>('name', .string)],
          invoke: (args) {
            surface.setHotel(args.read('name'));
            return null;
          },
        ),
        AgentTool(
          surface.setAddress,
          name: 'set_address',
          description: "Sets the hotel's street address with its city.",
          parameters: [const AgentParameter<String>('address', .string)],
          invoke: (args) {
            surface.setAddress(args.read('address'));
            return null;
          },
        ),
        AgentTool(
          surface.setCheckIn,
          name: 'set_check_in',
          description: 'Sets the day and the earliest time of the check-in.',
          parameters: [const AgentParameter<DateTime>('at', .dateTime)],
          invoke: (args) {
            surface.setCheckIn(args.read('at'));
            return null;
          },
        ),
        AgentTool(
          surface.setCheckOut,
          name: 'set_check_out',
          description: 'Sets the day of the check-out.',
          parameters: [const AgentParameter<DateTime>('day', .dateTime)],
          invoke: (args) {
            surface.setCheckOut(args.read('day'));
            return null;
          },
        ),
        AgentTool(
          surface.setTotalPrice,
          name: 'set_total_price',
          description: 'Sets what the whole stay costs, in whole euros.',
          parameters: [const AgentParameter<int>('euros', .integer)],
          invoke: (args) {
            surface.setTotalPrice(args.read('euros'));
            return null;
          },
        ),
        AgentTool(
          surface.setConfirmation,
          name: 'set_confirmation',
          description: "Sets the hotel's confirmation number.",
          parameters: [const AgentParameter<String>('number', .string)],
          invoke: (args) {
            surface.setConfirmation(args.read('number'));
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on BookingCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('draft', draft),
    if (!state.adding) ...[
      .calls(setHotel),
      .calls(setAddress),
      .calls(setCheckIn),
      .calls(setCheckOut),
      .calls(setTotalPrice),
      .calls(setConfirmation),
    ],
  ];
}
