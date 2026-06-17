import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';
import '../controllers/termsprivacy_controller.dart';

class TermsPrivacyView extends GetView<TermsPrivacyController> {
  const TermsPrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColor.statusBar,
      child: Scaffold(
        backgroundColor: AppColor.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Legal',
                subtitle: 'Terms of Service & Privacy Policy',
                showBack: true,
                bottom: Obx(
                  () => Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          text: 'Terms of Service',
                          isActive: controller.activeTab.value == 'terms',
                          onTap: () => controller.switchTab('terms'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTabButton(
                          text: 'Privacy Policy',
                          isActive: controller.activeTab.value == 'privacy',
                          onTap: () => controller.switchTab('privacy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Tab Content
                      Obx(() => controller.activeTab.value == 'terms' ? _buildTermsContent() : _buildPrivacyContent()),
                      // Accept Button
                      _buildAcceptButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({required String text, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFDBEAFE) : AppColor.subtleBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? const Color(0xFF1D4ED8) : AppColor.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.borderColor),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildSectionHeader(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Last updated: November 19, 2024',
            color: const Color(0xFF3B82F6),
            backgroundColor: const Color(0xFFDBEAFE),
          ),
          const SizedBox(height: 24),
          // Sections
          _buildTermsSection(
            title: '1. Acceptance of Terms',
            content:
                'By accessing and using the AI Construction Site Safety Monitor application ("the Service"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to these terms, please do not use the Service.',
          ),
          const SizedBox(height: 20),
          _buildTermsSection(
            title: '2. Use License',
            content:
                'Permission is granted to use the Service for construction site safety monitoring purposes under the following conditions:',
            bulletPoints: [
              'The Service is used solely for workplace safety monitoring',
              'You maintain the confidentiality of your account credentials',
              'You comply with all applicable safety regulations and laws',
              'You do not attempt to reverse engineer or hack the AI detection system',
            ],
          ),
          const SizedBox(height: 20),
          _buildTermsSection(
            title: '3. AI Detection Disclaimer',
            content:
                'While our AI-powered detection system achieves high accuracy rates (90%+), it should not replace human supervision and judgment. The Service is designed to assist safety monitoring, not replace comprehensive safety protocols. Users are responsible for verifying all violations and taking appropriate action.',
          ),
          const SizedBox(height: 20),
          _buildTermsSection(
            title: '4. Data Collection and Camera Use',
            content:
                'You agree that the Service will collect video footage and safety violation data from construction sites. All parties working on monitored sites must be informed of camera surveillance and AI monitoring in compliance with local privacy laws.',
          ),
          const SizedBox(height: 20),
          _buildTermsSection(
            title: '5. Limitation of Liability',
            content:
                'The Service providers shall not be held liable for any incidents, accidents, or safety violations that occur despite the use of the monitoring system. The Service is a tool to enhance safety, not guarantee it.',
          ),
          const SizedBox(height: 20),
          _buildTermsSection(
            title: '6. Service Modifications',
            content:
                'We reserve the right to modify or discontinue the Service at any time without notice. We may also update these terms periodically, and continued use of the Service constitutes acceptance of modified terms.',
          ),
          const SizedBox(height: 20),
          _buildTermsSection(
            title: '7. Account Termination',
            content:
                'We may terminate or suspend your account and access to the Service immediately, without prior notice or liability, for any reason, including breach of these Terms.',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.borderColor),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildSectionHeader(
            icon: Icons.security,
            title: 'Privacy Policy',
            subtitle: 'Last updated: November 19, 2024',
            color: const Color(0xFF10B981),
            backgroundColor: const Color(0xFFD1FAE5),
          ),
          const SizedBox(height: 24),
          // Sections
          _buildPrivacySection(
            title: '1. Information We Collect',
            content: 'We collect the following types of information:',
            bulletPoints: [
              'Video Footage: Live camera feeds from construction sites',
              'Violation Data: Detected safety violations with timestamps and locations',
              'User Information: Name, email, role, and company details',
              'Device Information: Mobile device type, OS version, and app usage data',
              'Location Data: Construction site locations and zone information',
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '2. How We Use Your Information',
            content: 'Your information is used to:',
            bulletPoints: [
              'Detect and alert you to safety violations in real-time',
              'Generate safety compliance reports and analytics',
              'Improve our AI detection algorithms',
              'Send notifications about violations and system updates',
              'Maintain records for regulatory compliance',
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '3. Data Security',
            icon: Icons.lock,
            content: 'We implement industry-standard security measures to protect your data:',
            bulletPoints: [
              'End-to-end encryption for all video feeds',
              'Secure cloud storage with redundant backups',
              'Access controls and authentication protocols',
              'Regular security audits and updates',
              'Compliance with GDPR and CCPA regulations',
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '4. Data Retention',
            content:
                'Violation records and video footage are retained for a minimum of 90 days and up to 7 years depending on regulatory requirements and your subscription plan. You can request data deletion at any time, subject to legal obligations.',
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '5. Data Sharing',
            content: 'We do not sell your personal information. Data may be shared with:',
            bulletPoints: [
              'Authorized team members within your organization',
              'Regulatory authorities when legally required',
              'Third-party service providers under strict confidentiality agreements',
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '6. Your Rights',
            icon: Icons.visibility,
            content: 'You have the right to:',
            bulletPoints: [
              'Access your personal data and violation records',
              'Request correction of inaccurate information',
              'Request deletion of your data (subject to legal requirements)',
              'Opt-out of non-essential notifications',
              'Export your data in a portable format',
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '7. Cookies and Tracking',
            content:
                'We use minimal tracking technologies to improve app performance and user experience. You can manage cookie preferences in your device settings.',
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(
            title: '8. Contact Us',
            content: 'For privacy-related questions or to exercise your rights, contact us at:',
            additionalContent: 'privacy@constructionsafety.com',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color backgroundColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
              ),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection({required String title, required String content, List<String>? bulletPoints}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 14, color: AppColor.textSecondary, height: 1.5)),
        if (bulletPoints != null) ...[
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bulletPoints.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•', style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(point, style: TextStyle(fontSize: 14, color: AppColor.textSecondary, height: 1.5)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySection({
    required String title,
    required String content,
    List<String>? bulletPoints,
    IconData? icon,
    String? additionalContent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: AppColor.textPrimary), const SizedBox(width: 8)],
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 14, color: AppColor.textSecondary, height: 1.5)),
        if (bulletPoints != null) ...[
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bulletPoints.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•', style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(point, style: TextStyle(fontSize: 14, color: AppColor.textSecondary, height: 1.5)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        if (additionalContent != null) ...[
          const SizedBox(height: 8),
          Text(additionalContent, style: const TextStyle(fontSize: 14, color: Color(0xFF3B82F6), height: 1.5)),
        ],
      ],
    );
  }

  Widget _buildAcceptButton() {
    return Obx(() {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColor.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By using this application, you acknowledge that you have read and understood our ${controller.activeTab.value == 'terms' ? 'Terms of Service' : 'Privacy Policy'}.',
              style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.handleAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'I Understand and Accept',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
