import 'package:flutter/material.dart';

class AntigravityCartBadge extends StatefulWidget {
  final Widget child;
  final int quantity;

  const AntigravityCartBadge({
    super.key,
    required this.child,
    required this.quantity,
  });

  @override
  State<AntigravityCartBadge> createState() => _AntigravityCartBadgeState();
}

class _AntigravityCartBadgeState extends State<AntigravityCartBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  int _lastQuantity = 0;

  @override
  void initState() {
    super.initState();
    _lastQuantity = widget.quantity;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.5), weight: 100 / 240),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 0.8), weight: 80 / 240),
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.0), weight: 60 / 240),
    ]).animate(_controller);

    _colorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.yellowAccent,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AntigravityCartBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity > _lastQuantity) {
      _controller.reset();
      _controller.forward();
    }
    _lastQuantity = widget.quantity;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Theme(
            data: Theme.of(context).copyWith(
              iconTheme: IconThemeData(
                color: _controller.isAnimating ? _colorAnimation.value : Colors.white,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
