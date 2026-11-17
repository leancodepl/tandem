import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/tandem/form_changes.dart';
import 'package:waypoint/features/booking/booking_draft.dart';
import 'package:waypoint/features/booking/booking_error.dart';
import 'package:waypoint/features/booking/booking_form_controller.dart';
import 'package:waypoint/features/booking/booking_presentation_event.dart';
import 'package:waypoint/features/booking/booking_state.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'booking_cubit.g.dart';

final _log = Logger('Booking');

/// The booking form that a pasted confirmation e-mail fills in. Nothing
/// here needs approval: the traveller adds the booking with their own tap.
@TandemAgent()
class BookingCubit({@override required final BookingFormController form})
    extends Cubit<BookingState>
    with
        _$BookingCubit,
        BlocPresentationMixin<BookingState, BookingPresentationEvent>,
        FormChanges<BookingState> {
  this : super(BookingState());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(draft),
    if (!state.adding) ...[
      .calls(setHotel),
      .calls(setAddress),
      .calls(setCheckIn),
      .calls(setCheckOut),
      .calls(setTotalPrice),
      .calls(setConfirmation),
    ],
  ];

  /// The hotel booking as the traveller sees it in the form.
  BookingDraft get draft => form.draft;

  /// Sets the hotel's name.
  void setHotel(String name) {
    form.hotel.setValue(name);
    _mark(.hotel);
  }

  /// Sets the hotel's street address with its city.
  void setAddress(String address) {
    form.address.setValue(address);
    _mark(.address);
  }

  /// Sets the day and the earliest time of the check-in.
  void setCheckIn(DateTime at) {
    _refuseIf(form.checkInError(at));
    form.checkIn.setValue(at);
    _mark(.checkIn);
  }

  /// Sets the day of the check-out.
  void setCheckOut(DateTime day) {
    _refuseIf(form.checkOutError(day));
    form.checkOut.setValue(day);
    _mark(.checkOut);
  }

  /// Sets what the whole stay costs, in whole euros.
  void setTotalPrice(int euros) {
    _refuseIf(form.totalPriceError('$euros'));
    form.totalPrice.setValue('$euros');
    _mark(.price);
  }

  /// Sets the hotel's confirmation number.
  void setConfirmation(String number) {
    final reference = BookingReference.tryParse(number);
    if (reference == null) {
      _refuse('The confirmation number must not be empty.');
    }
    form.confirmation.setValue(reference.value);
    _mark(.confirmation);
  }

  /// Whether the traveller can add the stay: every field filled in, none
  /// wrong, and not being added already.
  bool get ready =>
      form.missing.isEmpty && form.value.canSubmit && !state.adding;

  /// Adds the stay to the trip, once the form checks out.
  Future<void> add() async {
    final stay = form.stay;
    if (!ready || stay == null) return;

    emit(state.copyWith(adding: true));
    form.markReadOnly();
    final validated = await form.validate();
    if (isClosed || form.isDisposed) return;
    if (validated && form.value.canSubmit && form.missing.isEmpty) {
      emitPresentation(BookingPresentationEventAdded(stay));
    } else {
      emit(state.copyWith(adding: false));
      form.unmarkReadOnly();
    }
  }

  /// The traveller changed [part] by hand.
  void unmark(BookingPart part) =>
      emit(state.copyWith(marked: {...state.marked}..remove(part)));

  /// Empties the form, for another e-mail to fill it.
  void clear() {
    form.resetAll();
    emit(state.copyWith(marked: const {}));
  }

  void _mark(BookingPart part) =>
      emit(state.copyWith(marked: {...state.marked, part}));

  void _refuseIf(BookingError? error) {
    if (error != null) _refuse('${error.forAgent}.');
  }

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}
