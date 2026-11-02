import 'package:equatable/equatable.dart';

final class MarksState(Set<String> ids) with Equatable {
  final Set<String> ids = Set.unmodifiable(ids);

  @override
  List<Object?> get props => [ids];
}
