import 'dart:math' as math;

import 'package:flutter/material.dart';

class ThinkingDots extends StatefulWidget {
  final bool isActive;
  const ThinkingDots({super.key, required this.isActive});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.isActive) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant ThinkingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isActive && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    return SizedBox(
      width: 40,
      height: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              final phase = (t * 2 * math.pi) + i * 0.9;
              final y = (math.sin(phase) + 1) / 2; // 0..1
              final scale = 0.7 + y * 0.35;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

