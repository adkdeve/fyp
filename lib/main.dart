import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'app/data/services/auth_service.dart';
import 'app/routes/app_pages.dart';
import 'app/core/core.dart';
import 'binding/app_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Check token before launching UI
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();

  final String initialRoute = isLoggedIn ? AppPages.INITIAL : Routes.LOGIN;

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
