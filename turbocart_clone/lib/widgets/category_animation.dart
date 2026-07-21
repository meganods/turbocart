import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ─────────────────────────────────────────────────────────────────
//  Per-category style definition
// ─────────────────────────────────────────────────────────────────
class _CatStyle {
  final List<Color> gradient;
  final List<Color> blobs;
  const _CatStyle({required this.gradient, required this.blobs});
}

const Map<String, _CatStyle> _styles = {
  'grocery': _CatStyle(
    gradient: [Color(0xFF1B5E20), Color(0xFF33691E), Color(0xFF1A3C10)],
    blobs: [Color(0xFF76FF03), Color(0xFF00E676), Color(0xFFB9F6CA)],
  ),
  'dairy': _CatStyle(
    gradient: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A2F6E)],
    blobs: [Color(0xFF82B1FF), Color(0xFFE3F2FD), Color(0xFF40C4FF)],
  ),
  'snacks': _CatStyle(
    gradient: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFF7B1A00)],
    blobs: [Color(0xFFFF6D00), Color(0xFFFFD740), Color(0xFFFF3D00)],
  ),
  'beverages': _CatStyle(
    gradient: [Color(0xFF006064), Color(0xFF00838F), Color(0xFF003B40)],
    blobs: [Color(0xFF00E5FF), Color(0xFF80DEEA), Color(0xFF1DE9B6)],
  ),
  'beauty': _CatStyle(
    gradient: [Color(0xFF880E4F), Color(0xFFAD1457), Color(0xFF560027)],
    blobs: [Color(0xFFF48FB1), Color(0xFFFF80AB), Color(0xFFFFD6E7)],
  ),
  'pharmacy': _CatStyle(
    gradient: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00251A)],
    blobs: [Color(0xFF69F0AE), Color(0xFF00E676), Color(0xFFB9F6CA)],
  ),
  'electronics': _CatStyle(
    gradient: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF0D1240)],
    blobs: [Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFF64FFDA)],
  ),
  'decor': _CatStyle(
    gradient: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF2D0060)],
    blobs: [Color(0xFFCE93D8), Color(0xFFFFD54F), Color(0xFFF8BBD0)],
  ),
  'kids': _CatStyle(
    gradient: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF082A70)],
    blobs: [Color(0xFFFFD740), Color(0xFFFF6D00), Color(0xFF69F0AE)],
  ),
  'gifting': _CatStyle(
    gradient: [Color(0xFF7B1FA2), Color(0xFF9C27B0), Color(0xFF4A0072)],
    blobs: [Color(0xFFFF4081), Color(0xFFFFD740), Color(0xFFF48FB1)],
  ),
  'vacations': _CatStyle(
    gradient: [Color(0xFF01579B), Color(0xFF0277BD), Color(0xFF002F5B)],
    blobs: [Color(0xFF40C4FF), Color(0xFF80DEEA), Color(0xFFE0F7FA)],
  ),
  'all': _CatStyle(
    gradient: [Color(0xFF212121), Color(0xFF37474F), Color(0xFF1A1A2E)],
    blobs: [Color(0xFFFFD740), Color(0xFF00E676), Color(0xFF40C4FF)],
  ),
};

_CatStyle _styleFor(String id) => _styles[id] ?? _styles['all']!;

/// Returns the deep gradient colors for a given category id.
/// Used by the home screen to paint the full-screen background.
List<Color> categoryScreenGradient(String id) => _styleFor(id).gradient;

// ─────────────────────────────────────────────────────────────────
//  Animated blob background painter
// ─────────────────────────────────────────────────────────────────
class _BlobBgPainter extends CustomPainter {
  final double t;       // 0..1 slow loop (blob drift)
  final double shimmer; // 0..1 shimmer wave
  final List<Color> gradient;
  final List<Color> blobs;

