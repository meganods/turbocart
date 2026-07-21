import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBurstWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ParticleBurstWrapper({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<ParticleBurstWrapper> createState() => _ParticleBurstWrapperState();
}

class _ParticleBurstWrapperState extends State<ParticleBurstWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    _controller.reset();
    _controller.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _triggerBurst,
          child: widget.child,
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (!_controller.isAnimating) return const SizedBox.shrink();
            return CustomPaint(
              size: const Size(60, 32),
              painter: ParticleBurstPainter(progress: _controller.value),
            );
          },
        ),
      ],
    );
  }
}

class ParticleBurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  ParticleBurstPainter({required this.progress, this.color = const Color(0xFF0C831F)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = 24.0;
    final double progressRadius = maxRadius * progress;

    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60) * pi / 180;
      final double dx = progressRadius * cos(angle);
      final double dy = progressRadius * sin(angle);
      canvas.drawCircle(center + Offset(dx, dy), 4.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
