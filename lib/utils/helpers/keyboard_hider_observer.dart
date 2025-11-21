import 'package:flutter/material.dart';

class KeyboardHiderObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _hideKeyboard();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _hideKeyboard();
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
