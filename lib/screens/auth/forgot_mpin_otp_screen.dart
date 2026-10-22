import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/widget/common_pin_field.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/screens/auth/otp_screen.dart';
import 'package:mprs_android/screens/auth/signup_screen.dart';
import 'package:mprs_android/utils/snackbar_helper.dart';

class ForgotMpinOtpScreen extends StatefulWidget {
  const ForgotMpinOtpScreen({super.key});

  @override
  State<ForgotMpinOtpScreen> createState() => _ForgotMpinOtpScreenState();
}

class _ForgotMpinOtpScreenState extends State<ForgotMpinOtpScreen> {
  String _mpin = '';
  int _secondsRemaining = 30;
  Timer? _timer;

  void _onSubmitMpin(String value) {
    if (value == '1234') {
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => const MainScreen()),
      // );
    } else {
      showSnackBar(context, 'Invalid MPIN');
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 65, 30, 30),
          // top padding to push content a bit down but not centered
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Company Logo
              Image.asset(
                'assets/images/mprs_logo.png',
                // Ensure this asset exists & is in pubspec.yaml
                height: 60,
              ),
              const SizedBox(height: 20),

              // Greeting
              Text(
                'Enter OTP',
                style: AppTextStyles.montserratBold.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Instruction
              Text(
                'Enter the OTP we’ve sent to your number.',
                style: AppTextStyles.montserratBold.copyWith(
                  fontSize: 16,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),

              CommonPinCodeField(
                onChanged: (value) => _mpin = value,
                onCompleted: _onSubmitMpin,
              ),

              const SizedBox(height: 5),

              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          _secondsRemaining == 0
                              ? () {
                                _startTimer(); // restart timer
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const OTPScreen(),
                                  ),
                                );
                              }
                              : null,
                      child: Text(
                        'Resend',
                        style: AppTextStyles.montserratSemiBold.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ),
                    Text(
                      _secondsRemaining > 0
                          ? _formatTime(_secondsRemaining)
                          : '',
                      style: AppTextStyles.montserratBold.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              MainButton(text: 'Verify', onPressed: () {}),
              const SizedBox(height: 25),

              // Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTextStyles.montserratRegular.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: AppTextStyles.montserratSemiBold.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
