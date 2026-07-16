import 'package:flutter/material.dart';

/// Plain Gurmukhi with the embedded vishraam marks (`; , .`) stripped and single
/// spaces - for lists and search results, where the raw punctuation shouldn't
/// show. Strips marks *anywhere* in a token (a handful of corpus lines carry a
/// mark mid-word, e.g. `ਸਚ;ੁ`), so none ever leak into the text.
String strippedGurmukhi(String gurmukhi) => gurmukhi
    .split(RegExp(r'\s+'))
    .map((w) => w.replaceAll(RegExp('[;,.]'), ''))
    .where((w) => w.isNotEmpty)
    .join(' ');

/// Builds a Gurmukhi line as spans, handling the vishraam (pause) marks the
/// ShabadOS text embeds as punctuation - `;` heavy, `,` medium, `.` light. The
/// raw marks are always stripped (they aren't meant to be shown); when
/// [vishraam] is on, the word before a pause is coloured instead. [larivaar]
/// runs the words together with no spaces (classic larivaar reading).
///
/// The danda `॥`/`।` and verse numbers ride along as ordinary words.
List<InlineSpan> gurmukhiSpans(
  String gurmukhi, {
  required Color heavy,
  required Color medium,
  bool larivaar = false,
  bool vishraam = true,
}) {
  final separator = larivaar ? '' : ' ';
  final words = gurmukhi
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final out = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    final raw = words[i];
    // The pause weight comes from the trailing mark; `.` is a light pause with
    // no colour. Colour is only applied when vishraam display is on.
    Color? color;
    if (vishraam && raw.endsWith(';')) {
      color = heavy;
    } else if (vishraam && raw.endsWith(',')) {
      color = medium;
    }
    // Strip every mark, wherever it sits, so the glyph never shows.
    final word = raw.replaceAll(RegExp('[;,.]'), '');
    if (word.isEmpty) continue;
    out.add(
      TextSpan(
        text: word,
        style: color == null ? null : TextStyle(color: color),
      ),
    );
    if (i < words.length - 1) out.add(TextSpan(text: separator));
  }
  return out;
}