  const _BlobBgPainter({
    required this.t,
    required this.shimmer,
    required this.gradient,
    required this.blobs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── Gradient background ──
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // ── Dot grid texture overlay ──
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // ── Animated blobs ──
    final blobConfigs = [
      (
        cx: size.width * 0.2 + math.cos(t * math.pi * 2) * 30,
        cy: size.height * 0.3 + math.sin(t * math.pi * 2 * 0.7) * 20,
        r: 80.0,
        color: blobs[0].withValues(alpha: 0.22),
      ),
      (
        cx: size.width * 0.75 + math.sin(t * math.pi * 2 * 0.8) * 35,
        cy: size.height * 0.2 + math.cos(t * math.pi * 2 * 1.1) * 25,
        r: 65.0,
        color: blobs[1].withValues(alpha: 0.18),
      ),
      (
        cx: size.width * 0.55 + math.cos(t * math.pi * 2 * 0.6) * 40,
        cy: size.height * 0.75 + math.sin(t * math.pi * 2 * 0.9) * 20,
        r: 55.0,
        color: blobs[2].withValues(alpha: 0.2),
      ),
    ];

    for (final b in blobConfigs) {
      final blobPaint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..color = b.color;
      canvas.drawCircle(Offset(b.cx, b.cy), b.r, blobPaint);
    }

    // ── Shimmer sine wave at bottom ──
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final wavePath = Path();
    wavePath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final waveY = size.height - 28 -
          14 * math.sin((x / size.width * 2 * math.pi) + shimmer * 2 * math.pi);
      wavePath.lineTo(x, waveY);
    }
    wavePath.lineTo(size.width, size.height);
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(_BlobBgPainter old) =>
      old.t != t || old.shimmer != shimmer;
}

// ─────────────────────────────────────────────────────────────────
//  Public widget
// ─────────────────────────────────────────────────────────────────
class CategoryAnimationWidget extends StatefulWidget {
  final String categoryId;
  final Color primaryColor;
  final double size;

  const CategoryAnimationWidget({
    super.key,
    required this.categoryId,
    required this.primaryColor,
    this.size = 200,
  });

  @override
  State<CategoryAnimationWidget> createState() =>
      _CategoryAnimationWidgetState();
}

class _CategoryAnimationWidgetState extends State<CategoryAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _bgCtrl; // slow drift for blobs

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(widget.categoryId);
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        width: double.infinity,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_bgCtrl, _floatCtrl]),
          builder: (context, child) {
            return CustomPaint(
              painter: _BlobBgPainter(
                t: _bgCtrl.value,
                shimmer: _floatCtrl.value,
                gradient: style.gradient,
                blobs: style.blobs,
              ),
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow aura behind emoji
              _GlowAura(
                ctrl: _pulseCtrl,
                color: style.blobs[0],
              ),
              // Per-category emoji animation
              _buildAnimation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    switch (widget.categoryId) {
      case 'grocery':
        return Image.asset(
          'assets/images/grocery_banner.jpg',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _GroceryAnimation(main: _mainCtrl, float: _floatCtrl, particle: _particleCtrl);
          },
        );
      case 'dairy':
        return _DairyAnimation(main: _mainCtrl, float: _floatCtrl, pulse: _pulseCtrl);
      case 'snacks':
        return _SnacksAnimation(main: _mainCtrl, float: _floatCtrl, particle: _particleCtrl);
      case 'beverages':
        return Image.asset(
          'assets/images/beverages.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.local_cafe, size: 80, color: Colors.white70),
            );
          },
        );
      case 'beauty':
        return Image.asset(
          'assets/images/beauty_banner.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _BeautyAnimation(main: _mainCtrl, float: _floatCtrl, particle: _particleCtrl);
          },
        );
      case 'pharmacy':
        return _PharmacyAnimation(main: _mainCtrl, pulse: _pulseCtrl, particle: _particleCtrl);
      case 'electronics':
        return const _VideoAnimation(assetPath: 'assets/videos/electronics.mp4');
      case 'decor':
        return Image.asset(
          'assets/images/decor_banner.jpg',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const _VideoAnimation(assetPath: 'assets/videos/decor.mp4');
          },
        );
      case 'kids':
        return Image.asset(
          'assets/images/kids_banner.jpg',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _KidsAnimation(main: _mainCtrl, float: _floatCtrl, particle: _particleCtrl);
          },
        );
      case 'gifting':
        return Image.asset(
          'assets/images/gifting_banner.jpg',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _GiftingAnimation(main: _mainCtrl, float: _floatCtrl, particle: _particleCtrl);
          },
        );
      case 'vacations':
        return const _VideoAnimation(assetPath: 'assets/videos/vacation.mp4');
      default:
        return _AllAnimation(main: _mainCtrl, float: _floatCtrl, pulse: _pulseCtrl);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  Glow aura (shared)
