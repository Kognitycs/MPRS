import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/navigation_util.dart';
import 'package:mprs_android/service/fcm_token_service.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/screens/auth/signup_screen.dart';
import 'package:mprs_android/widget/common_pin_field.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/widget/or_divider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginWithMpinScreen extends StatefulWidget {
  const LoginWithMpinScreen({super.key});

  @override
  State<LoginWithMpinScreen> createState() => _LoginWithMpinScreenState();
}

class _LoginWithMpinScreenState extends State<LoginWithMpinScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String name = "";

  late final WebViewController _ourServicesController;
  double _webViewHeight = 300;

  @override
  void initState() {
    super.initState();
    name = "${AuthDataHelper.getFirstName()} ${AuthDataHelper.getLastName()}";
    _initOurServicesWebView();
  }

  void _initOurServicesWebView() {
    _ourServicesController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..addJavaScriptChannel(
            'FlutterHeight',
            onMessageReceived: (msg) {
              final h = double.tryParse(msg.message);
              if (h != null && h > 0 && mounted) {
                setState(() => _webViewHeight = h);
              }
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                _ourServicesController.runJavaScript(
                  "FlutterHeight.postMessage(document.body.scrollHeight.toString());",
                );
              },
            ),
          )
          ..loadFlutterAsset('assets/our_services.html');
  }

  Future<void> _onSubmitMpin(String value) async {
    if (AuthDataHelper.getMPin() == value) {
      await FcmTokenService.syncToBackend();
      if (!context.mounted) return;
      NavigationUtil.toMainScreen(context);
    } else {
      showSnackBar(context, 'Invalid MPIN');
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
              // Company Logo
              Image.asset(
                'assets/images/mprs_logo.png',
                // Ensure this asset exists & is in pubspec.yaml
                height: 50,
              ),
              const SizedBox(height: 20),

              // Greeting
              Text(
                name,
                style: AppTextStyles.montserratBold.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Instruction
              Text(
                'Welcome back! Please enter your MPIN.',
                style: TextStyle(fontSize: 16, color: AppColors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),

              CommonPinCodeField(onCompleted: _onSubmitMpin),

              const SizedBox(height: 30),
              OrDivider(),

              const SizedBox(height: 25),
              BiometricButton(onPressed: _authenticateWithBiometrics),
              const SizedBox(height: 25),

              // Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Our Services HTML — same as login screen
              SizedBox(
                height: _webViewHeight,
                child: WebViewWidget(controller: _ourServicesController),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isAuthenticated = false;

      if (canCheckBiometrics) {
        isAuthenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
      }

      if (isAuthenticated) {
        await FcmTokenService.syncToBackend();
        if (!context.mounted) return;
        NavigationUtil.toMainScreen(context);
      } else {
        showSnackBar(context, 'Biometric authentication failed');
      }
    } catch (e) {
      showSnackBar(context, 'Error: $e');
    }
  }
}
