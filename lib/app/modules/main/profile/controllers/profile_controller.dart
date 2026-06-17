import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../routes/app_pages.dart';

// Terminal (flutter run) mein clearly nazar aane wali debug helper.
// dart:developer ki log() output sirf DevTools mein jati hai, isliye debugPrint use kar rahe hain.
void _d(String message) => debugPrint('[PROFILE_DEBUG] $message');

class ProfileController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();

  final isEditing = false.obs;
  final isLoading = false.obs;
  final avatarRefreshKey = 0.obs;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final formData = <String, String>{
    'name': '',
    'email': '',
    'phone': '',
    'avatar_url': '',
    'status': 'inactive',
    'loginId': '—',
    'site_count': '0',
  }.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      _d("");
      _d("===================== PROFILE DEBUG START =====================");

      // 1. Load cached user data and raw storage map
      final cached = await _auth.getUserData();
      final rawCache = await _auth.getRawUserData();

      if (cached == null) {
        _d("🚨 WARNING: Cache mein user ka koi data nahi mila (AuthService.getUserData() is NULL)");
      } else {
        _d("✅ CACHE DATA FOUND: ID = ${cached.id}, Email = ${cached.email}");
        _applyUser(cached.toJson());
      }

      if (cached == null && rawCache != null) {
        _d("ℹ️ Raw cache mil gaya, applying raw map until model fix is confirmed.");
        _applyUser(rawCache);
      }

      // 2. Fetch live data from Firestore using the saved officer ID
      final targetId = cached?.id.isNotEmpty == true ? cached!.id : _parseRawId(rawCache);
      if (targetId != null && targetId.isNotEmpty) {
        _d("🔄 Fetching from Firestore for ID: '$targetId'...");

        final liveUser = await _firestore.getOfficerMe(targetId);
        if (liveUser == null) {
          _d("🚨 ERROR: Firestore returned NULL. Is ID ka koi document 'officers' collection mein nahi mila.");
        } else if (liveUser.containsKey('error')) {
          _d("🚨 FIRESTORE EXCEPTION: ${liveUser['error']}");
        } else {
          _d("🎉 SUCCESS: Firestore se raw data mil gaya!");
          _applyUser(liveUser);
          await _auth.saveUserData(liveUser);
        }
      } else {
        _d("🚨 ERROR: Unable to determine officer ID from cached data or raw storage.");
      }
    } catch (e, stacktrace) {
      _d("💥 CRITICAL EXCEPTION in fetchProfile: $e");
      _d("STACKTRACE: $stacktrace");
    } finally {
      isLoading.value = false;
      _d("====================== PROFILE DEBUG END ======================");
      _d("");
    }
  }

  String? _parseRawId(Map<String, dynamic>? rawData) {
    if (rawData == null) return null;
    if (rawData['id'] != null) return rawData['id'].toString();
    if (rawData['uid'] != null) return rawData['uid'].toString();
    return null;
  }

  void _applyUser(Map<String, dynamic> user) {
    // Pure map ko clear print karna taake hum keys check kar sakein
    _d("📦 RAW MAP DATA: $user");

    final name = (user['name'] ?? user['full_name'] ?? user['username'] ?? '—').toString();
    final email = (user['email'] ?? '—').toString();
    final phone = (user['phone'] ?? '—').toString();
    final status = (user['status'] ?? 'inactive').toString();
    final loginId = (user['loginId'] ?? user['login_id'] ?? '—').toString();

    var siteCount = '0';
    if (user['siteIds'] != null && user['siteIds'] is List) {
      siteCount = '${(user['siteIds'] as List).length}';
    } else if (user['site_ids'] != null && user['site_ids'] is List) {
      siteCount = '${(user['site_ids'] as List).length}';
    }

    _d("🔍 MAPPED FIELDS -> Name: $name, Email: $email, Phone: $phone, Status: $status, LoginID: $loginId, Sites: $siteCount");

    nameCtrl.text = name == '—' ? '' : name;
    emailCtrl.text = email == '—' ? '' : email;
    phoneCtrl.text = phone == '—' ? '' : phone;

    formData.assignAll({
      'name': name,
      'email': email,
      'phone': phone,
      'status': status,
      'loginId': loginId,
      'site_count': siteCount,
      'avatar_url': (user['avatar_url'] ?? user['image'] ?? '').toString(),
    });

    formData.refresh();
  }

  void toggleEditing() {
    if (isEditing.value) {
      // If cancelling, reset values
      final email = formData['email'] ?? '';
      final phone = formData['phone'] ?? '';
      emailCtrl.text = email;
      phoneCtrl.text = phone;
    }
    isEditing.value = !isEditing.value;
  }

  Future<void> saveProfile() async {
    isLoading.value = true;
    try {
      final cached = await _auth.getUserData();
      if (cached?.id == null) return;

      final updatedData = {'email': emailCtrl.text.trim(), 'phone': phoneCtrl.text.trim()};

      // Update in Firestore
      await _firestore.updateOfficerProfile(cached!.id.toString(), updatedData);

      // Update Local State & Cache
      formData['email'] = updatedData['email']!;
      formData['phone'] = updatedData['phone']!;
      formData.refresh();

      final currentFullData = cached.toJson();
      currentFullData['email'] = updatedData['email'];
      currentFullData['phone'] = updatedData['phone'];
      await _auth.saveUserData(currentFullData);

      isEditing.value = false;
      SnackBarUtils.showSnackBar('Profile updated successfully', title: 'Success');
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Error');
    } finally {
      isLoading.value = false;
    }
  }

  String getInitials() {
    final name = formData['name'] ?? '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '??';
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }
}
