import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/login_response.dart';
import 'package:mprs_android/screens/auth/new_mpin_screen.dart';
import 'package:mprs_android/screens/auth/signup_screen.dart';
import 'package:mprs_android/service/fcm_token_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'forgot_password_screen.dart';

class LoginPasswordScreen extends StatefulWidget {
  final String mobileNumber;

  const LoginPasswordScreen({super.key, required this.mobileNumber});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final _passwordController = TextEditingController();
  String? _errorText;
  final FocusNode _passwordFocusNode = FocusNode();
  bool _passwordVisible = false;

  late final WebViewController _ourServicesController;
  double _webViewHeight = 300;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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

  bool isValidIndianNumber(String number) {
    number = number.replaceAll(RegExp(r'\s+'), '');
    if (number.startsWith('+91')) {
      number = number.substring(3);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(number);
  }

  void _validate() {
    FocusScope.of(context).unfocus();
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorText = "Please enter your password");
      return;
    }

    setState(() => _errorText = null);

    login();
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
              Image.asset('assets/images/mprs_logo.png', height: 50),
              const SizedBox(height: 20),

              Text(
                'Welcome',
                style: AppTextStyles.montserratBold.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(fontSize: 16, color: AppColors.black),
                  children: [
                    const TextSpan(text: 'Please enter your password for\n '),
                    TextSpan(
                      text: '+91 ${widget.mobileNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              buildPasswordField(
                controller: _passwordController,
                label: "Enter your password",
                errorText: _errorText,
                onChanged: (value) {
                  // validation here
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          mobileNumber: widget.mobileNumber,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: AppColors.main,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                ),

              const SizedBox(height: 30),

              // Continue button
              MainButton(text: 'Login', onPressed: _validate),

              const SizedBox(height: 25),

              // Sign Up option
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

              // Our Services HTML section
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

  Future<void> login() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.unfocus();
      FocusScope.of(context).unfocus();
    });

    ProgressLoader.show(context);

    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    try {
      var response = await HttpClientHelper.postWithApplicationJson(
        ApiConstants.login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mobile': widget.mobileNumber,
          'password': _passwordController.text.trim(),
        }),
      );

      ProgressLoader.hide(context);

      /// Decode the response first
      final decoded = jsonDecode(response.data);

      /// Convert to object
      final userData = LoginResponse.fromJson(decoded);

      /// Check success
      if (response.statusCode == 200 && userData.user != null) {
        // save user
        AuthDataHelper.saveUserData(userData.user!);
        DbHelper().saveUserModel(userData.user);
        DbHelper().saveUserToken(userData.token);
        // save token
        AuthDataHelper.saveUserToken(userData.token);
        if (userData.user?.accountId != null &&
            userData.user!.accountId!.isNotEmpty) {
          AuthDataHelper.saveAccountId(userData.user!.accountId!);
        }
        // AuthDataHelper.saveAccountId(userData.user?.accountId ?? "");
        print("🔥 SAVED ACCOUNT ID: ${AuthDataHelper.getAccountId()}");
        await FcmTokenService.syncToBackend();
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => NewMpinScreen()),
        );
      } else {
        showSnackBar(context, decoded['message'] ?? "Login failed");
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error during login: $e');
    }
  }

  Widget buildPasswordField({
    required TextEditingController controller,
    required String label,
    Function(String)? onChanged,
    String? errorText,
  }) {
    return TextFormField(
      focusNode: _passwordFocusNode,
      obscureText: !_passwordVisible,
      controller: controller,
      keyboardType: TextInputType.text,
      autovalidateMode: AutovalidateMode.onUserInteraction,

      onChanged: (value) {
        if (onChanged != null) onChanged(value);
        setState(() {
          if (value.trim().length == 1) {
            _errorText = null;
          }
        });
      },

      style: TextStyle(color: Colors.black, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: errorText == null ? Colors.grey : AppColors.secondary,
          fontSize: 16,
        ),
        errorStyle: TextStyle(
          color: errorText == null ? Colors.grey : AppColors.secondary,
          fontSize: 14,
        ),
        prefixStyle: TextStyle(color: Colors.black, fontSize: 16),

        filled: true,
        fillColor: AppColors.white,

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                errorText == null ? AppColors.lightGrey : AppColors.secondary,
            width: 1.3,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                errorText == null ? AppColors.lightGrey : AppColors.secondary,
            width: 1.6,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? AppColors.secondary : AppColors.main,
            width: 1.6,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _passwordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _passwordVisible = !_passwordVisible;
            });
          },
        ),
      ),
    );
  }
}
