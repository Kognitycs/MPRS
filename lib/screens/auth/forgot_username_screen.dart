import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import '../../core/constants/app_colors.dart';
import '../../utils/snackbar_helper.dart';
import 'login_mobile_screen.dart';

class ForgotUsernameScreen extends StatefulWidget {
  const ForgotUsernameScreen({super.key});

  @override
  State<ForgotUsernameScreen> createState() => _ForgotUsernameScreenState();
}

class _ForgotUsernameScreenState extends State<ForgotUsernameScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _recoverUsername() {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showSnackBar(context, 'Please enter your email');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      showSnackBar(context, 'Please enter a valid email address');
      return;
    }


    showSnackBar(context, 'If this email is registered, a recovery link has been sent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
               Text(
                'Forgot Username?',
                style: AppTextStyles.montserratBold.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your registered email to recover your username',
                style: AppTextStyles.montserratRegular.copyWith(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              /// Email TextField
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.montserratSemiBold.copyWith(
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.grey,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.grey,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              /// Recover Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _recoverUsername,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.lightBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'RECOVER USERNAME',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              /// Bottom Login Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Remember your username? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginMobileScreen()),
                      );
                    },
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        color: AppColors.main,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
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
