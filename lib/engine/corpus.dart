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
    this.typeId = 4,
    this.sourceLine,
  });

  final String id;
  final int seq;
  final String gurmukhi;
  final String normalized;
  final int page;

  /// Corpus line type (`line_types`): 1 Manglacharan, 2 Sirlekh, 3 Rahao,
  /// 4 Pankti (the default - synthetic lines behave like plain verse lines).
  final int typeId;

  /// Physical line on the ang (`lines.source_line`); null where the corpus has
  /// none (Dasam Granth, synthetic lines).
  final int? sourceLine;

  /// A non-sung header line (Sirlekh title / ascription, or a Manglacharan) -
  /// what the intelligent spacebar skips over.
  bool get isHeader => typeId == 1 || typeId == 2;

  /// The pause line (asthaai) carrying the ਰਹਾਉ marker.
  bool get isRahao => gurmukhi.contains('ਰਹਾਉ');

  @override
  List<Object?> get props => [
    id,
    seq,
    gurmukhi,
    normalized,
    page,
    typeId,
    sourceLine,
  ];
}
