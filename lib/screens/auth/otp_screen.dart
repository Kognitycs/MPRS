import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/widget/common_pin_field.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/screens/auth/new_mpin_screen.dart';
import 'package:mprs_android/utils/snackbar_helper.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  String _otp = '';

  void _onSubmitOtp(String value) {
    if (value == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NewMpinScreen()),
      );
    } else {
      showSnackBar(context, 'Invalid OTP');
    }
  }

  void _resendOtp() {
    showSnackBar(context, 'OTP resent successfully');
  }

  void _verifyOtp() {
    if (_otp.isEmpty) {
      showSnackBar(context, 'Please enter the OTP');
      return;
    }
    _onSubmitOtp(_otp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 65, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo
              Image.asset('assets/images/mprs_logo.png', height: 60),
              const SizedBox(height: 20),

              Text(
                'Enter OTP',
                style: AppTextStyles.montserratRegular.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'Enter the OTP we’ve sent to your number.',
                style: AppTextStyles.montserratRegular.copyWith(
                  fontSize: 16,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),

              // OTP field
              CommonPinCodeField(
                onChanged: (value) => _otp = value,
                onCompleted: _onSubmitOtp,
                obscureText: false,
              ),
              const SizedBox(height: 5),

              // Resend button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resendOtp,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Resend',
                    style: AppTextStyles.montserratRegular.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Verify button
              MainButton(text: 'Verify', onPressed: _verifyOtp),

              const SizedBox(height: 30),

              // Back to Sign In
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back, size: 18, color: Colors.black),
                  const SizedBox(width: 4),
                  RichText(
                    text: TextSpan(
                      text: 'Back to ',
                      style: AppTextStyles.montserratRegular.copyWith(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: AppTextStyles.montserratBold.copyWith(
                            color: AppColors.secondary,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pop(context);
                                },
                        ),
                      ],
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
