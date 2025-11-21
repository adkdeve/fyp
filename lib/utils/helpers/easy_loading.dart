import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class MyLoading {
  void showEasyLoading(String status) {
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..loadingStyle = EasyLoadingStyle.dark
      ..radius = 10.0
      ..backgroundColor = Colors.white;
    EasyLoading.show(
      status: status,
      dismissOnTap: false,
    );
  }

  void dismissEasyLoading() {
    EasyLoading.dismiss();
  }

  void easyLoadingSuccess() {
    EasyLoading.init();
    EasyLoading.instance.backgroundColor = Colors.white;

    EasyLoading.showSuccess(
      "Done",
      duration: const Duration(seconds: 4),
    );
  }
}
