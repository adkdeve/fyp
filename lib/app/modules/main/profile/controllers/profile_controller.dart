import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';
import '../../../../routes/app_pages.dart';

class ProfileController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;
  final AuthService _auth = Get.find<AuthService>();

  final isEditing = false.obs;
  final isLoading = false.obs;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final formData = <String, String>{
    'name': '',
    'role': '',
    'email': '',
    'phone': '',
    'company': '',
    'location': '',
    'avatar_url': '',
    'violations_resolved': '0',
    'avg_response_rate': '0%',
    'active_zones': '0',
    'avg_response_time': '0.0s',
  }.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
    fetchStats();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final user = await _api.getMe();
      _applyUser(user);
      await _auth.saveUserData(user);
    } catch (_) {
      final cached = await _auth.getUserData();
      if (cached != null) {
        _applyUser(cached.toJson());
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchStats() async {
    try {
      final stats = await _api.getSummary(days: 30);
      formData['violations_resolved'] = '${stats['resolved'] ?? 0}';
      formData['active_zones'] = '${stats['active_zones'] ?? 0}';
      formData['avg_response_time'] = '${stats['avg_response_time'] ?? 0.0}s';
      final total = (stats['total_violations'] as int?) ?? 0;
      final resolved = (stats['resolved'] as int?) ?? 0;
      formData['avg_response_rate'] = total == 0
          ? '100%'
          : '${((resolved / total) * 100).round()}%';
      formData.refresh();
    } catch (_) {}
  }

  void _applyUser(Map<String, dynamic> user) {
    final name = (user['full_name'] ?? user['name'])?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final phone = (user['phone'] ?? user['phone_number'])?.toString() ?? '';
    nameCtrl.text = name;
    emailCtrl.text = email;
    phoneCtrl.text = phone;
    formData.assignAll({
      ...formData,
      'name': name,
      'email': email,
      'role': user['role']?.toString() ?? 'supervisor',
      'phone': phone,
      'company': user['company']?.toString() ?? '',
      'location': user['location']?.toString() ?? '',
      'avatar_url': (user['avatar_url'] ?? user['image'])?.toString() ?? '',
    });
  }

  void toggleEditing() => isEditing.value = !isEditing.value;

  Future<void> saveProfile() async {
    isLoading.value = true;
    try {
      final updated = await _api.updateMe({
        'full_name': formData['name']?.trim() ?? nameCtrl.text.trim(),
        'phone': formData['phone']?.trim() ?? phoneCtrl.text.trim(),
        'company': formData['company']?.trim(),
        'location': formData['location']?.trim(),
      });
      _applyUser(updated);
      await _auth.saveUserData(updated);
      isEditing.value = false;
      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> changePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final updated = await _api.uploadAvatar(File(picked.path));
      _applyUser(updated);
      await _auth.saveUserData(updated);
      Get.snackbar(
        'Success',
        'Profile photo updated',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  void showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await changePassword(currentCtrl.text, newCtrl.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _api.changePassword(currentPassword, newPassword);
      Get.snackbar(
        'Success',
        'Password updated',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  void showDeleteAccountDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This will disable your account and sign you out.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> deleteAccount() async {
    try {
      await _api.deleteAccount();
      await _auth.logout();
      Get.offAllNamed(Routes.LOGIN);
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  void updateField(String field, String value) {
    formData[field] = value;
    formData.refresh();
  }

  String getInitials() {
    final name = formData['name'] ?? '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }
}
