import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shia_colors.dart';

/// The app's light or dark [ThemeData], built from [ShiaColors].
///
/// The [ColorScheme] is spelled out role by role rather than generated with
/// `ColorScheme.fromSeed`: a brown seed gives every surface a pink cast,
/// which is exactly what the revamp moves away from. Every widget that
/// already reads `colorScheme.primary`, `onSurfaceVariant` and so on picks up
/// the new palette without changes.
ThemeData buildAppTheme(Brightness brightness) {
  final c = ShiaColors.forBrightness(brightness);
  final scheme = _colorScheme(brightness, c);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    dividerColor: c.divider,
    extensions: <ThemeExtension<dynamic>>[c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: c.accent),
      actionsIconTheme: IconThemeData(color: c.accent),
      titleTextStyle: ShiaText.cardTitle.copyWith(color: c.text),
      systemOverlayStyle: systemOverlayStyleFor(brightness),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.accent,
      unselectedLabelColor: c.textMuted,
      indicatorColor: c.accent,
      dividerColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1),
    listTileTheme: ListTileThemeData(iconColor: c.accent),
    // The revamp's dialog (RevampDialog): the ground, 24 px corners, the
    // section title and muted body text, so the simple confirmations still
    // built as an AlertDialog read the same.
    dialogTheme: DialogThemeData(
      backgroundColor: c.ground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: ShiaText.sectionTitle.copyWith(color: c.text),
      contentTextStyle: ShiaText.body.copyWith(color: c.textMuted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: c.chevron,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.well,
    ),
  );
}

/// Status and navigation bar styling over the ground: transparent status bar
/// with icons that read on it, and a navigation bar in the ground colour.
SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final iconBrightness = isDark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    // iOS names the status bar by its background, not its icons.
    statusBarBrightness: brightness,
    systemNavigationBarColor: ShiaColors.forBrightness(brightness).ground,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

ColorScheme _colorScheme(Brightness brightness, ShiaColors c) {
  final isDark = brightness == Brightness.dark;
  return ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.tintedNotice,
    onPrimaryContainer: c.text,
    // One brown: secondary is the accent too, so nothing in the app picks up
    // a second, unplanned hue.
    secondary: c.accent,
    onSecondary: c.onAccent,
    secondaryContainer: c.tintedNotice,
    onSecondaryContainer: c.text,
    // And one gold, where it reads (dark); on the light ground gold is too
    // faint for the calendar's text, so the accent stands in.
    tertiary: isDark ? c.gold : c.accent,
    onTertiary: isDark ? c.onGold : c.onAccent,
    tertiaryContainer: c.well,
    onTertiaryContainer: c.text,
    error: c.danger,
    onError: isDark ? const Color(0xFF601410) : Colors.white,
    errorContainer: isDark ? const Color(0xFF8C1D18) : const Color(0xFFF9DEDC),
    onErrorContainer:
        isDark ? const Color(0xFFF9DEDC) : const Color(0xFF410E0B),
    surface: c.ground,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceDim: isDark ? c.ground : const Color(0xFFEDE5DA),
    surfaceBright: isDark ? c.line : c.surface,
    surfaceContainerLowest: isDark ? c.ground : c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: isDark ? c.well : c.surface,
    surfaceContainerHighest: c.well,
    outline: c.chevron,
    outlineVariant: c.line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: c.text,
    onInverseSurface: c.ground,
    inversePrimary: ShiaColors.forBrightness(
      isDark ? Brightness.light : Brightness.dark,
    ).accent,
    // No elevation tint anywhere: it is what turned surfaces pink.
    surfaceTint: Colors.transparent,
  );
}
