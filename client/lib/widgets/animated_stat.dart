import 'package:flutter/material.dart';

/// Smoothly animates a numeric value whenever [value] changes.
/// Uses TweenAnimationBuilder so it interpolates from wherever
/// the animation currently is — works correctly at any playback speed.
class AnimatedStat extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedStat({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, child) => Text(formatter(v), style: style),
    );
  }
}
