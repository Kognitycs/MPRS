import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/navigation_util.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/widget/common_pin_field.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NewMpinScreen extends StatefulWidget {
  const NewMpinScreen({super.key});

  @override
  State<NewMpinScreen> createState() => _NewMpinScreenState();
}

class _NewMpinScreenState extends State<NewMpinScreen> {
  String _newMpin = '';
  String _confirmMpin = '';

  late final WebViewController _ourServicesController;
  double _webViewHeight = 300;

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

  void _submitMpin() async {
    if (_newMpin.isEmpty || _confirmMpin.isEmpty) {
      showSnackBar(context, 'Please enter and confirm your MPIN');
      return;
    }

    if (_newMpin.length < 4 || _confirmMpin.length < 4) {
      showSnackBar(context, 'MPIN must be 4 digits');
      return;
    }

    if (_newMpin != _confirmMpin) {
      showSnackBar(context, 'MPINs do not match');
      return;
    }

    AuthDataHelper.saveMPin(_newMpin);
    showSnackBar(context, 'MPIN set successfully');
    NavigationUtil.toMainScreen(context);
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
              // Company Logo
              Image.asset('assets/images/mprs_logo.png', height: 50),
              const SizedBox(height: 20),

              Text(
                'Set New MPIN',
                style: AppTextStyles.montserratBold.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),

              // Instruction
              Text(
                'Please enter your new MPIN.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // New MPIN
              CommonPinCodeField(onChanged: (value) => _newMpin = value),

              const SizedBox(height: 8),

              // Instruction
              Text(
                'Please re-enter your new MPIN.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Confirm MPIN
              CommonPinCodeField(onChanged: (value) => _confirmMpin = value),

              const SizedBox(height: 25),
              MainButton(text: 'Submit', onPressed: _submitMpin),
              const SizedBox(height: 30),

              // Our Services HTML — same as login / MPIN screens
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
}
