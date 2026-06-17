import 'package:flutter/material.dart';

class AppConfig {
  // ───── App Info ─────
  static const String appName = 'SafeSite AI';
  static const String version = '1.0.0';
  static const String buildNumber = '100';
  static const bool isDebugMode = false;

  static ThemeMode appDefaultTheme = ThemeMode.light;

  // ───── API Config ─────
  // Change this IP when your backend machine IP changes.
  static const String backendHost = 'my-unique-fastapi-backend.loca.lt';
  static const int backendPort = 8000;

  static String get baseUrl => 'https://$backendHost/api/v1/';

  static String get imageBaseUrl => 'https://$backendHost';

  static String get wsBaseUrl => 'wss://$backendHost/ws';

  static const bool enableMockFallback = false;

  static const Duration apiTimeout = Duration(seconds: 15);
  static const int paginationLimit = 10;

  // ───── Feature Flags ─────
  static const bool enablePayments = true;
  static const bool enablePushNotifications = true;
  static const bool enableBiometrics = true;
  static const bool useSecureStorage = true;

  // ───── UI Defaults ─────
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0;

  /// Default Locale
  static const Locale defaultLocale = Locale('en', 'US');

  /// Supported Locales
  static final List<Locale> supportedLocales = [const Locale('en', 'US'), const Locale('ur', 'PK')];
}
