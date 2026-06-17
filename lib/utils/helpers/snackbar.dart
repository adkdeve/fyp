import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/widgets/my_text.dart';

class SnackBarUtils {
  // ---------------------------------------------------------------------------
  // Console logging helper
  // ---------------------------------------------------------------------------
  // Har error/success ko console par spacing ke sath print karta hai taake
  // developer easily read kar sake.
  static void _log({
    required String level, // 'ERROR' ya 'SUCCESS'
    required String emoji,
    String? title,
    required String message,
  }) {
    if (!kDebugMode) return;

    const String line =
        '==============================================================';

    debugPrint('');
    debugPrint(line);
    debugPrint('  $emoji  $level');
    debugPrint(line);
    if (title != null && title.trim().isNotEmpty) {
      debugPrint('  Title   : $title');
    }
    debugPrint('  Message : $message');
    debugPrint(line);
    debugPrint('');
  }

  // ---------------------------------------------------------------------------
  // Error snackbar (red)
  // ---------------------------------------------------------------------------
  static showError(String message, {String? title, int duration = 2}) {
    _log(level: 'ERROR', emoji: '❌', title: title, message: message);

    Get.showSnackbar(
      GetSnackBar(
        snackPosition: SnackPosition.TOP,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
        duration: Duration(seconds: duration),
        backgroundColor: Colors.redAccent,
        borderRadius: 12,
        messageText: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null && title.trim().isNotEmpty) ...[
                          MyText(
                            softWrap: true,
                            text: title,
                            fontSize: 13,
                            textAlign: TextAlign.left,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 2),
                        ],
                        MyText(
                          softWrap: true,
                          text: message,
                          fontSize: 13,
                          textAlign: TextAlign.left,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Get.closeCurrentSnackbar(),
              child: const MyText(
                text: 'Close',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Success snackbar (green)
  // ---------------------------------------------------------------------------
  static showSnackBar(String message, {String? title, int duration = 2}) {
    _log(level: 'SUCCESS', emoji: '✅', title: title, message: message);

    Get.showSnackbar(
      GetSnackBar(
        snackPosition: SnackPosition.TOP,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
        duration: Duration(seconds: duration),
        backgroundColor: Colors.green,
        borderRadius: 12,
        messageText: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null && title.trim().isNotEmpty) ...[
                          MyText(
                            softWrap: true,
                            text: title,
                            fontSize: 13,
                            textAlign: TextAlign.left,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          const SizedBox(height: 2),
                        ],
                        MyText(
                          softWrap: true,
                          text: message,
                          fontSize: 13,
                          textAlign: TextAlign.left,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Get.closeCurrentSnackbar();
              },
              child: const MyText(
                text: 'Close',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static showScaffoldSnackBar(BuildContext buildContext, String message) {
    _log(level: 'SUCCESS', emoji: '✅', message: message);

    ScaffoldMessenger.of(
      buildContext,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static errorMsg(var responseData) async {
    String errorMessage;

    if (responseData is List && responseData.isNotEmpty) {
      errorMessage = responseData[0];
    } else if (responseData is String) {
      errorMessage = responseData;
    } else {
      errorMessage = 'An unexpected error occurred';
    }

    showError(errorMessage);
  }

  static successMsg(var responseData) async {
    String successMessage;

    if (responseData is List && responseData.isNotEmpty) {
      successMessage = responseData[0].toString();
    } else if (responseData is String) {
      successMessage = responseData;
    } else {
      successMessage = 'An unexpected error occurred';
    }

    showSnackBar(successMessage);
  }
}
