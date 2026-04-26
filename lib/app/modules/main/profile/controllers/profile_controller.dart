import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';

class ProfileController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;
  final AuthService _auth = Get.find<AuthService>();

  var isEditing = false.obs;
  var isLoading = false.obs;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // Derived display data
  final formData = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final user = await _api.getMe();
      final name = user['name'] as String? ?? '';
      final email = user['email'] as String? ?? '';
      nameCtrl.text = name;
      emailCtrl.text = email;
      formData.assignAll({
        'name': name,
        'email': email,
        'role': user['role'] as String? ?? 'supervisor',
        'phone': user['phone'] as String? ?? '',
      });
      // Cache locally
      await _auth.saveUserData(user);
    } catch (e) {
      // Fallback to cached data
      final cached = await _auth.getUserData();
      if (cached != null) {
        final fullName = '${cached.firstName} ${cached.lastName}'.trim();
        nameCtrl.text = fullName;
        emailCtrl.text = cached.email;
        formData.assignAll({
          'name': fullName,
          'email': cached.email,
          'role': 'supervisor',
          'phone': cached.phoneNumber ?? '',
        });
      }
    } finally {
      isLoading.value = false;
    }
  }

  void toggleEditing() => isEditing.value = !isEditing.value;

  Future<void> saveProfile() async {
    isLoading.value = true;
    try {
      final updated = await _api.updateMe({
        'name': nameCtrl.text.trim(),
      });
      formData['name'] = updated['name'] as String? ?? nameCtrl.text.trim();
      await _auth.saveUserData(updated);
      isEditing.value = false;
      Get.dialog(AlertDialog(
        title: const Text('Success'),
        content: const Text('Profile updated successfully!'),
        actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
      ));
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void updateField(String field, String value) {
    formData[field] = value;
    formData.refresh();
  }

  String getInitials() {
    final name = formData['name'] ?? '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'S';
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }
}
