import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// return screen size
  Size get size => MediaQuery.of(this).size;

  /// return screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// return screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// return screen devicePixelRatio
  double pixelRatio() => MediaQuery.of(this).devicePixelRatio;

  /// returns brightness
  Brightness platformBrightness() => MediaQuery.of(this).platformBrightness;

  /// Return the height of status bar
  double get statusBarHeight => MediaQuery.of(this).padding.top;

  /// Return the height of navigation bar
  double get navigationBarHeight => MediaQuery.of(this).padding.bottom;

  /// Returns Theme.of(context)
  ThemeData get theme => Theme.of(this);

  /// Returns Theme.of(context).textTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Returns DefaultTextStyle.of(context)
  DefaultTextStyle get defaultTextStyle => DefaultTextStyle.of(this);

  /// Returns Form.of(context)
  FormState? get formState => Form.of(this);

  /// Returns Scaffold.of(context)
  ScaffoldState get scaffoldState => Scaffold.of(this);

  /// Returns Overlay.of(context)
  OverlayState? get overlayState => Overlay.of(this);

  /// Returns primaryColor Color
  Color get primaryColor => theme.primaryColor;

  /// Returns secondaryColor Color
  Color get secondaryColor => theme.colorScheme.secondary;

  /// Returns scaffoldBackgroundColor Color
  Color get scaffoldBackgroundColor => theme.scaffoldBackgroundColor;

  /// Returns cardColor Color
  Color get cardColor => theme.cardColor;

  /// Returns dividerColor Color
  Color get dividerColor => theme.dividerColor;

  /// Returns dividerColor Color
  Color get iconColor => theme.iconTheme.color!;

  /// Request focus to given FocusNode
  void requestFocus(FocusNode focus) {
    FocusScope.of(this).requestFocus(focus);
  }

  /// Request focus to given FocusNode
  void unFocus(FocusNode focus) {
    focus.unfocus();
  }

  Orientation get orientation => MediaQuery.of(this).orientation;

  bool get isLandscape => orientation == Orientation.landscape;

  bool get isPortrait => orientation == Orientation.portrait;

  bool get canPop => Navigator.canPop(this);

  void pop<T extends Object>([T? result]) => Navigator.pop(this, result);

  TargetPlatform get platform => Theme.of(this).platform;

  bool get isAndroid => platform == TargetPlatform.android;

  bool get isIOS => platform == TargetPlatform.iOS;

  bool get isMacOS => platform == TargetPlatform.macOS;

  bool get isWindows => platform == TargetPlatform.windows;

  bool get isFuchsia => platform == TargetPlatform.fuchsia;

  bool get isLinux => platform == TargetPlatform.linux;

  // New Mobile, Tablet, Web checks based on screen width
  bool get isMobile => screenWidth < 600; // Mobile if width is less than 600px
  bool get isTabletCustom =>
      screenWidth >= 600 &&
      screenWidth < 1200; // Tablet between 600px and 1200px
  bool get isWeb => screenWidth >= 1200; // Web if width is 1200px or more

  void openDrawer() => Scaffold.of(this).openDrawer();

  void openEndDrawer() => Scaffold.of(this).openEndDrawer();

  // bool isTablet() =>
  //     MediaQuery.of(this).size.width < desktopBreakpointGlobal &&
  //         MediaQuery.of(this).size.width >= tabletBreakpointGlobal;

  // bool isDesktop() => MediaQuery.of(this).size.width >= desktopBreakpointGlobal;

  void hideKeyboard() {
    FocusScope.of(this).unfocus();
  }
}
