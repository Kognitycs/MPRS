import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/screens/auth/otp_screen.dart';
import 'package:mprs_android/utils/snackbar_helper.dart';

class ForgotMpinScreen extends StatefulWidget {
  const ForgotMpinScreen({super.key});

  @override
  State<ForgotMpinScreen> createState() => _ForgotMpinScreenState();
}

class _ForgotMpinScreenState extends State<ForgotMpinScreen> {
  String _mpin = '';
  bool _isError = false;
  String? _errorText;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool isValidIndianNumber(String number) {
    number = number.replaceAll(RegExp(r'\s+'), '');
    if (number.startsWith('+91')) {
      number = number.substring(3);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(number);
  }

  void _validatePhone() {
    final input = _phoneController.text;
    if (isValidIndianNumber(input)) {
      setState(() {
        _errorText = null;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OTPScreen()),
      );
    } else {
      setState(() {
        _errorText = 'Invalid number. Please try again.';
      });
    }
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
              Image.asset(
                'assets/images/mprs_logo.png',
                // Ensure this asset exists & is in pubspec.yaml
                height: 60,
              ),
              const SizedBox(height: 20),

              // Greeting
              Text(
                'Forgot MPIN?',
                style: AppTextStyles.montserratBold.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Instruction
              Text(
                'No worries, we’ll send you reset instruction.',
                style: AppTextStyles.montserratRegular.copyWith(
                  fontSize: 16,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),

              // Phone number input
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Enter your number',
                  labelStyle: TextStyle(
                    color:
                        _errorText == null ? Colors.grey : AppColors.secondary,
                  ),
                  prefixText: '+91 ',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _errorText == null
                              ? Colors.grey
                              : AppColors.secondary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _errorText == null
                              ? Colors.grey
                              : AppColors.secondary,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorText!,
                    style: AppTextStyles.montserratRegular.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              MainButton(text: 'Continue', onPressed: _validatePhone),

              const SizedBox(height: 30),
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
                          style: const TextStyle(
                            color: AppColors.secondary, // Orange
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pop(
                                    context,
                                  ); // or Navigator.pushNamed(context, '/signin');
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
