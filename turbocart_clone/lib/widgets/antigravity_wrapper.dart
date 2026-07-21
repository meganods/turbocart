// ignore_for_file: unused_field, unused_element, unused_import
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AntigravityWrapper extends StatefulWidget {
  final Widget child;
  final int index;
  final String category;
  final bool animateEntrance;
  final bool enableFloat;
  final bool enableLongPressLift;

  const AntigravityWrapper({
    super.key,
    required this.child,
    required this.index,
    this.category = 'grocery_kitchen',
    this.animateEntrance = true,
    this.enableFloat = false,
    this.enableLongPressLift = true,
  });

  @override
  State<AntigravityWrapper> createState() => _AntigravityWrapperState();
}

class _AntigravityWrapperState extends State<AntigravityWrapper> with TickerProviderStateMixin {
  // Continuous Float & Sway & Rotation
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Entrance Drop
  late AnimationController _entranceController;
  late Animation<double> _entranceOpacity;
  late Animation<double> _entranceScale;
  late Animation<Offset> _entranceOffset;

  // Scroll-triggered float in
  late AnimationController _scrollController;
  late Animation<double> _scrollOpacity;
  late Animation<double> _scrollTranslation;
  bool _hasFloatedIn = false;

  // Long press lift
  late AnimationController _liftController;
  late Animation<double> _liftScale;

  // Golden Shimmer for Gifting
  late AnimationController _shimmerController;

  // Category Configuration
  late double amplitude;
  late int durationMs;

  @override
  void initState() {
    super.initState();

    // Resolve Category configurations
    amplitude = 4.0;
    durationMs = 2200;

    final cat = widget.category;
    if (cat == 'grocery_kitchen') {
      amplitude = 3.0;
      durationMs = 2000;
    } else if (cat == 'snacks_drinks') {
      amplitude = 6.0;
      durationMs = 1800;
    } else if (cat == 'beauty_care') {
      amplitude = 5.0;
      durationMs = 2500;
    } else if (cat == 'household') {
      amplitude = 3.0;
      durationMs = 2000;
    } else if (cat == 'pharmacy') {
      amplitude = 2.0;
      durationMs = 3000;
    } else if (cat == 'dairy_bread') {
      amplitude = 4.0;
      durationMs = 2200;
    } else if (cat == 'fruits_veg') {
      amplitude = 7.0;
      durationMs = 1600;
    } else if (cat == 'baby_care') {
      amplitude = 3.0;
      durationMs = 2400;
    } else if (cat == 'electronics') {
      amplitude = 4.0;
      durationMs = 2100; // Peak hold handles separately
    } else if (cat == 'toys_games') {
      amplitude = 8.0;
      // Staggered random duration
      final rand = Random(widget.index);
      durationMs = 1400 + rand.nextInt(600);
    } else if (cat == 'sports') {
      amplitude = 6.0;
      durationMs = 2000;
    } else if (cat == 'gifting') {
      amplitude = 5.0;
      durationMs = 2000;
    } else if (cat == 'pet_care') {
      amplitude = 4.0;
      durationMs = 2200;
    } else if (cat == 'books') {
      amplitude = 4.0;
      durationMs = 2800;
    } else if (cat == 'stationery') {
      amplitude = 4.0;
      durationMs = 2200;
    } else if (cat == 'fashion') {
      amplitude = 5.0;
      durationMs = 2200;
    }

    // A: Continuous Float
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // Precise hold curve for electronics
    Curve bobCurve = Curves.easeInOut;
    if (cat == 'electronics') {
      bobCurve = const Interval(0.0, 0.9, curve: Curves.easeInOut);
    }

    _floatAnimation = Tween<double>(begin: -amplitude, end: amplitude).animate(
      CurvedAnimation(parent: _floatController, curve: bobCurve),
    );

    // Stagger phase offset based on index (adjacent cards never bob in sync)
    final double phaseOffset = (widget.index % 4) * 0.25;
    final int delayMs = durationMs > 0 ? (phaseOffset * durationMs).toInt() : 0;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted && widget.enableFloat) {
        _floatController.repeat(reverse: true);
      }
    });

    // B: Entrance Drop & Stationery Diagonal Slide
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)),
    );
    _entranceScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    // Offset based on category (Stationery does diagonal top-left slide)
    final Offset startOffset = cat == 'stationery' ? const Offset(-50, -50) : const Offset(0, -20);
    _entranceOffset = Tween<Offset>(begin: startOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    // Trigger Entrance Drop after stagger
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (!mounted) return;
      if (widget.animateEntrance) {
        _entranceController.forward();
      } else {
        _entranceController.value = 1.0;
      }
    });

    // F: Scroll-triggered float in
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scrollOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scrollController, curve: Curves.easeOutCubic),
    );
    _scrollTranslation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _scrollController, curve: Curves.easeOutCubic),
    );

    // G: Long press lift
    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _liftScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _liftController, curve: Curves.easeOut),
    );

    // Gifting Shimmer Sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    if (cat == 'gifting') {
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entranceController.dispose();
    _scrollController.dispose();
    _liftController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _triggerScrollFloatIn() {
    if (!_hasFloatedIn) {
      _hasFloatedIn = true;
      _scrollController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
