import 'package:flutter/material.dart';

/// The revamp's colour tokens (docs/DESIGN_SPEC.md, "Colour tokens"), one
/// set per brightness.
///
/// Read them with `ShiaColors.of(context)`. Material widgets get the same
/// values through the explicit [ColorScheme] built from these in
/// app_theme.dart, so most screens never need to look here; this is for the
/// tokens Material has no role for (the prayer card, glass, chevrons...).
@immutable
class ShiaColors extends ThemeExtension<ShiaColors> {
  const ShiaColors({
    required this.ground,
    required this.readerGround,
    required this.surface,
    required this.well,
    required this.line,
    required this.divider,
    required this.readerDivider,
    required this.text,
    required this.textMuted,
    required this.translation,
    required this.accent,
    required this.onAccent,
    required this.prayerCard,
    required this.prayerCardBorder,
    required this.onPrayerCard,
    required this.onPrayerCardMuted,
    required this.gold,
    required this.onGold,
    required this.tintedNotice,
    required this.chevron,
    required this.success,
    required this.danger,
    required this.glass,
    required this.glassSolid,
    required this.glassBorder,
    required this.glassShadow,
  });

  /// Page background.
  final Color ground;

  /// Zikr and Quran reading background.
  final Color readerGround;

  /// Cards, lists, sheets' rows.
  final Color surface;

  /// Icon tiles, date blocks, inputs.
  final Color well;

  /// Card borders.
  final Color line;

  /// Row dividers.
  final Color divider;

  /// Line-group dividers in the reader.
  final Color readerDivider;

  /// Primary text.
  final Color text;

  /// Secondary text and captions.
  final Color textMuted;

  /// Translation lines in the reader.
  final Color translation;

  /// Links, icons, selected states, primary buttons.
  final Color accent;

  /// Text and icons on an [accent] fill.
  final Color onAccent;

  /// The prayer card's fill.
  final Color prayerCard;

  /// The prayer card's 1 px border; transparent in light mode, where the
  /// card's fill already stands off the ground.
  final Color prayerCardBorder;

  final Color onPrayerCard;
  final Color onPrayerCardMuted;

  /// The one primary button on the prayer card.
  final Color gold;

  /// Text on [gold].
  final Color onGold;

  /// The back-up banner.
  final Color tintedNotice;

  /// Chevrons and drag handles only - too faint for text (3.3 : 1).
  final Color chevron;

  final Color success;
  final Color danger;

  /// Translucent fill of the floating tab bar, search button and reader
  /// tools; drawn over a backdrop blur.
  final Color glass;

  /// What [glass] falls back to where blur is off: the same tone, opaque.
  final Color glassSolid;

  final Color glassBorder;
  final Color glassShadow;

  /// Tint behind the selected item in the tab bar.
  Color get selectedTint =>
      accent.withValues(alpha: ground.computeLuminance() > 0.5 ? 0.12 : 0.16);

  static const ShiaColors light = ShiaColors(
    ground: Color(0xFFF8F5F0),
    readerGround: Color(0xFFFBF8F3),
    surface: Color(0xFFFFFFFF),
    well: Color(0xFFF2EBE1),
    line: Color(0xFFE8E0D5),
    divider: Color(0xFFEFE7DC),
    readerDivider: Color(0xFFE6DDD0),
    text: Color(0xFF2A1E16),
    textMuted: Color(0xFF6A5A4D),
    translation: Color(0xFF4E4036),
    accent: Color(0xFF6D4C35),
    onAccent: Color(0xFFFFFFFF),
    prayerCard: Color(0xFF4A3426),
    prayerCardBorder: Color(0x00000000),
    onPrayerCard: Color(0xFFFBF6EE),
    onPrayerCardMuted: Color(0xFFD9CBB8),
    gold: Color(0xFFE4C27A),
    onGold: Color(0xFF2A1E16),
    tintedNotice: Color(0xFFEFE4D6),
    chevron: Color(0xFF9A8A7C),
    success: Color(0xFF2F6B45),
    danger: Color(0xFFB3261E),
    glass: Color(0xD6FFFFFF), // rgba(255,255,255,0.84)
    glassSolid: Color(0xFFFFFFFF),
    glassBorder: Color(0x1A2A1E16), // rgba(42,30,22,0.10)
    glassShadow: Color(0x242A1E16), // rgba(42,30,22,0.14)
  );

  static const ShiaColors dark = ShiaColors(
    ground: Color(0xFF15110D),
    readerGround: Color(0xFF15110D),
    surface: Color(0xFF221B16),
    well: Color(0xFF2E251E),
    line: Color(0xFF3A3029),
    divider: Color(0xFF3A3029),
    readerDivider: Color(0xFF3A3029),
    text: Color(0xFFF2EBE2),
    textMuted: Color(0xFFBFB0A2),
    translation: Color(0xFFCDBFAE),
    accent: Color(0xFFE2C39A),
    onAccent: Color(0xFF2A1E16),
    prayerCard: Color(0xFF3A2A1F),
    prayerCardBorder: Color(0xFF4A3A2E),
    onPrayerCard: Color(0xFFFBF6EE),
    onPrayerCardMuted: Color(0xFFD9CBB8),
    gold: Color(0xFFE4C27A),
    onGold: Color(0xFF2A1E16),
    tintedNotice: Color(0xFF3A2D22),
    chevron: Color(0xFF8C7B6B),
    success: Color(0xFF7FBF95),
    danger: Color(0xFFF2B8B5),
    glass: Color(0xDB2C241D), // rgba(44,36,29,0.86)
    glassSolid: Color(0xFF2C241D),
    glassBorder: Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
    glassShadow: Color(0x73000000), // rgba(0,0,0,0.45)
  );

