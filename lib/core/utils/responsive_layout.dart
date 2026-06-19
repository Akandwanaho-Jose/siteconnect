import 'package:flutter/material.dart';

class ResponsiveLayout {
  const ResponsiveLayout._();

  static const double maxContentWidth = 720;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < 360) {
      return const EdgeInsets.all(12);
    }

    if (width < 600) {
      return const EdgeInsets.all(16);
    }

    return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
  }

  static bool isSmallPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 360;
  }
}
