import 'package:flutter/material.dart';

import '../../data/gurbani_database.dart';
import '../../theme/app_theme.dart';
import '../gurmukhi_text.dart';

/// The projected/streamed display of the current line: the big Gurmukhi over the
/// (selectable) display background, with English translation and roman
/// transliteration beneath - the presenter's display pane, and the shape of the
/// LAN overlay. Pure render: give it a line, its [LineDisplay], and the display
/// options.
class DisplayPane extends StatelessWidget {
  const DisplayPane({
    required this.gurmukhi,
    required this.display,
    this.background,
    this.larivaar = false,
    this.vishraam = true,
    this.fontScale = 1.0,
    this.leftAlign = false,
    super.key,
  });

  final String gurmukhi;
  final LineDisplay display;

  /// Overrides the theme's default display surface (the selectable preset).
  final Color? background;

  final bool larivaar;
  final bool vishraam;
  final double fontScale;
  final bool leftAlign; // STTM left-align: flush the text left instead of centre

  @override
  Widget build(BuildContext context) {
    final g = context.gurbani;
    final align = leftAlign ? TextAlign.left : TextAlign.center;
    final cross = leftAlign
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final en = display.translations['en'];
    // The roman transliteration embeds the same vishraam marks (`; , .`) as the
    // Gurmukhi, so strip them here too - only the English (real punctuation) and
    // Punjabi teeka keep theirs.
    final romanRaw = display.transliterations['roman'];
    final roman = romanRaw == null ? null : strippedGurmukhi(romanRaw);

    return ColoredBox(
      color: background ?? g.displayBackground,
      child: Align(
        alignment: leftAlign ? Alignment.centerLeft : Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: cross,
            children: [
              Text.rich(
                TextSpan(
                  children: gurmukhiSpans(
                    gurmukhi,
                    heavy: g.displayAccent,
                    medium: g.displayText.withValues(alpha: 0.55),
                    larivaar: larivaar,
                    vishraam: vishraam,
                  ),
                ),
                textAlign: align,
                style: TextStyle(
                  fontFamily: kGurmukhiFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 46 * fontScale,
                  height: 1.6,
                  color: g.displayText,
                ),
              ),
              if (en != null) ...[
                SizedBox(height: 28 * fontScale),
                Text(
                  en,
                  textAlign: align,
                  style: TextStyle(
                    fontSize: 22 * fontScale,
                    height: 1.4,
                    color: g.displayText.withValues(alpha: 0.86),
                  ),
                ),
              ],
              if (roman != null) ...[
                SizedBox(height: 18 * fontScale),
                Text(
                  roman,
                  textAlign: align,
                  style: TextStyle(
                    fontSize: 18 * fontScale,
                    height: 1.4,
                    color: g.displayAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
