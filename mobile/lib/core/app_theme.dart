import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta equivalente às classes Tailwind usadas no protótipo do Figma.
abstract final class AppColors {
  // slate
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);

  // teal
  static const teal50 = Color(0xFFF0FDFA);
  static const teal100 = Color(0xFFCCFBF1);
  static const teal200 = Color(0xFF99F6E4);
  static const teal300 = Color(0xFF5EEAD4);
  static const teal400 = Color(0xFF2DD4BF);
  static const teal600 = Color(0xFF0D9488);
  static const teal700 = Color(0xFF0F766E);

  // red
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red200 = Color(0xFFFECACA);
  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);

  // orange
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange400 = Color(0xFFFB923C);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);

  // amber
  static const amber50 = Color(0xFFFFFBEB);
  static const amber200 = Color(0xFFFDE68A);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);

  // green
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green400 = Color(0xFF4ADE80);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);

  // blue
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue400 = Color(0xFF60A5FA);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue800 = Color(0xFF1E40AF);
  static const blue900 = Color(0xFF1E3A8A);

  static const violet50 = Color(0xFFF5F3FF);
  static const violet700 = Color(0xFF6D28D9);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);

  // tons semânticos do protótipo
  static const statusGreenBg = Color(0xFFE8F5E9);
  static const statusGreen = Color(0xFF2E7D32);
  static const statusOrangeBg = Color(0xFFFFF3E0);
  static const statusOrange = Color(0xFFE65100);
  static const statusGreyBg = Color(0xFFF5F5F5);
  static const statusGrey = Color(0xFF616161);
  static const statusRedBg = Color(0xFFFFEBEE);
  static const statusRed = Color(0xFFC62828);
  static const purple = Color(0xFF6A1B9A);
  static const purpleBg = Color(0xFFF3E5F5);
  static const blueStrong = Color(0xFF1565C0);
  static const blueSoft = Color(0xFFE3F2FD);

  static const canvas = slate100;
  static const ink = Color(0xFF172033);
}

const appHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B3D52), Color(0xFF0D7A70), Color(0xFF00BFA5)],
  stops: [0, .5, 1],
);

const professionalHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF123B63), Color(0xFF176B87), Color(0xFF0EA5A4)],
  stops: [0, .52, 1],
);

const criticalHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
);

const contactButtonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
);

const backdropGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE9F3F3), Color(0xFFD7E5E8)],
);

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal600,
      primary: AppColors.teal700,
      surface: Colors.white,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: AppColors.slate100,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.teal700,
    ),
    timePickerTheme: const TimePickerThemeData(backgroundColor: Colors.white),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white),
  );
}

/// Fonte de destaque (Nunito) — `font-display` no protótipo.
TextStyle display({
  double size = 16,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.slate800,
  double? height,
  double? letterSpacing,
}) => GoogleFonts.nunito(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Fonte de texto (Inter).
TextStyle body({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.slate700,
  double? height,
  double? letterSpacing,
  FontStyle? style,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  fontStyle: style,
);
