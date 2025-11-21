import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfileController extends GetxController {
  // Reactive variables
  var isEditing = false.obs;
  var formData = {
    'name': 'John Doe',
    'role': 'Site Supervisor',
    'email': 'john.doe@construction.com',
    'phone': '+1 (555) 123-4567',
    'company': 'BuildSafe Construction Inc.',
    'location': 'Project Site Alpha - Downtown',
  }.obs;

  // Toggle edit mode
  void toggleEditing() {
    isEditing.value = !isEditing.value;
  }

  // Save profile changes
  void saveProfile() {
    isEditing.value = false;
    Get.dialog(
      AlertDialog(
        title: const Text('Success'),
        content: const Text('Profile updated successfully!'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Update form field
  void updateField(String field, String value) {
    formData[field] = value;
    formData.refresh();
  }

  // Get initials for profile picture
  String getInitials() {
    final names = formData['name']!.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return names[0][0].toUpperCase();
  }
}