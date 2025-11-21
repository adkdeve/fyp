import 'package:flutter/material.dart';

class AppConfig {
  // ───── App Info ─────
  static const String appName = 'Construction Site Safety';
  static const String version = '1.0.0';
  static const String buildNumber = '100';
  static const bool isDebugMode = false;

  static ThemeMode appDefaultTheme = ThemeMode.light;

  // ───── API Config ─────
  static const String baseUrl = 'https://pillojobfinder.devitcity.com/api/';
  static const String imageBaseUrl = 'https://pillojobfinder.devitcity.com/storage/';

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

  // ───── Third-Party Keys ─────
  static const String stripePublicKey = 'pk_test_1234567890';
  static const String firebaseSenderId = 'YOUR_FIREBASE_SENDER_ID';

  /// Default Locale
  static const Locale defaultLocale = Locale('en', 'US');

  /// Supported Locales
  static final List<Locale> supportedLocales = [
    const Locale('en', 'US'),
    const Locale('ur', 'PK'),
  ];
}
