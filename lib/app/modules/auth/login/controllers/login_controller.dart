import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../routes/app_pages.dart';

class LoginController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final isLoading = false.obs;
  final obscurePassword = true.obs;

  void togglePasswordVisibility() => obscurePassword.value = !obscurePassword.value;

  Future<void> login(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    isLoading.value = true;
    try {
      final res = await _firestore.login(
        emailCtrl.text.trim(),
        passwordCtrl.text.trim(),
      );

      // Check for errors
      if (res.containsKey('error')) {
        throw Exception(res['error']);
      }

      // Firebase Auth handles token automatically, save token for API calls if needed
      final token = res['token'] as String?;
      if (token != null) {
        await _auth.saveTokens(
          accessToken: token,
          refreshToken: null,
        );
      }

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
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }
}
