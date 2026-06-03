import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// ThemeData complet Mobili — Light + Dark
/// Contraintes :
///   - Animations ≤ 200ms (low-end Android)
///   - Pas de backdrop blur (coûteux GPU)
///   - Material 3 avec surfaceTintColor désactivé (look plat propre)
///   - Background light : gray50 (#F8FAFF), dark : bleu nuit (#060D2B)
abstract final class AppTheme {
  // ── Tokens de forme ───────────────────────────────────────────────────
  static const double _rXs  = 6.0;
  static const double _rSm  = 10.0;
  static const double _rMd  = 14.0;
  static const double _rLg  = 20.0;
  static const double _rXl  = 28.0;

  static const Duration _fast   = Duration(milliseconds: 150);
  static const Duration _normal = Duration(milliseconds: 200);

  // ─────────────────────────────────────────────────────────────────────
  // LIGHT
  // ─────────────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightScheme,
        textTheme: _textTheme(Brightness.light),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.gray50,

        // ── AppBar ────────────────────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.mobiliBlueDeep,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: const Color(0x1405164D),
          centerTitle: false,
          titleTextStyle: AppTextStyles.headlineSmall,
          iconTheme: const IconThemeData(
            color: AppColors.mobiliBlueDeep,
            size: 24,
          ),
          actionsIconTheme: const IconThemeData(
            color: AppColors.mobiliBlue,
            size: 24,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 60,
          shape: const Border(
            bottom: BorderSide(color: AppColors.gray100, width: 1),
          ),
        ),

