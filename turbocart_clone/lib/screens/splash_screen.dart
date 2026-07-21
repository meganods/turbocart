import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // SVG String of a clean, premium shopping cart in a circle
  final String _cartSvgString = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="80" height="80">
  <circle cx="12" cy="12" r="11" fill="#0C831F"/>
  <path d="M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z" fill="#F8C200"/>
</svg>
''';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // Start timer for navigation
    Timer(const Duration(milliseconds: 2500), _navigateToNextScreen);
  }

  bool _isVersionOutdated(String current, String minimum) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final minimumParts = minimum.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final currentVal = i < currentParts.length ? currentParts[i] : 0;
        final minimumVal = i < minimumParts.length ? minimumParts[i] : 0;
        if (currentVal < minimumVal) return true;
        if (currentVal > minimumVal) return false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    // Minimum App Version Enforcement Check
    try {
      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('store').get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null) {
          final String minVer = data['minimum_version'] ?? '1.0.0';
          final bool needsUpdate = _isVersionOutdated('1.0.0', minVer);
          if (needsUpdate && mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Update Required', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Text('A newer version of the app ($minVer) is available. Please update to continue using the app.'),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      // Mock redirection link
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: TurbocartColors.primary),
                    child: const Text('Update Now', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Minimum version query failed: $e. Proceeding with routing fallback.');
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.isLoggedIn) {
      // Check if user has a saved address
      final prefs = await SharedPreferences.getInstance();
      final hasAddress =
          (prefs.getString('addressText') ?? '').isNotEmpty;

      if (!mounted) return;
      if (hasAddress) {
        // Load cached address into provider
        await userProvider.loadSavedAddress();
        if (!mounted) return;
        context.go('/home');
      } else {
        context.go('/location-permission');
      }
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(
                  _cartSvgString,
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 24),
                const Text(
                  'turbocart',
                  style: TextStyle(
                    color: TurbocartColors.primary,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'India\'s last minute app',
                  style: TextStyle(
                    color: TurbocartColors.textGrey.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
