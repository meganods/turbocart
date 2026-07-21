import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/snackbar_utils.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  // Animation controllers for the map-pin illustration
  late AnimationController _pinBounce;
  late AnimationController _rippleCtrl;
  late Animation<double> _pinY;
  late Animation<double> _ripple;

  @override
  void initState() {
    super.initState();

    _pinBounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pinY = Tween<double>(begin: -12, end: 0).animate(
        CurvedAnimation(parent: _pinBounce, curve: Curves.easeInOutSine));

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _ripple = Tween<double>(begin: 0, end: 1).animate(_rippleCtrl);
  }

  @override
  void dispose() {
    _pinBounce.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  // ── Permission + GPS flow ──────────────────────────────────────────────────

  Future<void> _handleAllowLocation() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            SnackBarUtils.showTopSnackBar(
              context,
              'Permission denied. Please enter location manually.',
              backgroundColor: Colors.red,
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedDialog();
        setState(() => _isLoading = false);
        return;
      }

      await _fetchGPS();
    } catch (e) {
      debugPrint("Error requesting location permission: $e");
      // Fallback to fetch GPS directly
      await _fetchGPS();
    }
  }

  Future<void> _fetchGPS() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        context.go('/location-search', extra: {
          'fromGPS': true,
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showTopSnackBar(
          context,
          'Could not get GPS location. Please enter manually.',
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Permission Denied'),
        content: const Text(
          'Location access is permanently disabled.\nPlease enable it from Settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0C831F)),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Skip',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ),

              const Spacer(),

              // Animated illustration
              _buildIllustration(),

              const SizedBox(height: 40),

              // Heading
              const Text(
                "What's your location?",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              // Sub-text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'We need your location to show stores\nand delivery options near you',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // Allow location button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleAllowLocation,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Allow location access',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Manual entry button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0C831F), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go('/location-search'),
                  child: const Text(
                    'Enter location manually',
                    style: TextStyle(
                        color: Color(0xFF0C831F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          AnimatedBuilder(
            animation: _ripple,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(260, 260),
                painter: _RipplePainter(_ripple.value),
              );
            },
          ),

          // Map background circle
          Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8F5E9),
            ),
          ),

          // Map grid lines
          CustomPaint(
            size: const Size(180, 180),
            painter: _MapGridPainter(),
          ),

          // Bouncing pin
          AnimatedBuilder(
            animation: _pinY,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _pinY.value - 20),
                child: _buildPin(),
              );
            },
          ),

          // Pin shadow
          AnimatedBuilder(
            animation: _pinBounce,
            builder: (context, child) {
              final scale = 0.6 + 0.4 * (_pinY.value + 12) / 12;
              return Positioned(
                bottom: 55,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 28,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF0C831F),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x440C831F), blurRadius: 16, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 30),
        ),
        // Pointer tip
        CustomPaint(size: const Size(16, 10), painter: _PinTipPainter()),
      ],
    );
  }
}

// ── Painters ────────────────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final t = (progress - i * 0.33).clamp(0.0, 1.0);
      if (t == 0) continue;
      final paint = Paint()
        ..color = const Color(0xFF0C831F).withValues(alpha: (1 - t) * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 70 + 70 * t, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..strokeWidth = 1;
    // horizontal lines
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // vertical lines
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // small road dashes
    final roadPaint = Paint()
      ..color = const Color(0xFFA5D6A7)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(45, 0), const Offset(45, 180), roadPaint);
    canvas.drawLine(const Offset(0, 90), const Offset(180, 90), roadPaint);
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path,
        Paint()..color = const Color(0xFF0C831F));
  }

  @override
  bool shouldRepaint(_PinTipPainter old) => false;
}
