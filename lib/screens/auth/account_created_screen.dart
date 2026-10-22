import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/auth/login_mobile_screen.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class AccountCreatedScreen extends StatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
              const SizedBox(height: 80),
              Image.asset(
                "assets/images/success.png", // green shield check
                height: 70,
              ),

              const SizedBox(height: 30),

              // Title
              const Text(
                "Account Successfully\nCreated!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold, // Bold
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 20),

              MainButton(
                text: 'Login Now',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginMobileScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
