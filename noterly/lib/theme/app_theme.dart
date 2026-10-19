import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 Expressive styling for the app.
///
/// Flutter does not ship Material 3 Expressive components yet, so the expressive look (bolder type, larger and
/// shape-morphing corners, segmented list groups, spring-like motion) is applied through the theme and the app's
/// own widgets in `lib/widgets/expressive.dart`.
class AppTheme {
  static const Color seedColour = Color.fromRGBO(153, 0, 228, 1);

  /// Corner radii from the Material 3 Expressive shape scale.
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusLargeIncreased = 20;
  static const double radiusExtraLarge = 28;

  /// Standard spring-like motion: a quick start with a soft overshoot-free settle.
  static const Curve springCurve = Curves.easeOutCubic;
  static const Curve springBouncyCurve = Curves.easeOutBack;
  static const Duration motionFast = Duration(milliseconds: 200);
  static const Duration motionMedium = Duration(milliseconds: 350);

  /// The fallback scheme when the device has no dynamic (wallpaper) colours.
  static ColorScheme fallbackScheme(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: seedColour, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.expressive);

  /// The dynamic_color package builds its scheme from the old core palette and leaves the surface container roles
  /// equal to the page colour, which the expressive list groups depend on. Take the page colour and its container
  /// ladder from a scheme seeded with the wallpaper's primary colour, so they keep their contrast in light and dark,
  /// and keep the rest of the device colours as the system set them.
  static ColorScheme completeDynamicScheme(ColorScheme dynamicScheme) {
    final seeded = ColorScheme.fromSeed(seedColor: dynamicScheme.primary, brightness: dynamicScheme.brightness);

    return dynamicScheme.copyWith(
      surface: seeded.surface,
      surfaceDim: seeded.surfaceDim,
      surfaceBright: seeded.surfaceBright,
      surfaceContainerLowest: seeded.surfaceContainerLowest,
      surfaceContainerLow: seeded.surfaceContainerLow,
      surfaceContainer: seeded.surfaceContainer,
      surfaceContainerHigh: seeded.surfaceContainerHigh,
      surfaceContainerHighest: seeded.surfaceContainerHighest,
    );
  }

  static ThemeData build(ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: scheme.brightness);
    final textTheme = _textTheme(base.textTheme, scheme);

    // Buttons morph from fully round to a rounder rectangle while pressed.
    final buttonShape = WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
      if (states.contains(WidgetState.pressed)) {
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium));
      }
      return const StadiumBorder();
    });
    final buttonStyle = ButtonStyle(
      shape: buttonShape,
      animationDuration: motionFast,
      textStyle: WidgetStatePropertyAll(weighted(textTheme.labelLarge!, FontWeight.w600)),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge!.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusExtraLarge)),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: weighted(textTheme.bodyLarge!.copyWith(color: scheme.onSurface), FontWeight.w500),
        subtitleTextStyle: textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        iconColor: scheme.onSurfaceVariant,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 3,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLargeIncreased)),
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 64),
        extendedPadding: const EdgeInsetsDirectional.only(start: 20, end: 24),
        extendedIconLabelSpacing: 12,
        extendedTextStyle: textTheme.titleMedium,
        iconSize: 26,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return weighted(
            textTheme.labelMedium!.copyWith(color: selected ? scheme.secondary : scheme.onSurfaceVariant),
            selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusExtraLarge)),
        titleTextStyle: textTheme.headlineSmall!.copyWith(color: scheme.onSurface),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusExtraLarge)),
        headerHeadlineStyle: textTheme.headlineLarge,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusExtraLarge)),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      inputDecorationTheme: InputDecorationThemeData(border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium))),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(shape: buttonShape, animationDuration: motionFast),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textStyle: weighted(textTheme.labelSmall!, FontWeight.w700),
      ),
    );
  }

  /// [style] in Inter at [weight]. google_fonts loads each weight as its own font family, so changing only the
  /// weight of an Inter style would keep drawing the regular face.
  static TextStyle weighted(TextStyle style, FontWeight weight) => GoogleFonts.inter(textStyle: style.copyWith(fontWeight: weight));

  /// Inter with the Material 3 Expressive emphasised weights on display, headline and title styles.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final emphasised = base.copyWith(
      displayLarge: base.displayLarge!.copyWith(fontWeight: FontWeight.w600),
      displayMedium: base.displayMedium!.copyWith(fontWeight: FontWeight.w600),
      displaySmall: base.displaySmall!.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: base.headlineLarge!.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge!.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall!.copyWith(fontWeight: FontWeight.w600),
      // Used for the secondary lines in the reminder lists (times, repeats, snoozes).
      labelLarge: base.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
    );

    return GoogleFonts.interTextTheme(emphasised);
  }
}
