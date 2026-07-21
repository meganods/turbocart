import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/colors.dart';
import '../utils/snackbar_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String _selectedCountryCode = '+91';

  final String _logoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="80" height="80">
  <circle cx="12" cy="12" r="11" fill="#0C831F"/>
  <path d="M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z" fill="#F8C200"/>
</svg>
''';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      SnackBarUtils.showTopSnackBar(context, 'Please enter your mobile number');
      return;
    }
    
    if (phone.length != 10) {
      SnackBarUtils.showTopSnackBar(context, 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final fullPhoneNumber = '$_selectedCountryCode$phone';

    setState(() {
      _isLoading = false;
    });

    SnackBarUtils.showTopSnackBar(
      context, 
      'OTP sent successfully! (Use any 6 digits)', 
      backgroundColor: TurbocartColors.primary
    );

    context.go('/otp', extra: {
      'verificationId': 'mock-ver-id-12345',
      'phoneNumber': fullPhoneNumber,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
              // Centered Turbocart Logo
              Center(
                child: Column(
                  children: [
                    SvgPicture.string(
                      _logoSvg,
                      width: 80,
                      height: 80,
                      placeholderBuilder: (context) => const SizedBox(width: 80, height: 80),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'turbocart',
                      style: TextStyle(
                        color: TurbocartColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Heading
              const Text(
                'Enter your mobile number',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TurbocartColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We will send a 6-digit verification code',
                style: TextStyle(
                  fontSize: 13,
                  color: TurbocartColors.textGrey,
                ),
              ),
              const SizedBox(height: 24),
              // Country code + TextField
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: TurbocartColors.lightGrey, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        items: <String>['+91', '+1', '+44', '+971'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: TurbocartColors.textDark,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCountryCode = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 1,
                      height: 24,
                      color: TurbocartColors.lightGrey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: 'Mobile Number',
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ElevatedButton
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
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
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'By continuing, you agree to our Terms of Service & Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: TurbocartColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}
