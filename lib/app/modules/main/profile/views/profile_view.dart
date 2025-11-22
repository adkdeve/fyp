import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // bg-gray-50
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Picture
                    _buildProfilePicture(),
                    const SizedBox(height: 16),
                    // Personal Information
                    _buildPersonalInformation(),
                    const SizedBox(height: 16),
                    // Work Information
                    _buildWorkInformation(),
                    const SizedBox(height: 16),
                    // Account Stats
                    _buildAccountStats(),
                    const SizedBox(height: 16),
                    // Danger Zone
                    _buildDangerZone(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity, // Make header full width
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4B5563)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Text(
                  'Manage your account information',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            return Container(
              decoration: BoxDecoration(
                color: controller.isEditing.value
                    ? const Color(0xFF059669) // green-600
                    : const Color(0xFF2563EB), // blue-600
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: controller.isEditing.value
                    ? controller.saveProfile
                    : controller.toggleEditing,
                icon: Icon(
                  controller.isEditing.value ? Icons.save : Icons.edit,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Obx(() {
      return Container(
        width: double.infinity, // Make profile picture container full width
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  controller.getInitials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (controller.isEditing.value) ...[
              TextButton(
                onPressed: () {
                  // Handle change photo
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Change Photo'),
                      content: const Text('Photo change functionality would go here.'),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Change Photo',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildPersonalInformation() {
    return Container(
      width: double.infinity, // Make container full width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header - Fixed to take full width
          Container(
            width: double.infinity, // Make section header full width
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          // Form Fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFormField(
                  icon: Icons.person,
                  label: 'Full Name',
                  field: 'name',
                ),
                const SizedBox(height: 16),
                _buildFormField(
                  icon: Icons.person_outline,
                  label: 'Role',
                  field: 'role',
                ),
                const SizedBox(height: 16),
                _buildFormField(
                  icon: Icons.email,
                  label: 'Email',
                  field: 'email',
                ),
                const SizedBox(height: 16),
                _buildFormField(
                  icon: Icons.phone,
                  label: 'Phone Number',
                  field: 'phone',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkInformation() {
    return Container(
      width: double.infinity, // Make container full width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header - Fixed to take full width
          Container(
            width: double.infinity, // Make section header full width
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text(
              'Work Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          // Form Fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFormField(
                  icon: Icons.business,
                  label: 'Company',
                  field: 'company',
                ),
                const SizedBox(height: 16),
                _buildFormField(
                  icon: Icons.location_on,
                  label: 'Current Location',
                  field: 'location',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required String field,
  }) {
    return Obx(() {
      return SizedBox(
        width: double.infinity, // Make form field take full width
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            controller.isEditing.value
                ? TextFormField(
              initialValue: controller.formData[field],
              onChanged: (value) => controller.updateField(field, value),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            )
                : SizedBox(
              width: double.infinity, // Make text take full width
              child: Text(
                controller.formData[field]!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAccountStats() {
    return Container(
      width: double.infinity, // Make container full width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header - Fixed to take full width
          Container(
            width: double.infinity, // Make section header full width
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text(
              'Account Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          // Stats Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  value: '156',
                  label: 'Violations Resolved',
                  color: const Color(0xFFDBEAFE),
                  textColor: const Color(0xFF2563EB),
                ),
                _buildStatCard(
                  value: '89%',
                  label: 'Avg Response Rate',
                  color: const Color(0xFFDCFCE7),
                  textColor: const Color(0xFF16A34A),
                ),
                _buildStatCard(
                  value: '4',
                  label: 'Active Zones',
                  color: const Color(0xFFF3E8FF),
                  textColor: const Color(0xFF9333EA),
                ),
                _buildStatCard(
                  value: '2.3s',
                  label: 'Avg Response Time',
                  color: const Color(0xFFFFEDD5),
                  textColor: const Color(0xFFEA580C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      width: double.infinity, // Make container full width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header - Fixed to take full width
          Container(
            width: double.infinity, // Make section header full width
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              border: Border(bottom: BorderSide(color: Color(0xFFFECACA))),
            ),
            child: const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Change Password'),
                          content: const Text('Password change functionality would go here.'),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Change Password',
                      style: TextStyle(
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Delete Account'),
                          content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Get.back();
                                // Add account deletion logic here
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                    ),
                    child: const Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}