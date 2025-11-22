import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HelpSupportController extends GetxController {
  // Reactive variables
  var searchQuery = ''.obs;
  var expandedFaqIndex = Rx<int?>(null);
  var isLoading = false.obs;

  // FAQ data
  final List<Map<String, String>> faqs = [
    {
      'question': 'How does AI detection work?',
      'answer': 'Our system uses YOLO and Mask R-CNN deep learning models to analyze live video feeds in real-time. The AI identifies safety violations such as missing PPE, unauthorized access, and hazardous zone intrusions with 90%+ accuracy.',
    },
    {
      'question': 'What happens when a violation is detected?',
      'answer': 'When a violation is detected, the system immediately sends alerts to supervisors via the mobile app. The violation is logged with timestamp, location, and visual evidence for compliance tracking.',
    },
    {
      'question': 'How fast are alerts delivered?',
      'answer': 'Alerts are typically delivered within 2-3 seconds of violation detection, ensuring rapid response times for critical safety incidents.',
    },
    {
      'question': 'Can I customize notification settings?',
      'answer': 'Yes! You can customize which types of alerts you receive (critical, medium, low) and set up daily summaries in the Settings > Notifications section.',
    },
    {
      'question': 'How do I add new cameras?',
      'answer': 'Go to Settings > Camera Management and tap the \'+\' button. Follow the setup wizard to configure your new camera and deploy AI detection models.',
    },
    {
      'question': 'What PPE violations can be detected?',
      'answer': 'The system can detect missing hard hats, safety vests, gloves, safety glasses, harnesses, and other required personal protective equipment.',
    },
    {
      'question': 'How is data stored and secured?',
      'answer': 'All violation data is encrypted and stored in a secure cloud database with local backup. Only authorized personnel can access the records.',
    },
    {
      'question': 'Can I export violation reports?',
      'answer': 'Yes! You can export violation history to CSV format from the History screen for compliance audits and safety reviews.',
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

  // Toggle FAQ expansion
  void toggleFaq(int index) {
    if (expandedFaqIndex.value == index) {
      expandedFaqIndex.value = null;
    } else {
      expandedFaqIndex.value = index;
    }
  }

  // Update search query
  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  // Handle contact support methods
  void handleContactSupport(String method) {
    switch (method) {
      case 'email':
        Get.dialog(
          AlertDialog(
            title: const Text('Opening email client...'),
            content: const Text('Email: support@constructionsafety.com'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'phone':
        Get.dialog(
          AlertDialog(
            title: const Text('Call Support'),
            content: const Text(
              'Phone: 1-800-SAFETY-1\n(1-800-723-3891)\n\nAvailable 24/7',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'chat':
        Get.dialog(
          AlertDialog(
            title: const Text('Live Chat'),
            content: const Text(
              'Connecting you to a support agent...\n\nEstimated wait time: 2 minutes',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;
    }
  }

  // Handle resource buttons
  void handleResource(String resource) {
    switch (resource) {
      case 'guide':
        Get.dialog(
          AlertDialog(
            title: const Text('User Guide'),
            content: const Text('Opening user guide...'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'tutorials':
        Get.dialog(
          AlertDialog(
            title: const Text('Video Tutorials'),
            content: const Text('Opening video tutorials...'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'guidelines':
        Get.dialog(
          AlertDialog(
            title: const Text('Safety Guidelines'),
            content: const Text('Downloading safety guidelines...'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;
    }
  }
}