import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/data/services/auth_service.dart';
import 'app/data/services/notification_service.dart';
import 'app/data/services/notification_prefs.dart';
import 'app/routes/app_pages.dart';
import 'app/core/core.dart';
import 'binding/app_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase may already be initialized or config missing
    print('Firebase initialization error: $e');
  }

  // Local notifications (naye violation par phone notification)
  await NotificationService.to.init();
  await NotificationPrefs.to.load();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  // Restore saved dark-mode preference (Settings > Display)
  try {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode') ?? false;
    AppConfig.appDefaultTheme = darkMode ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {}

  R.theme.applySystemUIOverlayStyle(AppConfig.appDefaultTheme);

  // Check token/session before launching UI
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  final synced = isLoggedIn ? await authService.syncUserSession() : null;
  final String initialRoute = (isLoggedIn && synced != null) ? AppPages.INITIAL : Routes.LOGIN;

  if (isLoggedIn && synced == null) {
    // If session is stale or user is inactive, clear all auth state.
    await authService.logout();
  }

  runApp(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: AppConfig.appName,
          initialBinding: AppBinding(),
          debugShowCheckedModeBanner: false,
          builder: EasyLoading.init(),
          defaultTransition: Transition.rightToLeft,
          // Localization
          translations: MyAppTranslation(),
          locale: AppConfig.defaultLocale,
          fallbackLocale: AppConfig.defaultLocale,
          supportedLocales: MyAppTranslation.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // Theme
          themeMode: AppConfig.appDefaultTheme,
          theme: R.theme.light,
          darkTheme: R.theme.dark,
          // Routing
          initialRoute: initialRoute,
          getPages: AppPages.routes,
        );
      },
    ),
  );
}
