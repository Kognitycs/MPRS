import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/screens/auth/change_your_password_screen.dart';
import 'package:mprs_android/screens/auth/login_mobile_screen.dart';
import 'package:mprs_android/service/phone_auth_service.dart';
import 'package:mprs_android/widget/common_pin_field.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class ForgotPasswordScreen extends StatefulWidget {
  /// Mobile used at login; OTP is sent to this number (not email).
  final String? mobileNumber;

  const ForgotPasswordScreen({super.key, this.mobileNumber});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  String _otp = '';
  String? _otpError;
  int _secondsRemaining = 30;
  static const _resendCooldownSeconds = 30;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;

  String get _mobileDigits =>
      widget.mobileNumber?.replaceAll(RegExp(r'\D'), '') ?? '';

  String get _fullMobileNumber => '+91$_mobileDigits';

  @override
  void initState() {
    super.initState();
    if (_mobileDigits.length != 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showSnackBar(context, 'Please enter a valid mobile number to continue.');
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _maskedPhone(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      final last4 = digits.substring(digits.length - 4);
      return '+91 XXXXXX$last4';
    }
    return '+91 $mobile';
  }

  void _startResendTimer() {
    _timer?.cancel();
    final fromService = PhoneAuthService.secondsUntilResendAllowed(_fullMobileNumber);
    final wait = fromService > 0 ? fromService : _resendCooldownSeconds;
    setState(() => _secondsRemaining = wait);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_mobileDigits.length != 10 || _isSendingOtp) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSendingOtp = true;
      _otpError = null;
    });
    ProgressLoader.show(context);

    try {
      final result = await _phoneAuthService.sendOtp(_fullMobileNumber);
      if (!mounted) return;

      if (result.isAutoVerified) {
        ProgressLoader.hide(context);
        setState(() => _otpSent = true);
        await _completeOtpVerification(result.autoVerifiedIdToken!);
        return;
      }

      setState(() => _otpSent = true);
      _startResendTimer();
      showSnackBar(
        context,
        'OTP sent to ${_maskedPhone(_mobileDigits)}',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.message ?? 'Failed to send OTP. Please try again.';
      setState(() => _otpError = message);
      showSnackBar(context, message);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _otpError = message);
      showSnackBar(context, message);
    } finally {
      ProgressLoader.hide(context);
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isSendingOtp) return;
    await _sendOtp();
  }

  Future<void> _completeOtpVerification(String idToken) async {
    await _phoneAuthService.tryVerifyPhoneWithBackend(idToken);
    if (!mounted) return;

    ProgressLoader.hide(context);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeYourPasswordScreen(
          mobileNumber: _mobileDigits,
        ),
      ),
    );

    await _phoneAuthService.signOut();
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;
    if (!_otpSent) {
      showSnackBar(context, 'Please tap Send OTP first.');
      return;
    }
    if (_otp.length != 6) {
      showSnackBar(context, 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _otpError = null;
    });
    ProgressLoader.show(context);

    try {
      final idToken = await _phoneAuthService.verifySmsCodeAndGetIdToken(_otp);
      if (!mounted) return;
      ProgressLoader.hide(context);
      await _completeOtpVerification(idToken);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = e.message ?? 'Invalid OTP. Please try again.';
      });
      await _phoneAuthService.clearFirebaseSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = e.toString().replaceFirst('Exception: ', '');
      });
      await _phoneAuthService.clearFirebaseSession();
    } finally {
      ProgressLoader.hide(context);
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneHint = _mobileDigits.isNotEmpty
        ? _maskedPhone(_mobileDigits)
        : 'your registered mobile number';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Recover your Password',
          style: AppTextStyles.montserratSemiBold.copyWith(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/mprs_logo.png',
                        height: 52,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Forgot your password?',
                      style: AppTextStyles.montserratBold.copyWith(
                        fontSize: 22,
                        color: AppColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _otpSent
                          ? 'No worries. Enter the 6-digit OTP we sent to $phoneHint to recover your account.'
                          : 'Tap Send OTP to receive a verification code at $phoneHint.',
                      style: AppTextStyles.montserratRegular.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF5F6368),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Enter OTP',
                      style: AppTextStyles.montserratSemiBold.copyWith(
                        fontSize: 16,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CommonPinCodeField(
                      length: 6,
                      obscureText: false,
                      onChanged: (value) {
                        _otp = value;
                        if (_otpError != null) {
                          setState(() => _otpError = null);
                        }
                      },
                      onCompleted: (_) => _verifyOtp(),
                    ),
                    if (_otpError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _otpError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    if (_otpSent) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: _secondsRemaining > 0
                            ? Text(
                                'Resend OTP in ${_secondsRemaining}s',
                                style: AppTextStyles.montserratRegular.copyWith(
                                  fontSize: 14,
                                  color: const Color(0xFF9AA0A6),
                                ),
                              )
                            : GestureDetector(
                                onTap: _isSendingOtp ? null : _resendOtp,
                                child: Text(
                                  'Resend OTP',
                                  style: AppTextStyles.montserratSemiBold.copyWith(
                                    fontSize: 14,
                                    color: _isSendingOtp
                                        ? AppColors.grey
                                        : AppColors.secondary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.secondary,
                                  ),
                                ),
                              ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (!_otpSent)
                      MainButton(
                        text: _isSendingOtp ? 'Sending...' : 'Send OTP',
                        onPressed: _isSendingOtp ? () {} : _sendOtp,
                      )
                    else
                      MainButton(
                        text: _isVerifying ? 'Verifying...' : 'Verify',
                        onPressed: _isVerifying ? () {} : _verifyOtp,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Remember your password? ',
                    style: AppTextStyles.montserratRegular.copyWith(
                      fontSize: 14,
                      color: AppColors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginMobileScreen(),
                        ),
                        (_) => false,
                      );
                    },
                    child: Text(
                      'Log in',
                      style: AppTextStyles.montserratSemiBold.copyWith(
                        fontSize: 14,
                        color: AppColors.main,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.main,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
