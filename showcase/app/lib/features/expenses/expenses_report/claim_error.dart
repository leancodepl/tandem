import 'package:equatable/equatable.dart';
import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// Why a claim of the expense report is wrong.
sealed class const ClaimError() with Equatable {
  /// The error in English, for the agent.
  String get forAgent;
}

/// The claim is not a whole number of euros between 1 and the [paid]
/// amount of its receipt.
final class const ClaimOutOfRange(final Money paid) extends ClaimError {
  @override
  List<Object?> get props => [paid];

  @override
  String get forAgent => 'Claim between €1 and the €${paid.toInt()} paid';
}

/// The claim breaks the company's policy.
final class const ClaimOverPolicy(final PolicyBreach breach)
    extends ClaimError {
  @override
  List<Object?> get props => [breach];

  @override
  String get forAgent => breach.forAgent;
}
