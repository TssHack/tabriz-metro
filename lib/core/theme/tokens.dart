import 'package:flutter/material.dart';

/// Semantic color tokens from the approved Figma design system.
/// Widgets read colors only through `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.fg,
    required this.fgMuted,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.line1,
    required this.line1Soft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.hero,
    required this.heroB,
    required this.onHero,
  });

  static const light = AppTokens(
    bg: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF2F9),
    fg: Color(0xFF0F172A),
    fgMuted: Color(0xFF5B6578),
    border: Color(0xFFE3E8F1),
    primary: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE3EBFF),
    line1: Color(0xFFD7263D),
    line1Soft: Color(0xFFFDE7EA),
    success: Color(0xFF0E8A5F),
    successSoft: Color(0xFFDDF5EA),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    hero: Color(0xFF1D4ED8),
    heroB: Color(0xFF1E3A8A),
    onHero: Color(0xFFFFFFFF),
  );

  static const dark = AppTokens(
    bg: Color(0xFF0A1020),
    surface: Color(0xFF121A2C),
    surface2: Color(0xFF1A2438),
    fg: Color(0xFFE8EDF6),
    fgMuted: Color(0xFF9AA6BC),
    border: Color(0xFF243049),
    primary: Color(0xFF6E9BFF),
    onPrimary: Color(0xFF0A1020),
    primarySoft: Color(0xFF1B2A52),
    line1: Color(0xFFFF5A6E),
    line1Soft: Color(0xFF3A1820),
    success: Color(0xFF3DDC97),
    successSoft: Color(0xFF0F3327),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2E0E),
    hero: Color(0xFF1B2F6B),
    heroB: Color(0xFF111C3F),
    onHero: Color(0xFFFFFFFF),
  );

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color fg;
  final Color fgMuted;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color line1;
  final Color line1Soft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color hero;
  final Color heroB;
  final Color onHero;

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? fg,
    Color? fgMuted,
    Color? border,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? line1,
    Color? line1Soft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? hero,
    Color? heroB,
    Color? onHero,
  }) => AppTokens(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    fg: fg ?? this.fg,
    fgMuted: fgMuted ?? this.fgMuted,
    border: border ?? this.border,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primarySoft: primarySoft ?? this.primarySoft,
    line1: line1 ?? this.line1,
    line1Soft: line1Soft ?? this.line1Soft,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    hero: hero ?? this.hero,
    heroB: heroB ?? this.heroB,
    onHero: onHero ?? this.onHero,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      fg: l(fg, other.fg),
      fgMuted: l(fgMuted, other.fgMuted),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      line1: l(line1, other.line1),
      line1Soft: l(line1Soft, other.line1Soft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      hero: l(hero, other.hero),
      heroB: l(heroB, other.heroB),
      onHero: l(onHero, other.onHero),
    );
  }
}

/// Corner radii and sizes from the design system.
abstract final class AppRadii {
  static const double card = 20;
  static const double cardSmall = 18;
  static const double button = 14;
  static const double chip = 999;
}

abstract final class AppSizes {
  static const double minTouch = 44;
  static const double gutter = 16;
}

extension TokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