// ─────────────────────────────────────────────────────────────────
class _GlowAura extends StatelessWidget {
  final AnimationController ctrl;
  final Color color;
  const _GlowAura({required this.ctrl, required this.color});

  @override
  Widget build(BuildContext context) {
    final pulse = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOutSine));
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) => Container(
        width: 110 * pulse.value,
        height: 110 * pulse.value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🥦 GROCERY: Basket with falling vegetables
// ─────────────────────────────────────────────────────────────────
class _GroceryAnimation extends StatelessWidget {
  final AnimationController main, float, particle;
  const _GroceryAnimation({required this.main, required this.float, required this.particle});

  @override
  Widget build(BuildContext context) {
    final bounce = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutSine));
    final vegFall = Tween<double>(begin: -60, end: 20).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0, 0.5, curve: Curves.bounceOut)));
    final leafFloat = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOutSine));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, particle]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 20 + leafFloat.value * 15,
              top: 40 - leafFloat.value * 10,
              child: Opacity(opacity: 0.9, child: const Text('🍃', style: TextStyle(fontSize: 22))),
            ),
            Positioned(
              right: 22 - leafFloat.value * 12,
              top: 60 + leafFloat.value * 8,
              child: Opacity(opacity: 0.8, child: const Text('🌿', style: TextStyle(fontSize: 18))),
            ),
            if (particle.value < 0.55)
              Positioned(
                top: vegFall.value,
                left: 55,
                child: Opacity(
                  opacity: (particle.value < 0.45 ? particle.value / 0.45 : 1.0).clamp(0, 1),
                  child: Transform.rotate(
                    angle: particle.value * math.pi,
                    child: const Text('🥕', style: TextStyle(fontSize: 30)),
                  ),
                ),
              ),
            if (particle.value > 0.15 && particle.value < 0.65)
              Positioned(
                top: math.max(-60.0, (particle.value - 0.15) / 0.5 * 80 - 60),
                left: 90,
                child: Opacity(
                  opacity: ((particle.value - 0.15) < 0.1 ? (particle.value - 0.15) / 0.1 : 1.0).clamp(0, 1),
                  child: const Text('🥦', style: TextStyle(fontSize: 26)),
                ),
              ),
            if (particle.value > 0.25 && particle.value < 0.7)
              Positioned(
                top: math.max(-60.0, (particle.value - 0.25) / 0.5 * 80 - 60),
                left: 120,
                child: Opacity(
                  opacity: ((particle.value - 0.25) < 0.1 ? (particle.value - 0.25) / 0.1 : 1.0).clamp(0, 1),
                  child: const Text('🍅', style: TextStyle(fontSize: 24)),
                ),
              ),
            Transform.translate(
              offset: Offset(0, bounce.value),
              child: const Text('🧺', style: TextStyle(fontSize: 80)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🥛 DAIRY: Milk bottle with splash droplets
// ─────────────────────────────────────────────────────────────────
class _DairyAnimation extends StatelessWidget {
  final AnimationController main, float, pulse;
  const _DairyAnimation({required this.main, required this.float, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final breathe = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutSine));
    final splashY = Tween<double>(begin: 30, end: -10).animate(
      CurvedAnimation(parent: pulse, curve: const Interval(0, 0.4, curve: Curves.easeOut)));
    final dropOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: pulse, curve: const Interval(0.3, 0.6, curve: Curves.easeIn)));
    final floatVal = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOutSine));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, pulse]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 28 + floatVal.value * 10,
              top: 50 - floatVal.value * 20,
              child: Opacity(
                opacity: dropOpacity.value,
                child: Container(
                  width: 9, height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 26 + floatVal.value * 8,
              top: 70 - floatVal.value * 15,
              child: Opacity(
                opacity: dropOpacity.value * 0.7,
                child: Container(
                  width: 6, height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBDEFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: splashY.value,
              child: Opacity(
                opacity: (1 - pulse.value * 1.5).clamp(0, 1),
                child: const Text('💧', style: TextStyle(fontSize: 24)),
              ),
            ),
            Transform.scale(
              scale: breathe.value,
              child: const Text('🥛', style: TextStyle(fontSize: 84)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🍟 SNACKS: Chips packet popping
// ─────────────────────────────────────────────────────────────────
class _SnacksAnimation extends StatelessWidget {
  final AnimationController main, float, particle;
  const _SnacksAnimation({required this.main, required this.float, required this.particle});

  @override
  Widget build(BuildContext context) {
    final squish = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutBack));
    final chip1 = Tween<double>(begin: 0, end: -58).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    final chip2 = Tween<double>(begin: 0, end: -52).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0.1, 0.45, curve: Curves.easeOut)));
    final chip3 = Tween<double>(begin: 0, end: -48).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0.2, 0.5, curve: Curves.easeOut)));
    final chipOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0.35, 0.6)));
    final floatVal = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOutSine));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, particle]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (particle.value < 0.6) ...[
              Positioned(
                top: 60 + chip1.value,
                left: 45 - floatVal.value * 15,
                child: Opacity(opacity: chipOpacity.value,
                  child: Transform.rotate(angle: -0.5, child: const Text('🍪', style: TextStyle(fontSize: 22)))),
              ),
              Positioned(
                top: 60 + chip2.value,
                right: 40 + floatVal.value * 10,
                child: Opacity(opacity: chipOpacity.value,
                  child: Transform.rotate(angle: 0.7, child: const Text('🍪', style: TextStyle(fontSize: 20)))),
              ),
              Positioned(
                top: 55 + chip3.value,
                left: 80,
                child: Opacity(opacity: chipOpacity.value,
                  child: Transform.rotate(angle: 0.3, child: const Text('🍪', style: TextStyle(fontSize: 18)))),
              ),
            ],
            Transform.scale(
              scaleX: squish.value,
              scaleY: 1 / squish.value,
              child: const Text('🍟', style: TextStyle(fontSize: 84)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🥤 BEVERAGES: Glass filling with bubbles
// ─────────────────────────────────────────────────────────────────
// ignore: unused_element
class _BeveragesAnimation extends StatelessWidget {
  final AnimationController main, float, pulse;
  const _BeveragesAnimation({required this.main, required this.float, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final fillLevel = Tween<double>(begin: 0.1, end: 0.85).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutCubic));
    final bubble1Y = Tween<double>(begin: 0, end: -50).animate(
      CurvedAnimation(parent: pulse, curve: Curves.easeOut));
    final bubble2Y = Tween<double>(begin: 0, end: -45).animate(
      CurvedAnimation(parent: pulse, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    final iceY = Tween<double>(begin: -40, end: 8).animate(
      CurvedAnimation(parent: float, curve: const Interval(0, 0.4, curve: Curves.bounceOut)));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, pulse]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 30 + bubble1Y.value * fillLevel.value,
              left: 70,
              child: Opacity(
                opacity: (1 - pulse.value).clamp(0, 1),
                child: Container(width: 7, height: 7,
                  decoration: const BoxDecoration(color: Color(0xFF80DEEA), shape: BoxShape.circle)),
              ),
            ),
            Positioned(
              bottom: 35 + bubble2Y.value * fillLevel.value,
              left: 100,
              child: Opacity(
                opacity: (1 - pulse.value * 1.2).clamp(0, 1),
                child: Container(width: 5, height: 5,
                  decoration: const BoxDecoration(color: Color(0xFFB2EBF2), shape: BoxShape.circle)),
              ),
            ),
            Positioned(
              top: 45 + iceY.value,
              child: const Text('🧊', style: TextStyle(fontSize: 24)),
            ),
            const Text('🥤', style: TextStyle(fontSize: 84)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  💄 BEAUTY: Sparkle cosmetic with orbiting particles
// ─────────────────────────────────────────────────────────────────
class _BeautyAnimation extends StatelessWidget {
  final AnimationController main, float, particle;
  const _BeautyAnimation({required this.main, required this.float, required this.particle});

  @override
  Widget build(BuildContext context) {
    final breathe = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutSine));
    final orbit = Tween<double>(begin: 0, end: 2 * math.pi).animate(particle);
    final sparkleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOut));
    const r = 52.0;

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, particle]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(4, (i) {
              final angle = orbit.value + (i * math.pi / 2);
              final dx = math.cos(angle) * r;
              final dy = math.sin(angle) * r;
              return Positioned(
                left: 100 + dx - 8,
                top: 100 + dy - 8,
                child: Opacity(
                  opacity: sparkleOpacity.value * 0.9,
                  child: const Text('✨', style: TextStyle(fontSize: 18)),
                ),
              );
            }),
            Transform.scale(
              scale: breathe.value,
              child: const Text('💄', style: TextStyle(fontSize: 84)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  💊 PHARMACY: Medical cross with ECG pulse
// ─────────────────────────────────────────────────────────────────
class _PharmacyAnimation extends StatelessWidget {
  final AnimationController main, pulse, particle;
  const _PharmacyAnimation({required this.main, required this.pulse, required this.particle});

  @override
  Widget build(BuildContext context) {
    final ripple1 = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: pulse, curve: Curves.easeOut));
    final ripple2 = Tween<double>(begin: 0.3, end: 1.3).animate(
      CurvedAnimation(parent: pulse, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    final rippleOpacity = Tween<double>(begin: 0.7, end: 0).animate(pulse);
    final glow = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutSine));

    return AnimatedBuilder(
      animation: Listenable.merge([main, pulse, particle]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: ripple1.value,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF69F0AE).withValues(alpha: rippleOpacity.value),
                    width: 2.5,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: ripple2.value,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: rippleOpacity.value * 0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(180, 42),
              painter: _ECGPainter(progress: particle.value),
            ),
            Transform.scale(
              scale: glow.value,
              child: const Text('💊', style: TextStyle(fontSize: 80)),
            ),
            const Positioned(
              top: 18,
              child: Text('➕', style: TextStyle(fontSize: 24, color: Color(0xFF69F0AE))),
            ),
          ],
        );
      },
    );
  }
}

