/// What book_changes booked.
final class const Booked({
  required final String confirmation,

  /// Each booking that changed, as the screen shows it now.
  required final List<String> changes,

  /// Charged to the company card, in euros.
  required final int charged,
});
