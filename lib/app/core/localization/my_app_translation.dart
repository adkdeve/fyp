import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import 'locales.g.dart';

class MyAppTranslation extends Translations {
  static const Locale defaultLocale = AppConfig.defaultLocale;

  static  List<Locale> supportedLocales = AppConfig.supportedLocales;

  @override
  Map<String, Map<String, String>> get keys => AppTranslation.translations;

  /// Change language at runtime
  static void changeLanguage(Locale locale) {
    Get.updateLocale(locale);
  }
}

// /// Wrapper to avoid conflict with generated class
// class AppTranslationKeys {
//   static Map<String, Map<String, String>> translations = {
//     'en_US': Locales.en_Us, // fix key from 'en_Us' to 'en_US'
//   };
// }
