import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../routes/app_pages.dart';

class ProfileController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();

  final isEditing = false.obs;
  final isLoading = false.obs;
  final avatarRefreshKey = 0.obs;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final roleCtrl = TextEditingController();
  final companyCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final changePasswordCurrentCtrl = TextEditingController();
  final changePasswordNewCtrl = TextEditingController();

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
      final user = await _firestore.getMe();
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
      final stats = await _firestore.getSummary(30);
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
    final role = user['role']?.toString() ?? 'supervisor';
    final phone = (user['phone'] ?? user['phone_number'])?.toString() ?? '';
    final company = user['company']?.toString() ?? '';
    final location = user['location']?.toString() ?? '';
    nameCtrl.text = name;
    emailCtrl.text = email;
    phoneCtrl.text = phone;
    roleCtrl.text = role;
    companyCtrl.text = company;
    locationCtrl.text = location;
    formData.assignAll({
      ...formData,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'company': company,
      'location': location,
      'avatar_url': (user['avatar_url'] ?? user['image'])?.toString() ?? '',
    });
  }

  void toggleEditing() => isEditing.value = !isEditing.value;

  Future<void> saveProfile() async {
    isLoading.value = true;
    try {
      final updated = await _firestore.updateMe({
        'full_name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'company': companyCtrl.text.trim(),
        'location': locationCtrl.text.trim(),
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
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;
    try {
      final updated = await _firestore.uploadAvatar(File(picked.path));
      _applyUser(updated);
      avatarRefreshKey.value++;
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
    changePasswordCurrentCtrl.clear();
    changePasswordNewCtrl.clear();
    Get.dialog(
      AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: changePasswordCurrentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: changePasswordNewCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Get.back();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final currentPassword = changePasswordCurrentCtrl.text;
              final newPassword = changePasswordNewCtrl.text;
              FocusManager.instance.primaryFocus?.unfocus();
              Get.back();
              await changePassword(currentPassword, newPassword);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      changePasswordCurrentCtrl.clear();
      changePasswordNewCtrl.clear();
    });
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _firestore.changePassword(currentPassword, newPassword);
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
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Get.back();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              Get.back();
              await Future<void>.delayed(const Duration(milliseconds: 50));
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
      await _firestore.deleteAccount();
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

  TextEditingController controllerForField(String field) {
    switch (field) {
      case 'name':
        return nameCtrl;
      case 'email':
        return emailCtrl;
      case 'phone':
        return phoneCtrl;
      case 'role':
        return roleCtrl;
      case 'company':
        return companyCtrl;
      case 'location':
        return locationCtrl;
      default:
        throw ArgumentError('Unknown profile field: $field');
    }
  }

  bool isFieldEditable(String field) {
    switch (field) {
      case 'email':
      case 'role':
        return false;
      default:
        return true;
    }
  }

  String getInitials() {
    final name = formData['name'] ?? '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }

  String? get resolvedAvatarUrl {
    final raw = formData['avatar_url']?.trim() ?? '';
    if (raw.isEmpty) return null;

    String resolved;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      resolved = raw;
    } else if (raw.startsWith('/')) {
      resolved = '${AppConfig.imageBaseUrl}$raw';
    } else {
      resolved = '${AppConfig.imageBaseUrl}/$raw';
    }

    final separator = resolved.contains('?') ? '&' : '?';
    return '$resolved${separator}v=${avatarRefreshKey.value}';
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    roleCtrl.dispose();
    companyCtrl.dispose();
    locationCtrl.dispose();
    changePasswordCurrentCtrl.dispose();
    changePasswordNewCtrl.dispose();
    super.onClose();
  }
}
