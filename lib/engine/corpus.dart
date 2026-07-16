import 'package:equatable/equatable.dart';

/// One line (tuk) of the corpus. [seq] is its global `order_id`, not an index
/// into whatever slice it arrived in - a sliding window must never renumber a
/// line, or forward/backward comparisons across windows break.
class Verse extends Equatable {
  const Verse({
    required this.id,
    required this.seq,
    required this.gurmukhi,
    required this.normalized,
    required this.page,
  });

  final String id;
  final int seq;
  final String gurmukhi;
  final String normalized;
  final int page;

  @override
  List<Object?> get props => [id, seq, gurmukhi, normalized, page];
}
