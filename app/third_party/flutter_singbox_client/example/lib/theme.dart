import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const kBg = Color(0xFF0B0F14);
const kCard = Color(0xFF111827);
const kCardAlt = Color(0xFF162032);
const kAccent = Color(0xFF38BDF8);
const kSuccess = Color(0xFF22C55E);
const kWarning = Color(0xFFF59E0B);
const kError = Color(0xFFEF4444);
const kTextPrimary = Color(0xFFF1F5F9);
const kTextSecondary = Color(0xFF94A3B8);
const kTextMuted = Color(0xFF475569);
const kDivider = Color(0xFF1E293B);

// ── Theme builder ─────────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      surface: kCard,
      primary: kAccent,
      onPrimary: kBg,
      secondary: kAccent,
      onSecondary: kBg,
      error: kError,
      onSurface: kTextPrimary,
      surfaceContainerHighest: kCardAlt,
      outline: kDivider,
    ),
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: kTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: kTextSecondary, size: 22),
      actionsIconTheme: IconThemeData(color: kTextSecondary, size: 22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kCard,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: const Color(0x200E7490),
      elevation: 0,
      height: 60,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
          color: sel ? kAccent : kTextMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return IconThemeData(color: sel ? kAccent : kTextMuted, size: 20);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: kDivider,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kTextSecondary,
      textColor: kTextPrimary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return kTextMuted;
        return s.contains(WidgetState.selected) ? kAccent : const Color(0xFF64748B);
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return kDivider;
        return s.contains(WidgetState.selected)
            ? const Color(0x4038BDF8)
            : const Color(0xFF1E293B);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: kCardAlt,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      textStyle: TextStyle(color: kTextPrimary, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: kCard,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kError),
      ),
      labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
      helperStyle: const TextStyle(color: kTextMuted, fontSize: 11),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: kTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: kTextPrimary, fontSize: 14),
      bodySmall: TextStyle(color: kTextSecondary, fontSize: 12),
      labelLarge: TextStyle(
        color: kTextSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
      labelMedium: TextStyle(color: kTextSecondary, fontSize: 11),
      labelSmall: TextStyle(color: kTextMuted, fontSize: 10),
      titleLarge: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    ),
  );
}
