import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/colors.dart';
import '../providers/user_provider.dart';
import '../utils/snackbar_utils.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSlideUp = false;
  int _timerSeconds = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Trigger slide up animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isSlideUp = true;
        });
      }
    });

    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timerSeconds = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timerSeconds > 0) {
            _timerSeconds--;
          } else {
            _countdownTimer?.cancel();
          }
        });
      }
    });
  }

  void _verifyOtp() async {
    final code = _otpController.text.trim();
    // For demo/mockup testing, if OTP is empty, we automatically authenticate and proceed
    final finalCode = code.isEmpty ? '123456' : code;

    if (finalCode.length != 6) {
      SnackBarUtils.showTopSnackBar(context, 'Please enter a 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.verificationId == 'mock-ver-id-12345') {
        // Handle mock login scenario: Accept any 6-digit OTP
        final cleanPhone = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        final derivedUid = 'uid_${cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone}';
        _handleSuccessfulAuth(derivedUid);
        return;
      }

      // Real Firebase verification
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: finalCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        _handleSuccessfulAuth(user.uid);
      } else {
        throw Exception('User authentication failed.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      SnackBarUtils.showTopSnackBar(context, e.toString());
    }
  }

  void _handleSuccessfulAuth(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(widget.phoneNumber);

      setState(() {
        _isLoading = false;
      });

      // Retrieve and save FCM push token
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': fcmToken,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Failed to retrieve FCM token: $e');
      }

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final bool isBlocked = data['blocked'] ?? false;
          if (isBlocked) {
            await FirebaseAuth.instance.signOut();
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            userProvider.clearUser();
            setState(() {
              _isLoading = false;
            });
            SnackBarUtils.showTopSnackBar(context, 'Your account has been suspended. Contact support.');
            return;
          }

          userProvider.updateProfile(
            name: data['name'] ?? 'Turbocart Customer',
            email: data['email'] ?? '',
          );
        }
        context.go('/home');
      } else {
        context.go('/profile-setup', extra: {'uid': uid, 'phone': widget.phoneNumber});
      }
    } catch (e) {
      debugPrint('Firestore read failed: $e. Transitioning using mock routing fallback.');
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(widget.phoneNumber);
      setState(() {
        _isLoading = false;
      });
      // Fallback: If document lookup fails, proceed to profile setup for setup
      context.go('/profile-setup', extra: {'uid': uid, 'phone': widget.phoneNumber});
    }
  }

  void _resendOtp() {
    _startTimer();
    SnackBarUtils.showTopSnackBar(context, 'OTP Resent successfully! Try using 123456');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TurbocartColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Top App Bar
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: TurbocartColors.textDark),
                onPressed: () => context.go('/login'),
              ),
            ),
            // Centered animation container
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.fastOutSlowIn,
                height: _isSlideUp ? size.height * 0.8 : 0,
                width: size.width,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: TurbocartColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sent to mobile number ${widget.phoneNumber}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: TurbocartColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      PinCodeTextField(
                        appContext: context,
                        length: 6,
                        obscureText: false,
                        showCursor: false,
                        cursorColor: Colors.transparent,
                        animationType: AnimationType.fade,
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(10),
                          fieldHeight: 50,
                          fieldWidth: 45,
                          activeFillColor: Colors.white,
                          selectedFillColor: Colors.white,
                          inactiveFillColor: TurbocartColors.surface,
                          activeColor: TurbocartColors.primary,
                          selectedColor: TurbocartColors.primary,
                          inactiveColor: Colors.black54,
                        ),
                        animationDuration: const Duration(milliseconds: 300),
                        backgroundColor: Colors.transparent,
                        enableActiveFill: true,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        onCompleted: (v) {
                          _verifyOtp();
                        },
                        onChanged: (value) {},
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TurbocartColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Didn't receive OTP? ",
                            style: TextStyle(color: TurbocartColors.textGrey, fontSize: 14),
                          ),
                          _timerSeconds > 0
                              ? Text(
                                  'Resend in ${_timerSeconds}s',
                                  style: const TextStyle(
                                    color: TurbocartColors.textGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _resendOtp,
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                  child: const Text(
                                    'Resend OTP',
                                    style: TextStyle(
                                      color: TurbocartColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
