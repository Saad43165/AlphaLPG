import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Alpha LPG design tokens. Brand colours are fixed; everything that must
/// change between light and dark mode lives in [AppPalette] and is read with
/// `context.pal`.
abstract final class Brand {
  // Brand
  static const blue = Color(0xFF33A4E3); // logo "A"
  static const blueDark = Color(0xFF1F7FC0); // primary actions
  static const blueDeep = Color(0xFF155E93); // header gradient end
  static const blueLight = Color(0xFFA9DDF5); // last chevron
  static const navy = Color(0xFF0F2A3F); // size badges, dark panels
  static const flame = Color(0xFFF6C23E); // flame in the logo
  static const cylinderRed = Color(0xFFE53424);

  // Status
  static const whatsapp = Color(0xFF25D366);
  static const success = Color(0xFF1E9E5A);
  static const danger = Color(0xFFC62828);
  static const warning = Color(0xFF9A6B00);

  static const radius = 18.0;

  static const headerGradient = LinearGradient(
    colors: [blue, blueDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkStatusBar = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static const lightStatusBar = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static ThemeData theme(Brightness brightness) {
    final pal = brightness == Brightness.dark
        ? AppPalette.night
        : AppPalette.light;
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: brightness,
      primary: dark ? const Color(0xFF3AA0E2) : blueDark,
      secondary: flame,
      surface: pal.card,
      error: danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      // Urdu / Arabic letters: Inter has none, so the apps that bundle
      // this font use it (others ignore the name).
      fontFamilyFallback: const ['NotoNaskh'],
      brightness: brightness,
    );
    final text = base.textTheme
        .apply(bodyColor: pal.ink, displayColor: pal.ink)
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: pal.ink,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: pal.ink,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(color: pal.muted),
        );
    final roundedField = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: pal.line),
    );
    return base.copyWith(
      extensions: [pal],
      scaffoldBackgroundColor: pal.surface,
      canvasColor: pal.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: dark ? lightStatusBar : darkStatusBar,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: pal.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: pal.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: pal.line, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: dark ? const Color(0xFF4DB3F0) : blueDark,
        textColor: pal.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      iconTheme: IconThemeData(color: pal.ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blueDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: dark
              ? const Color(0xFF28425A)
              : const Color(0xFFC9D6E2),
          disabledForegroundColor: dark
              ? const Color(0xFF6B8399)
              : Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pal.ink,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: pal.line, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? const Color(0xFF4DB3F0) : blueDark,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: roundedField,
        enabledBorder: roundedField,
        focusedBorder: roundedField.copyWith(
          borderSide: BorderSide(
            color: dark ? const Color(0xFF4DB3F0) : blueDark,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(color: pal.muted),
        hintStyle: TextStyle(color: pal.muted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: pal.card,
        selectedColor: dark ? blueDark : navy,
        side: BorderSide(color: pal.line),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: pal.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: pal.card,
          selectedBackgroundColor: dark ? blueDark : navy,
          selectedForegroundColor: Colors.white,
          foregroundColor: pal.ink,
          side: BorderSide(color: pal.line),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: blue.withValues(alpha: dark ? 0.25 : 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? pal.ink : pal.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? (dark ? const Color(0xFF4DB3F0) : blueDark)
                : pal.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? blueDark : pal.line,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF223A4F) : navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? blueDark : pal.muted,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Colours that differ between light and dark mode.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.surface,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.tint,
    required this.shadow,
  });

  final bool isDark;

  /// Screen background.
  final Color surface;

  /// Cards, sheets and fields.
  final Color card;
  final Color line;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Soft blue wash behind product images and icons.
  final Color tint;
  final List<BoxShadow> shadow;

  static final light = AppPalette(
    isDark: false,
    surface: const Color(0xFFF4F7FA),
    card: Colors.white,
    line: const Color(0xFFE2E9F0),
    ink: Brand.navy,
    muted: const Color(0xFF61758A),
    tint: const Color(0xFFEAF5FC),
    shadow: [
      BoxShadow(
        color: Brand.navy.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static const night = AppPalette(
    isDark: true,
    surface: Color(0xFF0A1621),
    card: Color(0xFF122434),
    line: Color(0xFF223A4F),
    ink: Color(0xFFE9F1F8),
    muted: Color(0xFF8CA3B8),
    tint: Color(0xFF173650),
    shadow: [],
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 ? this : (other as AppPalette? ?? this);
}

extension PaletteContext on BuildContext {
  /// Light/dark colours for the current theme. Rebuilds when the theme changes.
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}
