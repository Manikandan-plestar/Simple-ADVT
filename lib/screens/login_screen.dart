import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  bool _isValidEmail = false;
  bool _isOtpSent = false;
  bool _isSendingOtp = false;
  bool _isResendingOtp = false;
  bool _isVerifyingOtp = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final valid = email.isNotEmpty && emailRegex.hasMatch(email);
    if (_isValidEmail != valid) {
      setState(() {
        _isValidEmail = valid;
        if (_isValidEmail) {
          _errorMessage = null;
        }
      });
    }
  }

  void _startResendTimer([int seconds = 30]) {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = seconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _otpController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail || _isSendingOtp) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final response = await authService.sendOtp(email);

    if (mounted && response.success) {
      setState(() {
        _isSendingOtp = false;
        _isOtpSent = true;
      });
      _startResendTimer(60);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(response.message),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isSendingOtp = false;
        _errorMessage = response.message;
      });
    }
  }

  void _handleResendOtp() async {
    if (_resendCountdown > 0 || _isResendingOtp || _isSendingOtp) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isResendingOtp = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final response = await authService.resendOtp(email);

    if (mounted && response.success) {
      setState(() {
        _isResendingOtp = false;
      });
      _startResendTimer(60);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(response.message),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isResendingOtp = false;
        _errorMessage = response.message;
      });
    }
  }

  void _handleEditEmail() {
    _resendTimer?.cancel();
    setState(() {
      _isOtpSent = false;
      _otpController.clear();
      _errorMessage = null;
      _resendCountdown = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _emailFocusNode.requestFocus();
      }
    });
  }

  void _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6 || _isVerifyingOtp) {
      if (otp.length != 6) {
        setState(() {
          _errorMessage = 'Please enter a valid 6-digit OTP';
        });
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final response = await authService.verifyOtp(otp);

    if (!mounted) return;

    setState(() {
      _isVerifyingOtp = false;
    });

    if (response.success) {
      if (response.isExistingUser) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        Navigator.pushReplacementNamed(context, '/register');
      }
    } else {
      setState(() {
        _errorMessage = response.message;
      });
    }
  }

  void _showTermsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Terms and Conditions & Privacy Policy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Acceptance of Terms\n'
                'By accessing or using  ADVT, you agree to be bound by these Terms and Conditions and our Privacy Policy.\n\n'
                '2. User Verification\n'
                'You must provide a valid email address to verify your identity and access our platform features.\n\n'
                '3. Privacy & Data Security\n'
                'We respect your privacy and protect your personal information in accordance with industry security standards.\n\n'
                '4. Service Availability\n'
                ' ADVT connects local businesses with customers based on targeted locations.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('I Understand'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),

                      // 1. Welcome Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A4F46E5),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ADVT',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Explore & Advertise',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Welcome Subtitle
                      const Text(
                        'Welcome to ADVT',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your email address to receive a verification OTP.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 2. Email Address Input Field
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isOtpSent,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFF1F5F9),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF4F46E5),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Error message container if any
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Initial State: Send OTP Button
                      if (!_isOtpSent) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_isValidEmail && !_isSendingOtp)
                                ? _handleSendOtp
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              disabledBackgroundColor: const Color(0xFFC7D2FE),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isSendingOtp
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Text(
                                    'Send OTP',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],

                      // 4. OTP State: OTP Input & Verify Button
                      if (_isOtpSent) ...[
                        const Text(
                          'Enter OTP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _otpController,
                          focusNode: _otpFocusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF111827),
                            letterSpacing: 2.0,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter 6-digit OTP',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                              letterSpacing: 0,
                            ),
                            counterText: '',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF4F46E5),
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Verify OTP Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              disabledBackgroundColor: const Color(0xFFC7D2FE),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isVerifyingOtp
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Text(
                                    'Verify OTP',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Edit Email and Resend OTP Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _handleEditEmail,
                              child: const Text(
                                'Edit Email',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: (_resendCountdown == 0 && !_isResendingOtp)
                                  ? _handleResendOtp
                                  : null,
                              child: _isResendingOtp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    )
                                  : Text(
                                      _resendCountdown > 0
                                          ? 'Resend in $_resendCountdown seconds'
                                          : 'Resend OTP',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _resendCountdown > 0
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                        color: _resendCountdown > 0
                                            ? const Color(0xFF6B7280)
                                            : const Color(0xFF4F46E5),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: 32),

                      // Terms and Conditions Section
                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                            children: [
                              const TextSpan(text: 'By continuing, you agree to our\n'),
                              TextSpan(
                                text: 'Terms and Conditions',
                                style: const TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                ..onTap = _showTermsDialog,
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                ..onTap = _showTermsDialog,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
