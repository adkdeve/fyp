import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/helpsupport_controller.dart';

class HelpSupportView extends GetView<HelpSupportController> {
  const HelpSupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Content - Fixed with Expanded and proper scrolling
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Back button and title
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help & Support',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                    Text('Get answers and assistance', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Bar
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: controller.searchController,
      decoration: InputDecoration(
        hintText: 'Search help articles...',
        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Contact Support
          _buildContactSupport(),
          const SizedBox(height: 16),
          // Resources
          _buildResources(),
          const SizedBox(height: 16),
          // FAQs
          _buildFAQs(),
          const SizedBox(height: 16),
          // App Version
          _buildAppVersion(),
        ],
      ),
    );
  }

  Widget _buildContactSupport() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text(
              'Contact Support',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
            ),
          ),
          // Contact Options
          Column(
            children: [
              _buildContactOption(
                icon: Icons.email,
                title: 'Email Support',
                subtitle: 'Response within 24 hours',
                color: const Color(0xFF3B82F6),
                backgroundColor: const Color(0xFFDBEAFE),
                onTap: () => controller.handleContactSupport('email'),
              ),
              _buildContactOption(
                icon: Icons.phone,
                title: 'Phone Support',
                subtitle: 'Available 24/7',
                color: const Color(0xFF10B981),
                backgroundColor: const Color(0xFFD1FAE5),
                onTap: () => controller.handleContactSupport('phone'),
              ),
              _buildContactOption(
                icon: Icons.chat,
                title: 'Live Chat',
                subtitle: 'Instant assistance',
                color: const Color(0xFF8B5CF6),
                backgroundColor: const Color(0xFFEDE9FE),
                onTap: () => controller.handleContactSupport('chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildResources() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text(
              'Resources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
            ),
          ),
          // Resource Options
          Column(
            children: [
              _buildResourceOption(
                icon: Icons.menu_book,
                title: 'User Guide',
                subtitle: 'Complete documentation',
                color: const Color(0xFFF59E0B),
                backgroundColor: const Color(0xFFFEF3C7),
                onTap: () => controller.handleResource('guide'),
              ),
              _buildResourceOption(
                icon: Icons.videocam,
                title: 'Video Tutorials',
                subtitle: 'Step-by-step guides',
                color: const Color(0xFFEF4444),
                backgroundColor: const Color(0xFFFEE2E2),
                onTap: () => controller.handleResource('tutorials'),
              ),
              _buildResourceOption(
                icon: Icons.description,
                title: 'Safety Guidelines',
                subtitle: 'Best practices & protocols',
                color: const Color(0xFF14B8A6),
                backgroundColor: const Color(0xFFCCFBF1),
                onTap: () => controller.handleResource('guidelines'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildFAQs() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline, size: 20, color: Color(0xFF111827)),
                SizedBox(width: 8),
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
          // FAQ List - Fixed with proper Obx usage
          Obx(() => _buildFAQList()),
        ],
      ),
    );
  }

  Widget _buildFAQList() {
    final filteredFaqs = controller.filteredFaqs;

    if (filteredFaqs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No FAQs found matching your search.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      );
    }

    return Column(
      children: List.generate(filteredFaqs.length, (index) {
        final faq = filteredFaqs[index];
        final isExpanded = controller.expandedFaqIndex.value == index;

        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () => controller.toggleFaq(index),
                title: Text(faq['question']!, style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
                trailing: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              if (isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(faq['answer']!, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAppVersion() {
    return const Column(
      children: [
        Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        SizedBox(height: 4),
        Text('Last updated: Nov 19, 2024', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}