        // ── Card ──────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rLg),
            side: const BorderSide(color: AppColors.gray200, width: 1),
          ),
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
        ),

        // ── ElevatedButton ────────────────────────────────────────────
        // Le primary est géré par MobiliButton (gradient) — ce theme
        // couvre les boutons ElevatedButton standards non-Mobili
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mobiliBlue,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.gray200,
            disabledForegroundColor: AppColors.gray400,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rMd),
            ),
            textStyle: AppTextStyles.buttonSecondary,
            animationDuration: _fast,
          ),
        ),

        // ── OutlinedButton ────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mobiliBlue,
            disabledForegroundColor: AppColors.gray400,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rMd),
            ),
            side: const BorderSide(color: AppColors.mobiliBlue, width: 2),
            textStyle: AppTextStyles.buttonSecondary
                .copyWith(color: AppColors.mobiliBlue),
            animationDuration: _fast,
          ),
        ),

        // ── TextButton ────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.mobiliBlue,
            minimumSize: const Size(88, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rSm),
            ),
            textStyle: AppTextStyles.buttonSmall
                .copyWith(color: AppColors.mobiliBlue),
            animationDuration: _fast,
          ),
        ),

        // ── Input ─────────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.gray300, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.gray300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.mobiliBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide: const BorderSide(color: AppColors.danger, width: 2),
          ),
          labelStyle: AppTextStyles.inputLabel,
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.gray400),
          errorStyle: AppTextStyles.bodySmall
              .copyWith(color: AppColors.danger),
          floatingLabelStyle: AppTextStyles.inputLabel
              .copyWith(color: AppColors.mobiliBlue),
          prefixIconColor: AppColors.gray400,
          suffixIconColor: AppColors.gray400,
        ),

        // ── BottomNavigationBar ───────────────────────────────────────
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.mobiliBlue,
          unselectedItemColor: AppColors.gray400,
          selectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),

        // ── NavigationBar (Material 3) ────────────────────────────────
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.mobiliBlueFog,
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                  color: AppColors.mobiliBlue, size: 24);
            }
            return const IconThemeData(color: AppColors.gray400, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.mobiliBlue,
              );
            }
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.gray400,
            );
          }),
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x1405164D),
          elevation: 4,
        ),

        // ── Chip ──────────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.mobiliBlueFog,
          selectedColor: AppColors.mobiliBlueSoft,
          labelStyle: AppTextStyles.labelSmall
              .copyWith(color: AppColors.mobiliBlue),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: const StadiumBorder(),
          side: BorderSide.none,
          iconTheme:
              const IconThemeData(color: AppColors.mobiliBlue, size: 16),
        ),

        // ── Divider ───────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.gray100,
          thickness: 1,
          space: 1,
        ),

        // ── ListTile ──────────────────────────────────────────────────
        listTileTheme: ListTileThemeData(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          minVerticalPadding: 10,
          tileColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rSm),
          ),
          titleTextStyle: AppTextStyles.titleMedium,
          subtitleTextStyle: AppTextStyles.bodySmall,
          iconColor: AppColors.mobiliBlue,
        ),

        // ── Dialog ────────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rXl),
          ),
          titleTextStyle: AppTextStyles.headlineMedium,
          contentTextStyle: AppTextStyles.bodyLarge,
          elevation: 8,
          shadowColor: const Color(0x2005164D),
          surfaceTintColor: Colors.transparent,
        ),

        // ── BottomSheet ───────────────────────────────────────────────
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(_rXl),
            ),
          ),
          dragHandleColor: AppColors.gray300,
          dragHandleSize: const Size(40, 4),
          elevation: 8,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
        ),

        // ── SnackBar ──────────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.mobiliBlueDeep,
          contentTextStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.white),
          actionTextColor: AppColors.mobiliYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rMd),
          ),
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(12),
          elevation: 4,
        ),

        // ── FAB ───────────────────────────────────────────────────────
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.mobiliYellow,
          foregroundColor: AppColors.mobiliBlueDeep,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rLg),
          ),
        ),

        // ── Progress ──────────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.mobiliBlue,
          linearTrackColor: AppColors.mobiliBlueFog,
          circularTrackColor: AppColors.mobiliBlueFog,
        ),

        // ── Badge ─────────────────────────────────────────────────────
        badgeTheme: const BadgeThemeData(
          backgroundColor: AppColors.danger,
          textColor: AppColors.white,
          smallSize: 8,
          largeSize: 18,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),

        // ── Tab ───────────────────────────────────────────────────────
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.mobiliBlue,
          unselectedLabelColor: AppColors.gray400,
          indicatorColor: AppColors.mobiliBlue,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          dividerColor: AppColors.gray200,
        ),

        // ── Switch ────────────────────────────────────────────────────
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.white;
            return AppColors.gray400;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.mobiliBlue;
            }
            return AppColors.gray200;
          }),
          trackOutlineColor:
              WidgetStateProperty.all(Colors.transparent),
        ),

        // ── PageTransitions — rapide, low-end ─────────────────────────
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),

        splashColor: AppColors.mobiliBlueFog,
        highlightColor: AppColors.gray100,
        splashFactory: InkRipple.splashFactory,
        visualDensity: VisualDensity.standard,
      );

  // ─────────────────────────────────────────────────────────────────────
  // DARK
  // ─────────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkScheme,
        textTheme: _textTheme(Brightness.dark),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.darkBg,

        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkOnSurface,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: const Color(0x40000000),
          centerTitle: false,
          titleTextStyle: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.darkOnSurface),
          iconTheme: const IconThemeData(
              color: AppColors.darkOnSurface, size: 24),
          actionsIconTheme: const IconThemeData(
              color: AppColors.mobiliYellow, size: 24),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 60,
          shape: const Border(
            bottom: BorderSide(color: AppColors.darkOutline, width: 1),
          ),
        ),

        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rLg),
            side: const BorderSide(color: AppColors.darkOutline, width: 1),
          ),
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mobiliBlueLight,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.darkOutline,
            disabledForegroundColor: AppColors.darkOnSurfaceVar,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rMd),
            ),
            textStyle: AppTextStyles.buttonSecondary,
            animationDuration: _fast,
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mobiliYellowSoft,
            disabledForegroundColor: AppColors.darkOnSurfaceVar,
            minimumSize: const Size(double.infinity, 52),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rMd),
            ),
            side: const BorderSide(
                color: AppColors.mobiliYellowSoft, width: 2),
            textStyle: AppTextStyles.buttonSecondary
                .copyWith(color: AppColors.mobiliYellowSoft),
            animationDuration: _fast,
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.mobiliYellow,
            minimumSize: const Size(88, 44),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rSm),
            ),
            textStyle: AppTextStyles.buttonSmall
                .copyWith(color: AppColors.mobiliYellow),
            animationDuration: _fast,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceRaised,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.darkOutline, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.darkOutline, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.mobiliYellow, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_rMd),
            borderSide: const BorderSide(color: AppColors.danger, width: 2),
          ),
          labelStyle: AppTextStyles.inputLabel
              .copyWith(color: AppColors.darkOnSurfaceVar),
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.darkOnSurfaceVar),
          errorStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
          floatingLabelStyle: AppTextStyles.inputLabel
              .copyWith(color: AppColors.mobiliYellow),
          prefixIconColor: AppColors.darkOnSurfaceVar,
          suffixIconColor: AppColors.darkOnSurfaceVar,
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.mobiliYellow,
          unselectedItemColor: AppColors.darkOnSurfaceVar,
          selectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          indicatorColor: const Color(0xFF1A2E6B),
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                  color: AppColors.mobiliYellow, size: 24);
            }
            return const IconThemeData(
                color: AppColors.darkOnSurfaceVar, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.mobiliYellow,
              );
            }
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.darkOnSurfaceVar,
            );
          }),
          surfaceTintColor: Colors.transparent,
          elevation: 4,
        ),

        chipTheme: ChipThemeData(
          backgroundColor: AppColors.darkSurfaceRaised,
          selectedColor: const Color(0xFF1A2E6B),
          labelStyle: AppTextStyles.labelSmall
              .copyWith(color: AppColors.mobiliYellowSoft),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: const StadiumBorder(),
          side: BorderSide.none,
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.darkOutline,
          thickness: 1,
          space: 1,
        ),

        listTileTheme: ListTileThemeData(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          minVerticalPadding: 10,
          tileColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rSm),
          ),
          titleTextStyle: AppTextStyles.titleMedium
              .copyWith(color: AppColors.darkOnSurface),
          subtitleTextStyle: AppTextStyles.bodySmall
              .copyWith(color: AppColors.darkOnSurfaceVar),
          iconColor: AppColors.mobiliYellow,
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rXl),
          ),
          titleTextStyle: AppTextStyles.headlineMedium
              .copyWith(color: AppColors.darkOnSurface),
          contentTextStyle: AppTextStyles.bodyLarge
              .copyWith(color: AppColors.darkOnSurface),
          elevation: 8,
          surfaceTintColor: Colors.transparent,
        ),

        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(_rXl)),
          ),
          dragHandleColor: AppColors.darkOutline,
          dragHandleSize: const Size(40, 4),
          elevation: 8,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkSurfaceRaised,
          contentTextStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.darkOnSurface),
          actionTextColor: AppColors.mobiliYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rMd),
          ),
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(12),
          elevation: 4,
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.mobiliYellow,
          foregroundColor: AppColors.mobiliBlueDeep,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rLg),
          ),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.mobiliYellow,
          linearTrackColor: Color(0xFF1A2E6B),
          circularTrackColor: Color(0xFF1A2E6B),
        ),

        badgeTheme: const BadgeThemeData(
          backgroundColor: AppColors.danger,
          textColor: AppColors.white,
          smallSize: 8,
          largeSize: 18,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),

        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.mobiliYellow,
          unselectedLabelColor: AppColors.darkOnSurfaceVar,
          indicatorColor: AppColors.mobiliYellow,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          dividerColor: AppColors.darkOutline,
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.mobiliBlueDeep;
            }
            return AppColors.darkOnSurfaceVar;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.mobiliYellow;
            }
            return AppColors.darkOutline;
          }),
          trackOutlineColor:
              WidgetStateProperty.all(Colors.transparent),
        ),

        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),

        splashColor: const Color(0x1FFFCC00),
        highlightColor: const Color(0x0FFFCC00),
        splashFactory: InkRipple.splashFactory,
        visualDensity: VisualDensity.standard,
      );

  // ─────────────────────────────────────────────────────────────────────
  // COLOR SCHEMES
  // ─────────────────────────────────────────────────────────────────────
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.mobiliBlue,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.mobiliBlueFog,
    onPrimaryContainer: AppColors.mobiliBlueDeep,
    secondary: AppColors.mobiliYellow,
    onSecondary: AppColors.mobiliBlueDeep,
    secondaryContainer: Color(0xFFFFF8D0),
    onSecondaryContainer: Color(0xFF3D2E00),
    tertiary: AppColors.success,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.successSoft,
    onTertiaryContainer: Color(0xFF052E0F),
    error: AppColors.danger,
    onError: AppColors.white,
    errorContainer: AppColors.dangerSoft,
    onErrorContainer: Color(0xFF5C0000),
    surface: AppColors.white,
    onSurface: AppColors.gray900,
    surfaceContainerHighest: AppColors.gray100,
    onSurfaceVariant: AppColors.gray600,
    outline: AppColors.gray300,
    outlineVariant: AppColors.gray200,
    shadow: Color(0x1405164D),
    scrim: Color(0x80000000),
    inverseSurface: AppColors.mobiliBlueDeep,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.mobiliYellowSoft,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.mobiliYellow,
    onPrimary: AppColors.mobiliBlueDeep,
    primaryContainer: Color(0xFF1A2E6B),
    onPrimaryContainer: AppColors.mobiliYellowSoft,
    secondary: AppColors.mobiliBlueLight,
    onSecondary: AppColors.white,
    secondaryContainer: Color(0xFF0A1F70),
    onSecondaryContainer: AppColors.mobiliBlueSoft,
    tertiary: AppColors.success,
    onTertiary: AppColors.white,
    tertiaryContainer: Color(0xFF052E0F),
    onTertiaryContainer: AppColors.stationGreenSoft,
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF5C0000),
    errorContainer: Color(0xFF8B1A1A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainerHighest: AppColors.darkSurfaceRaised,
    onSurfaceVariant: AppColors.darkOnSurfaceVar,
    outline: AppColors.darkOutline,
    outlineVariant: Color(0xFF0F1E50),
    shadow: Color(0x40000000),
    scrim: Color(0x99000000),
    inverseSurface: AppColors.darkOnSurface,
    onInverseSurface: AppColors.darkSurface,
    inversePrimary: AppColors.mobiliBlue,
  );

  // ─────────────────────────────────────────────────────────────────────
  // TEXT THEME
  // ─────────────────────────────────────────────────────────────────────
  static TextTheme _textTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color title = isDark ? AppColors.darkOnSurface : AppColors.mobiliBlueDeep;
    final Color body  = isDark ? AppColors.darkOnSurface : AppColors.gray800;
    final Color sub   = isDark ? AppColors.darkOnSurfaceVar : AppColors.gray500;

    return TextTheme(
      displayLarge:  AppTextStyles.displayLarge.copyWith(color: title),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: title),
      displaySmall:  AppTextStyles.headlineLarge.copyWith(color: title),
      headlineLarge:  AppTextStyles.headlineLarge.copyWith(color: title),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: title),
      headlineSmall:  AppTextStyles.headlineSmall.copyWith(color: title),
      titleLarge:  AppTextStyles.titleLarge.copyWith(color: body),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: body),
      titleSmall:  AppTextStyles.titleSmall.copyWith(color: body),
      bodyLarge:  AppTextStyles.bodyLarge.copyWith(color: body),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: body),
      bodySmall:  AppTextStyles.bodySmall.copyWith(color: sub),
      labelLarge:  AppTextStyles.labelLarge.copyWith(color: body),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: body),
      labelSmall:  AppTextStyles.labelSmall.copyWith(color: sub),
    );
  }
}
