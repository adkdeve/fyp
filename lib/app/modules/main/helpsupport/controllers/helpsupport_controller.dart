import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HelpSupportController extends GetxController {
  // Reactive variables
  var searchQuery = ''.obs;
  var expandedFaqIndex = Rx<int?>(null);
  var isLoading = false.obs;
  final searchController = TextEditingController();

  // FAQ data
  final List<Map<String, String>> faqs = [
    {
      'question': 'How does AI detection work?',
      'answer':
          'Our system uses YOLO and Mask R-CNN deep learning models to analyze live video feeds in real-time. The AI identifies safety violations such as missing PPE, unauthorized access, and hazardous zone intrusions with 90%+ accuracy.',
    },
    {
      'question': 'What happens when a violation is detected?',
      'answer':
          'When a violation is detected, the system immediately sends alerts to supervisors via the mobile app. The violation is logged with timestamp, location, and visual evidence for compliance tracking.',
    },
    {
      'question': 'How fast are alerts delivered?',
      'answer':
          'Alerts are typically delivered within 2-3 seconds of violation detection, ensuring rapid response times for critical safety incidents.',
    },
    {
      'question': 'Can I customize notification settings?',
      'answer':
          'Yes. You can customize critical and medium alerts in the Settings > Notifications section.',
    },
    {
      'question': 'How do I add new cameras?',
      'answer':
          'Go to Settings > Camera Management and tap the \'+\' button. Follow the setup wizard to configure your new camera and deploy AI detection models.',
    },
    {
      'question': 'What PPE violations can be detected?',
      'answer':
          'The system can detect missing hard hats, safety vests, gloves, safety glasses, harnesses, and other required personal protective equipment.',
    },
    {
      'question': 'How is data stored and secured?',
      'answer':
          'All violation data is encrypted and stored in a secure cloud database with local backup. Only authorized personnel can access the records.',
    },
    {
      'question': 'Can I export violation reports?',
      'answer':
          'Yes! You can export violation history to CSV format from the History screen for compliance audits and safety reviews.',
    },
  ];

  // Get filtered FAQs based on search query
  List<Map<String, String>> get filteredFaqs {
    if (searchQuery.isEmpty) return faqs;

    final query = searchQuery.value.toLowerCase();
    return faqs.where((faq) {
      final question = faq['question']!.toLowerCase();
      final answer = faq['answer']!.toLowerCase();

      return question.contains(query) || answer.contains(query);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_handleSearchChanged);
  }

  @override
  void onClose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    super.onClose();
  }

  // Toggle FAQ expansion
  void toggleFaq(int index) {
    if (expandedFaqIndex.value == index) {
      expandedFaqIndex.value = null;
    } else {
      expandedFaqIndex.value = index;
    }
  }

  void _handleSearchChanged() {
    updateSearchQuery(searchController.text);
  }

  // Update search query
  void updateSearchQuery(String query) {
    if (searchQuery.value == query) return;
    searchQuery.value = query;
  }

  // Handle contact support methods
  void handleContactSupport(String method) {
    switch (method) {
      case 'email':
        _openDetail(
          'Email Support',
          'Email: support@constructionsafety.com\nResponse within 24 hours.',
        );
        break;

      case 'phone':
        _openDetail(
          'Phone Support',
          'Phone: 1-800-SAFETY-1\n(1-800-723-3891)\nAvailable 24/7.',
        );
        break;

      case 'chat':
        _openDetail(
          'Live Chat',
          'Live chat requests are logged inside the app.\nA support agent will respond from the operations desk.',
        );
        break;
    }
  }

  // Handle resource buttons
  void handleResource(String resource) {
    switch (resource) {
      case 'guide':
        _openDetail(
          'User Guide',
          '1. Add cameras from Settings > Camera Management.\n2. Open Dashboard to monitor live feeds.\n3. Review alerts and acknowledge or resolve violations.\n4. Use History and Analytics for reports.',
        );
        break;

      case 'tutorials':
        _openDetail(
          'Video Tutorials',
          'Tutorial 1: Connect a camera.\nTutorial 2: Review a safety alert.\nTutorial 3: Export safety reports.',
        );
        break;

      case 'guidelines':
        _openDetail(
          'Safety Guidelines',
          'Workers must wear required PPE, avoid restricted zones, keep paths clear, and report hazards immediately.',
        );
        break;
    }
  }

  void _openDetail(String title, String body) {
    Get.to(
      () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(body, style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
      ),
    );
  }
}
