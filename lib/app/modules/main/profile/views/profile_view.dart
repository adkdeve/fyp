import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ProfileController());
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColor.statusBar,
      child: Scaffold(
        backgroundColor: AppColor.scaffoldBg,
        body: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value && controller.formData['name']!.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(
                  title: 'My Profile',
                  subtitle: 'View and manage your account information',
                  showBack: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Identity Card
                        _buildIdentityCard(),
                        const SizedBox(height: 16),
                        // Account Details
                        _buildContactInfoCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    final status = controller.formData['status'] ?? 'inactive';
    final isActive = status.toLowerCase() == 'active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Circle
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  ),
                ),
                child: Center(
                  child: Text(
                    controller.getInitials(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name, Role & Status Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            controller.formData['name'] ?? 'Unknown Officer',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive ? const Color(0xFF16A34A) : AppColor.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Safety Officer', style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColor.borderColor.withOpacity(0.8), height: 1),
          ),

          // Meta Info (Sites Assigned & Login ID)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: AppColor.textTertiary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sites Assigned', style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                        Text(
                          '${controller.formData['site_count']} site(s)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColor.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: AppColor.textTertiary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Login ID', style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                        Text(
                          controller.formData['loginId'] ?? '—',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColor.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  'Account Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
                ),
              ],
            ),
          ),
          Divider(color: AppColor.borderColor.withOpacity(0.8), height: 1),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReadOnlyRow(icon: Icons.mail_outline, label: 'Email', value: controller.formData['email']),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColor.borderColor.withOpacity(0.5), height: 1),
                ),
                _buildReadOnlyRow(icon: Icons.phone_outlined, label: 'Phone', value: controller.formData['phone']),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColor.borderColor.withOpacity(0.5), height: 1),
                ),
                _buildReadOnlyRow(icon: Icons.login, label: 'Login ID', value: controller.formData['loginId']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController textController,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColor.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: textController,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: AppColor.textPrimary),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColor.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyRow({required IconData icon, required String label, required String? value}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColor.textTertiary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
            const SizedBox(height: 2),
            Text(
              (value == null || value.trim().isEmpty) ? '—' : value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColor.textPrimary),
            ),
          ],
        ),
      ],
    );
  }
}
