import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';
import '../../../../routes/app_pages.dart';

class LoginController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;
  final AuthService _auth = Get.find<AuthService>();

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final obscurePassword = true.obs;

  void togglePasswordVisibility() => obscurePassword.value = !obscurePassword.value;

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      final res = await _api.login(
        emailCtrl.text.trim(),
        passwordCtrl.text.trim(),
      );
      // Save tokens
      await _auth.saveTokens(
        accessToken: res['access_token'] as String,
        refreshToken: res['refresh_token'] as String?,
      );
      // Save user data
      if (res['user'] != null) {
        await _auth.saveUserData(res['user'] as Map<String, dynamic>);
      }
      Get.offAllNamed(AppPages.INITIAL);
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error.withOpacity(0.9),
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }
}
