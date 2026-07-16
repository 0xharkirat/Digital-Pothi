import 'package:flutter/material.dart';

/// The Gurbani font family (see pubspec). One family, weights 400/600/800.
const kGurmukhiFont = 'GurbaniAkhar';

/// Raw palette. Contrast ratios are against the navy display surface unless
/// noted; the presenter's readability rides on the Gurmukhi text, never on the
/// accent, so the accent is only ever a marker/selection colour.
abstract final class AppColors {
  /// Kesari / saffron - the nishan sahib colour. Accent + current-line marker.
  /// 5.3:1 on navy (WCAG AA text, AAA large).
  static const kesari = Color(0xFFE8871E);

  /// Deep navy - the default projected/streamed surface.
  static const navy = Color(0xFF0B1E3B);
  static const navyDeep = Color(0xFF071426);

  /// Cream - Gurmukhi on the display. 14:1 on navy (AAA); softer than pure white.
  static const cream = Color(0xFFFBF3E3);

  /// Amber - transliteration on the display. 8.6:1 on navy (AAA).
  static const amber = Color(0xFFF0B429);

  /// A darker amber that still clears AA on a *light* controller surface.
  static const amberOnLight = Color(0xFFA85D00);

  /// Sync semantics (already used by the tracker badge).
  static const onLine = Color(0xFF34A853);
  static const catchingUp = amber;

  /// Cool-dark controller surfaces. Seeding the scheme on saffron tints the
  /// neutral tones warm-brown; these keep the operator's app clean and let the
  /// navy display be the only warm surface.
  static const ctrlBg = Color(0xFF0E1116);
  static const ctrlSurface = Color(0xFF12161D);
  static const ctrlPane = Color(0xFF171C24);
  static const ctrlPaneHigh = Color(0xFF212A35);
  static const ctrlText = Color(0xFFE6E8EC);
  static const ctrlTextMuted = Color(0xFF9AA1AC);
}

/// Domain design tokens, kept out of [ColorScheme] so the Gurbani-specific look
/// themes from one place. Controller styles adapt to light/dark; the `display*`
/// tokens are the fixed presentation look (the projected surface is always dark
/// regardless of the controller's mode), plus a runtime-selectable background.
@immutable
class GurbaniTheme extends ThemeExtension<GurbaniTheme> {
  const GurbaniTheme({
    required this.accent,
    required this.gurmukhi,
    required this.transliteration,
    required this.translation,
    required this.teeka,
    required this.displayBackground,
    required this.displayText,
    required this.displayAccent,
  });

  /// Kesari, for selection + the current-line marker.
  final Color accent;

  /// Shabad-view line in the controller (GurbaniAkhar, on-surface).
  final TextStyle gurmukhi;

  /// Roman transliteration in the controller (contrast-safe per mode).
  final TextStyle transliteration;

  /// English translation in the controller.
  final TextStyle translation;

  /// Punjabi teeka in the controller (GurbaniAkhar).
  final TextStyle teeka;

  /// The projected surface - navy by default; the app swaps this for the other
  /// STTM-style presets (black, khanda, custom image) at runtime.
  final Color displayBackground;

  /// Cream, for the big projected Gurmukhi line.
  final Color displayText;

  /// Amber, for the projected transliteration and marker.
  final Color displayAccent;

  @override
  GurbaniTheme copyWith({
    Color? accent,
    TextStyle? gurmukhi,
    TextStyle? transliteration,
    TextStyle? translation,
    TextStyle? teeka,
    Color? displayBackground,
    Color? displayText,
    Color? displayAccent,
  }) => GurbaniTheme(
    accent: accent ?? this.accent,
    gurmukhi: gurmukhi ?? this.gurmukhi,
    transliteration: transliteration ?? this.transliteration,
    translation: translation ?? this.translation,
    teeka: teeka ?? this.teeka,
    displayBackground: displayBackground ?? this.displayBackground,
    displayText: displayText ?? this.displayText,
    displayAccent: displayAccent ?? this.displayAccent,
  );

  @override
  GurbaniTheme lerp(GurbaniTheme? other, double t) {
    if (other == null) return this;
    return GurbaniTheme(
      accent: Color.lerp(accent, other.accent, t)!,
      gurmukhi: TextStyle.lerp(gurmukhi, other.gurmukhi, t)!,
      transliteration: TextStyle.lerp(
        transliteration,
        other.transliteration,
        t,
      )!,
      translation: TextStyle.lerp(translation, other.translation, t)!,
      teeka: TextStyle.lerp(teeka, other.teeka, t)!,
      displayBackground: Color.lerp(
        displayBackground,
        other.displayBackground,
        t,
      )!,
      displayText: Color.lerp(displayText, other.displayText, t)!,
      displayAccent: Color.lerp(displayAccent, other.displayAccent, t)!,
    );
  }
}

/// App themes. Material 3 seeded on kesari for harmonious components, plus the
/// [GurbaniTheme] tokens. The projected display always uses the dark
/// presentation tokens, so the controller can be light without washing out what
/// the sangat sees.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: AppColors.kesari,
      brightness: brightness,
    );
    if (dark) {
      // Cool the saffron-tinted brown neutrals to a clean slate-dark.
      scheme = scheme.copyWith(
        surface: AppColors.ctrlSurface,
        surfaceContainerLowest: AppColors.ctrlBg,
        surfaceContainerLow: AppColors.ctrlPane,
        surfaceContainer: AppColors.ctrlPane,
        surfaceContainerHigh: AppColors.ctrlPaneHigh,
        surfaceContainerHighest: AppColors.ctrlPaneHigh,
        onSurface: AppColors.ctrlText,
        onSurfaceVariant: AppColors.ctrlTextMuted,
      );
    }
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppColors.ctrlBg : null,
      extensions: [
        GurbaniTheme(
          accent: AppColors.kesari,
          gurmukhi: TextStyle(
            fontFamily: kGurmukhiFont,
            fontSize: 26,
            height: 1.7,
            color: scheme.onSurface,
          ),
          transliteration: TextStyle(
            fontSize: 16,
            height: 1.5,
            // Amber pops on a dark controller but fails contrast on white.
            color: dark ? AppColors.amber : AppColors.amberOnLight,
          ),
          translation: TextStyle(
            fontSize: 17,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
          teeka: TextStyle(
            fontFamily: kGurmukhiFont,
            fontSize: 17,
            height: 1.7,
            color: scheme.onSurfaceVariant,
          ),
          displayBackground: AppColors.navy,
          displayText: AppColors.cream,
          displayAccent: AppColors.amber,
        ),
      ],
    );
  }
}

/// Sugar so widgets read `context.gurbani.gurmukhi` instead of the long
/// `Theme.of(context).extension<GurbaniTheme>()!`.
extension GurbaniThemeX on BuildContext {
  GurbaniTheme get gurbani => Theme.of(this).extension<GurbaniTheme>()!;
}
