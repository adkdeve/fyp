import 'package:flutter/material.dart';

extension AppTextTheme on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;

  // Display
  TextStyle get displayLarge => text.displayLarge!;
  TextStyle get displayMedium => text.displayMedium!;
  TextStyle get displaySmall => text.displaySmall!;

  // Headline
  TextStyle get headlineLarge => text.headlineLarge!; // aka headline1
  TextStyle get headlineMedium => text.headlineMedium!; // aka headline2
  TextStyle get headlineSmall => text.headlineSmall!; // aka headline3

  // Title
  TextStyle get titleLarge => text.titleLarge!;
  TextStyle get titleMedium => text.titleMedium!;
  TextStyle get titleSmall => text.titleSmall!;

  // Body
  TextStyle get bodyLarge => text.bodyLarge!;
  TextStyle get bodyMedium => text.bodyMedium!;
  TextStyle get bodySmall => text.bodySmall!;

  // Label
  TextStyle get labelLarge => text.labelLarge!;
  TextStyle get labelMedium => text.labelMedium!;
  TextStyle get labelSmall => text.labelSmall!;
}
