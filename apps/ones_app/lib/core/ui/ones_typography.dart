import 'package:flutter/material.dart';

class OnesTypography {
  const OnesTypography._();

  static const String airstrike = 'Airstrike';
  static const String lemonMilk = 'LemonMilk';

  static const List<String> bodyFallbacks = <String>[
    'Trebuchet MS',
    'Arial',
    'Helvetica',
    'sans-serif',
  ];

  static TextStyle? heroTitle(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge;
  }

  static TextStyle? sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall;
  }

  static TextStyle? subtitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium;
  }

  static TextStyle? body(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium;
  }

  static TextStyle? label(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge;
  }
}