  static ShiaColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The tokens for [context]'s theme. Falls back to the set matching the
  /// theme's brightness, so a widget under a bare `ThemeData` (a test, a
  /// one-off `Theme` override) still gets sensible colours.
  static ShiaColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ShiaColors>() ?? forBrightness(theme.brightness);
  }

  @override
  ShiaColors copyWith({
    Color? ground,
    Color? readerGround,
    Color? surface,
    Color? well,
    Color? line,
    Color? divider,
    Color? readerDivider,
    Color? text,
    Color? textMuted,
    Color? translation,
    Color? accent,
    Color? onAccent,
    Color? prayerCard,
    Color? prayerCardBorder,
    Color? onPrayerCard,
    Color? onPrayerCardMuted,
    Color? gold,
    Color? onGold,
    Color? tintedNotice,
    Color? chevron,
    Color? success,
    Color? danger,
    Color? glass,
    Color? glassSolid,
    Color? glassBorder,
    Color? glassShadow,
  }) {
    return ShiaColors(
      ground: ground ?? this.ground,
      readerGround: readerGround ?? this.readerGround,
      surface: surface ?? this.surface,
      well: well ?? this.well,
      line: line ?? this.line,
      divider: divider ?? this.divider,
      readerDivider: readerDivider ?? this.readerDivider,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      translation: translation ?? this.translation,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      prayerCard: prayerCard ?? this.prayerCard,
      prayerCardBorder: prayerCardBorder ?? this.prayerCardBorder,
      onPrayerCard: onPrayerCard ?? this.onPrayerCard,
      onPrayerCardMuted: onPrayerCardMuted ?? this.onPrayerCardMuted,
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      tintedNotice: tintedNotice ?? this.tintedNotice,
      chevron: chevron ?? this.chevron,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      glass: glass ?? this.glass,
      glassSolid: glassSolid ?? this.glassSolid,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
    );
  }

  @override
  ShiaColors lerp(ShiaColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ShiaColors(
      ground: l(ground, other.ground),
      readerGround: l(readerGround, other.readerGround),
      surface: l(surface, other.surface),
      well: l(well, other.well),
      line: l(line, other.line),
      divider: l(divider, other.divider),
      readerDivider: l(readerDivider, other.readerDivider),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      translation: l(translation, other.translation),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      prayerCard: l(prayerCard, other.prayerCard),
      prayerCardBorder: l(prayerCardBorder, other.prayerCardBorder),
      onPrayerCard: l(onPrayerCard, other.onPrayerCard),
      onPrayerCardMuted: l(onPrayerCardMuted, other.onPrayerCardMuted),
      gold: l(gold, other.gold),
      onGold: l(onGold, other.onGold),
      tintedNotice: l(tintedNotice, other.tintedNotice),
      chevron: l(chevron, other.chevron),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      glass: l(glass, other.glass),
      glassSolid: l(glassSolid, other.glassSolid),
      glassBorder: l(glassBorder, other.glassBorder),
      glassShadow: l(glassShadow, other.glassShadow),
    );
  }
}

/// The type scale from docs/DESIGN_SPEC.md ("Typography"), for the revamp's
/// own widgets. Sizes are at 1.0x; the app and system text scale apply on
/// top through the ambient [MediaQuery] as for any other text.
///
/// Colour is left unset so each style inherits the surrounding
/// [DefaultTextStyle] (normally [ShiaColors.text]).
abstract final class ShiaText {
  static TextStyle _style(double size, double lineHeight, FontWeight weight,
          {double? letterSpacing}) =>
      TextStyle(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  /// "Favorites", "Quran", "Settings".
  static final TextStyle largeTitle =
      _style(34, 41, FontWeight.w700, letterSpacing: -0.4);

  /// Home's title, today's Hijri date, on phones.
  static final TextStyle homeTitle =
      _style(32, 38, FontWeight.w700, letterSpacing: -0.5);

  /// Home's title from tablet width up.
  static final TextStyle homeTitleWide =
      _style(36, 43, FontWeight.w700, letterSpacing: -0.5);

  /// "Shortcuts", "Coming up".
  static final TextStyle sectionTitle = _style(20, 24, FontWeight.w700);

  static final TextStyle cardTitle = _style(17, 22, FontWeight.w600);
  static final TextStyle body = _style(17, 22, FontWeight.w400);
  static final TextStyle secondary = _style(15, 20, FontWeight.w400);
  static final TextStyle caption = _style(13, 17, FontWeight.w400);

  /// Tab bar and reader tool labels; [tabLabelSelected] for the current one.
  static final TextStyle tabLabel = _style(11, 13, FontWeight.w500);
  static final TextStyle tabLabelSelected = _style(11, 13, FontWeight.w700);
}
