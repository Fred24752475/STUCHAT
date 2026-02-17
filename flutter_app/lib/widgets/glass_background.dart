import 'package:flutter/material.dart';

class GlassBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;

  const GlassBackground({
    super.key,
    required this.child,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultGradient = isDark
        ? [
            const Color(0xFF000000),
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e),
          ]
        : [
            const Color(0xFFE3F2FD),
            const Color(0xFFBBDEFB),
            const Color(0xFF90CAF9),
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors ?? defaultGradient,
        ),
      ),
      child: child,
    );
  }
}
