import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/widgets/my_text.dart';

class SnackBarUtils {
  static showError(String message, [int duration = 2]) {
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
                    child: MyText(
                      softWrap: true,
                      text: message,
                      fontSize: 13,
                      textAlign: TextAlign.left,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
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

  static showSnackBar(String message, [int duration = 2]) {
    Get.showSnackbar(
      GetSnackBar(
        snackPosition: SnackPosition.TOP,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
        duration: Duration(seconds: duration),

        // isDismissible: false,
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
                    child: MyText(
                      softWrap: true,
                      text: message,
                      fontSize: 13,
                      textAlign: TextAlign.left,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
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
