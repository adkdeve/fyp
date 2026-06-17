import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Theme-aware semantic colors + status-bar helpers.
///
/// Har screen inhe use kare taake light/dark dono mein consistent rahe.
/// `Theme.of(context).brightness` GetMaterialApp ke theme switch hone par
/// update hota hai, isliye ye getters reactive hain (build dobara chalta hai).
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Surfaces ────────────────────────────────────────────────────────────────
  /// Screen ka background (scaffold).
  Color get scaffoldBg => isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);

  /// Card / sheet / header surface.
  Color get cardBg => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  /// Chip / input / subtle fill.
  Color get subtleBg => isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6);

  // ── Text ────────────────────────────────────────────────────────────────────
  Color get textPrimary => isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get textTertiary => isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  // ── Lines ─────────────────────────────────────────────────────────────────────
  Color get borderColor => isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);
  Color get dividerColor => isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEEEFF2);

  // ── Status bar ──────────────────────────────────────────────────────────────
  /// Default status bar — light theme mein white, dark theme mein dark (black).
  /// Koi specific color nahi (sirf dashboard apna blue use karta hai).
  SystemUiOverlayStyle get statusBar => SystemUiOverlayStyle(
        statusBarColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      );

  /// Fixed-color status bar (e.g. dashboard ke liye blue). Icons light rakhe
  /// jaate hain kyunki colored bar usually dark hota hai.
  SystemUiOverlayStyle statusBarColored(Color color, {bool lightIcons = true}) =>
      SystemUiOverlayStyle(
        statusBarColor: color,
        statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      );
}

/// Context-free version of the semantic colors — `Get.isDarkMode` use karta hai.
/// Un helper methods ke liye jahan BuildContext available nahi hota.
/// Theme switch (Get.changeThemeMode) pe poora widget tree rebuild hota hai,
/// isliye ye values bhi update ho jaati hain.
class AppColor {
  AppColor._();

  static bool get _dark => Get.isDarkMode;

  static Color get scaffoldBg => _dark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
  static Color get cardBg => _dark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color get subtleBg => _dark ? const Color(0xFF262626) : const Color(0xFFF3F4F6);

  static Color get textPrimary => _dark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  static Color get textSecondary => _dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textTertiary => _dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  static Color get borderColor => _dark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);
  static Color get dividerColor => _dark ? const Color(0xFF2E2E2E) : const Color(0xFFEEEFF2);

  /// Default status bar — light theme mein white, dark theme mein dark (black).
  static SystemUiOverlayStyle get statusBar => SystemUiOverlayStyle(
        statusBarColor: _dark ? const Color(0xFF1E1E1E) : Colors.white,
        statusBarIconBrightness: _dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: _dark ? Brightness.dark : Brightness.light,
      );

  /// Fixed-color status bar (e.g. dashboard blue).
  static SystemUiOverlayStyle statusBarColored(Color color, {bool lightIcons = true}) =>
      SystemUiOverlayStyle(
        statusBarColor: color,
        statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      );

  // ── Severity / status accent helpers (theme-aware) ──────────────────────────
  // Colored cards (alerts, dashboard camera card, banners) ke liye — light mode
  // mein halka tinted-light, dark mode mein dark surface + colored tint. Web ke
  // `dark:bg-*-900/20` jaisa.

  /// Card / surface background for a severity accent.
  static Color tintedSurface(Color accent) => _dark
      ? Color.alphaBlend(accent.withValues(alpha: 0.16), const Color(0xFF1E1E1E))
      : Color.alphaBlend(accent.withValues(alpha: 0.10), Colors.white);

  /// Border for a severity accent.
  static Color accentBorder(Color accent) => accent.withValues(alpha: _dark ? 0.45 : 0.30);

  /// Readable text/icon color for a severity accent (light on dark, dark on light).
  static Color accentText(Color accent) => _dark
      ? Color.lerp(accent, Colors.white, 0.45)!
      : Color.lerp(accent, Colors.black, 0.28)!;

  /// Small badge background for a severity accent.
  static Color accentBadgeBg(Color accent) => accent.withValues(alpha: _dark ? 0.24 : 0.15);
}