class _ECGPainter extends CustomPainter {
  final double progress;
  _ECGPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: 0.8)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height / 2;
    final offset = progress * w;

    path.moveTo(0, h);
    for (double x = 0; x < w; x += 1) {
      final relX = (x + offset) % w;
      double y = h;
      if (relX > w * 0.3 && relX < w * 0.35) {
        y = h - (relX - w * 0.3) / (w * 0.05) * h;
      } else if (relX >= w * 0.35 && relX < w * 0.4) {
        y = h - h + (relX - w * 0.35) / (w * 0.05) * (h * 2.5);
      } else if (relX >= w * 0.4 && relX < w * 0.45) {
        y = h + h * 1.5 - (relX - w * 0.4) / (w * 0.05) * (h * 2.5);
      } else if (relX >= w * 0.45 && relX < w * 0.5) {
        y = h - 0 + (relX - w * 0.45) / (w * 0.05) * h;
      }
      if (x == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ECGPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────
//  📱 ELECTRONICS: Smartphone powering on
// ─────────────────────────────────────────────────────────────────
// ignore: unused_element
class _ElectronicsAnimation extends StatelessWidget {
  final AnimationController main, float, pulse;
  const _ElectronicsAnimation({required this.main, required this.float, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final screenGlow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: pulse, curve: const Interval(0.2, 0.7, curve: Curves.easeInOut)));
    final circuitOpacity = Tween<double>(begin: 0, end: 0.9).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOut));
    final slideIn = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(parent: main, curve: Curves.easeOutCubic));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, pulse]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: circuitOpacity.value,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _CircuitPainter(progress: pulse.value),
              ),
            ),
            Container(
              width: 62, height: 102,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: screenGlow.value * 0.6),
                  blurRadius: 28,
                  spreadRadius: 8,
                )],
              ),
            ),
            Transform.translate(
              offset: Offset(0, slideIn.value),
              child: const Text('📱', style: TextStyle(fontSize: 84)),
            ),
            Positioned(
              top: 15,
              right: 35,
              child: Opacity(
                opacity: screenGlow.value,
                child: const Icon(Icons.power_settings_new, color: Color(0xFF00E5FF), size: 22),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CircuitPainter extends CustomPainter {
  final double progress;
  _CircuitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final pathDefs = [
      [Offset(20, 80), Offset(40, 80), Offset(40, 50), Offset(80, 50)],
      [Offset(size.width - 20, 80), Offset(size.width - 40, 80), Offset(size.width - 40, 60), Offset(size.width - 70, 60)],
      [Offset(20, 130), Offset(50, 130), Offset(50, 150), Offset(90, 150)],
    ];

    for (final pts in pathDefs) {
      if (pts.length >= 2) {
        final path = Path();
        path.moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        final metric = path.computeMetrics().first;
        final animPath = metric.extractPath(0, metric.length * progress);
        canvas.drawPath(animPath, paint);
        if (progress > 0.1) {
          canvas.drawCircle(pts.last, 3.5, Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.9));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CircuitPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────
//  💡 DECOR: Swinging pendant lamp with glow
// ─────────────────────────────────────────────────────────────────
// ignore: unused_element
class _DecorAnimation extends StatelessWidget {
  final AnimationController main, float, pulse;
  const _DecorAnimation({required this.main, required this.float, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final swing = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutSine));
    final glowSize = Tween<double>(begin: 45, end: 85).animate(
      CurvedAnimation(parent: pulse, curve: Curves.easeInOutSine));
    final glowOpacity = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: pulse, curve: Curves.easeInOutSine));
    final rayOpacity = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOutSine));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, pulse]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              bottom: 20,
              child: Container(
                width: glowSize.value,
                height: glowSize.value / 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD54F).withValues(alpha: glowOpacity.value),
                ),
              ),
            ),
            ...List.generate(6, (i) {
              final angle = (i * math.pi / 3) + (pulse.value * 0.5);
              const rayLength = 38.0;
              return Positioned(
                top: 95,
                left: 100 + math.cos(angle) * rayLength - 1,
                child: Transform.rotate(
                  angle: angle,
                  child: Opacity(
                    opacity: rayOpacity.value * 0.7,
                    child: Container(
                      width: 2, height: 18,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFD54F), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Transform.rotate(
              angle: swing.value,
              origin: const Offset(0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 3, height: 38, color: const Color(0xFF9E9E9E)),
                  const Text('💡', style: TextStyle(fontSize: 80)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🧸 KIDS: Bouncing teddy with stars
// ─────────────────────────────────────────────────────────────────
class _KidsAnimation extends StatelessWidget {
  final AnimationController main, float, particle;
  const _KidsAnimation({required this.main, required this.float, required this.particle});

  @override
  Widget build(BuildContext context) {
    final bounce = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutBack));
    final squishX = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOut));
    final wave = Tween<double>(begin: -0.3, end: 0.3).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOutSine));
    final starOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    final starFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, particle]),
      builder: (context, _) {
        final starOp = (particle.value < 0.5 ? starOpacity.value : starFade.value).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(5, (i) {
              final angle = (i * 2 * math.pi / 5) + particle.value * math.pi;
              const radius = 68.0;
              return Positioned(
                left: 100 + math.cos(angle) * radius - 10,
                top: 100 + math.sin(angle) * radius - 10,
                child: Opacity(
                  opacity: starOp * (i % 2 == 0 ? 1 : 0.6),
                  child: Text(
                    ['⭐', '🌟', '✨', '💫', '⭐'][i],
                    style: TextStyle(fontSize: ([17.0, 15.0, 19.0, 13.0, 16.0])[i]),
                  ),
                ),
              );
            }),
            Positioned(
              right: 46,
              top: 70,
              child: Transform.rotate(
                angle: wave.value,
                origin: const Offset(0, -10),
                child: const Text('🤚', style: TextStyle(fontSize: 24)),
              ),
            ),
            Transform.translate(
              offset: Offset(0, bounce.value),
              child: Transform.scale(
                scaleX: squishX.value,
                scaleY: 2.0 - squishX.value,
                alignment: Alignment.bottomCenter,
                child: const Text('🧸', style: TextStyle(fontSize: 84)),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🎁 GIFTING: Gift box bursting with confetti
// ─────────────────────────────────────────────────────────────────
class _GiftingAnimation extends StatelessWidget {
  final AnimationController main, float, particle;
  const _GiftingAnimation({required this.main, required this.float, required this.particle});

  @override
  Widget build(BuildContext context) {
    final lidLift = Tween<double>(begin: 0, end: -28).animate(
      CurvedAnimation(parent: main, curve: const Interval(0, 0.4, curve: Curves.easeOut)));
    final confettiProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    final confettiFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: particle, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));

    const confettiColors = [
      Color(0xFFFF4081), Color(0xFFFFD740), Color(0xFF40C4FF),
      Color(0xFF69F0AE), Color(0xFFCE93D8), Color(0xFFFF6D00),
    ];
    final rand = math.Random(42);

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, particle]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (particle.value < 0.9)
              ...List.generate(12, (i) {
                final angle = (i * math.pi / 6) - math.pi / 2;
                final speed = 0.6 + rand.nextDouble() * 0.4;
                final dist = confettiProgress.value * 72 * speed;
                final dx = math.cos(angle) * dist;
                final dy = math.sin(angle) * dist + confettiProgress.value * 28;
                return Positioned(
                  left: 100 + dx - 4,
                  top: 90 + dy - 4,
                  child: Opacity(
                    opacity: confettiFade.value,
                    child: Transform.rotate(
                      angle: confettiProgress.value * math.pi * 2 * (i.isEven ? 1 : -1),
                      child: Container(
                        width: 9, height: 9,
                        decoration: BoxDecoration(
                          color: confettiColors[i % confettiColors.length],
                          borderRadius: BorderRadius.circular(i.isEven ? 4.5 : 0),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const Text('🎁', style: TextStyle(fontSize: 84)),
            Positioned(
              top: 42 + lidLift.value,
              child: const Text('🎀', style: TextStyle(fontSize: 36)),
            ),
            if (main.value > 0.3)
              Positioned(
                top: 28 + lidLift.value,
                child: Opacity(
                  opacity: (main.value - 0.3) * 1.4,
                  child: const Text('✨', style: TextStyle(fontSize: 30)),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ✈️ VACATIONS: Suitcase with flying airplane
// ─────────────────────────────────────────────────────────────────
// ignore: unused_element
class _VacationsAnimation extends StatelessWidget {
  final AnimationController main, float, particle;
  const _VacationsAnimation({required this.main, required this.float, required this.particle});

  @override
  Widget build(BuildContext context) {
    final planeOrbit = Tween<double>(begin: 0, end: 2 * math.pi).animate(particle);
    final suitcaseOpen = Tween<double>(begin: 0, end: 0.15).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOut));
    final pinBounce = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: float, curve: Curves.easeInOutSine));
    const orbitRadius = 62.0;

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, particle]),
      builder: (context, _) {
        final planeX = math.cos(planeOrbit.value) * orbitRadius;
        final planeY = math.sin(planeOrbit.value) * orbitRadius * 0.5;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Orbit path
            Container(
              width: 134, height: 134,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF40C4FF).withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),
            Positioned(
              top: 14 + pinBounce.value,
              right: 28,
              child: const Text('📍', style: TextStyle(fontSize: 30)),
            ),
            Positioned(
              left: 100 + planeX - 14,
              top: 100 + planeY - 14,
              child: Transform.rotate(
                angle: planeOrbit.value + math.pi / 4,
                child: const Text('✈️', style: TextStyle(fontSize: 26)),
              ),
            ),
            Transform.rotate(
              angle: suitcaseOpen.value,
              child: const Text('🧳', style: TextStyle(fontSize: 84)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🌐 ALL: Rotating grid of category icons
// ─────────────────────────────────────────────────────────────────
class _AllAnimation extends StatelessWidget {
  final AnimationController main, float, pulse;
  const _AllAnimation({required this.main, required this.float, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final rotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(pulse);
    final scale = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: main, curve: Curves.easeInOutSine));
    const icons = ['🛒', '✈️', '📱', '💄', '💊', '💡', '🧸', '🎁', '🥦', '🥛', '🍟', '🥤'];

    return AnimatedBuilder(
      animation: Listenable.merge([main, float, pulse]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(8, (i) {
              final angle = rotation.value / 8 + (i * 2 * math.pi / 8);
              const r = 74.0;
              final dx = math.cos(angle) * r;
              final dy = math.sin(angle) * r;
              return Positioned(
                left: 100 + dx - 13,
                top: 100 + dy - 13,
                child: Text(icons[i], style: const TextStyle(fontSize: 23)),
              );
            }),
            ...List.generate(4, (i) {
              final angle = -rotation.value / 4 + (i * 2 * math.pi / 4);
              const r = 40.0;
              final dx = math.cos(angle) * r;
              final dy = math.sin(angle) * r;
              return Positioned(
                left: 100 + dx - 10,
                top: 100 + dy - 10,
                child: Text(icons[i + 8], style: const TextStyle(fontSize: 19)),
              );
            }),
            Transform.scale(
              scale: scale.value,
              child: const Text('🛍️', style: TextStyle(fontSize: 46)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Video Animation (Asset)
// ─────────────────────────────────────────────────────────────────
class _VideoAnimation extends StatefulWidget {
  final String assetPath;
  const _VideoAnimation({required this.assetPath});

  @override
  State<_VideoAnimation> createState() => _VideoAnimationState();
}

class _VideoAnimationState extends State<_VideoAnimation> {
  static final Map<String, VideoPlayerController> _controllers = {};
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _VideoAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _initController();
    }
  }

  void _initController() {
    final path = widget.assetPath;
    _hasError = false;

    if (_controllers.containsKey(path)) {
      _controller = _controllers[path];
      if (_controller!.value.isInitialized) {
        if (!_controller!.value.isPlaying) {
          _controller!.play();
        }
      }
      setState(() {});
      return;
    }

    final controller = VideoPlayerController.asset(path)
      ..setLooping(true)
      ..setVolume(0.0);

    _controllers[path] = controller;
    _controller = controller;

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        controller.play();
      }
    }).catchError((error) {
      debugPrint("Error initializing video $path: $error");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError || controller == null) {
      return const SizedBox.expand(
        child: Center(
          child: Icon(Icons.play_circle_outline, size: 60, color: Colors.white70),
        ),
      );
    }

    if (!controller.value.isInitialized) {
      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
