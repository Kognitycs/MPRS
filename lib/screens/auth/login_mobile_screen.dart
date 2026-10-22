import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/model/country_code_model.dart';
import 'package:mprs_android/screens/auth/login_password_screen.dart';
import 'package:mprs_android/screens/auth/signup_screen.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({super.key});

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final _phoneController = TextEditingController();
  String? _errorText;
  CountryCodeModel selectedCountry = CountryCodeModel(
    name: "India",
    code: "IN",
    dialCode: "+91",
    flag: "🇮🇳",
  );
  var countryCodesList = CountryUtils.countryCodesList;

  late final WebViewController _ourServicesController;
  double _webViewHeight = 300;

  @override
  void dispose() {
    _phoneController.dispose();
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
                // Ask the page for its scroll height so we can size the widget.
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

  void _validatePhone() {
    final input = _phoneController.text.trim();
    if (isValidIndianNumber(input)) {
      setState(() => _errorText = null);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPasswordScreen(mobileNumber: input),
        ),
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

              Text(
                'Please enter your mobile number to login.',
                style: TextStyle(fontSize: 16, color: AppColors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),
              // SizedBox(
              //   height: 110,
              //   child: ListView(
              //     scrollDirection: Axis.horizontal,
              //     children: [
              //       serviceCard(Icons.directions_boat, "Ocean Freight"),
              //       serviceCard(Icons.flight, "Air Freight"),
              //       serviceCard(Icons.warehouse, "Warehousing"),
              //     ],
              //   ),
              // ),
              buildMobileField(
                controller: _phoneController,
                label: "Mobile Number",
                errorText: _errorText,
                prefixWidget: buildCountryPrefix(
                  country: selectedCountry,
                  onTap: () {
                    _showSearchableCountryDropdown(
                      context: context,
                      title: "Country Code",
                      items: countryCodesList,
                      onSelected: (country) {
                        setState(() {
                          selectedCountry = country;
                        });
                      },
                    );
                  },
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

              const SizedBox(height: 60),

              // Continue button
              MainButton(text: 'Continue', onPressed: _validatePhone),

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

  Widget buildMobileField({
    required TextEditingController controller,
    required String label,
    Function(String)? onChanged,
    String? errorText,
    Widget? prefixWidget, // 👈 ADD THIS
  }) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        return Focus(
          onFocusChange: (hasFocus) {
            setState(() {});
          },
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            autovalidateMode: AutovalidateMode.onUserInteraction,

            onChanged: (value) {
              if (onChanged != null) onChanged(value);
              setState(() {
                if (value.trim().length == 10) {
                  _errorText = null;
                }
              });
            },

            style: const TextStyle(color: Colors.black, fontSize: 16),

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

              /// 🌍 COUNTRY CODE INSIDE FIELD
              prefixIcon:
                  prefixWidget != null
                      ? Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        child: prefixWidget,
                      )
                      : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),

              filled: true,
              fillColor: AppColors.white,

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      errorText == null
                          ? AppColors.lightGrey
                          : AppColors.secondary,
                  width: 1.3,
                ),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      errorText == null
                          ? AppColors.lightGrey
                          : AppColors.secondary,
                  width: 1.6,
                ),
              ),

              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 1.6),
              ),

              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 1.6),
              ),

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildCountryPrefix({
    required CountryCodeModel? country,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (country != null) ...[
            Text(country.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              country.dialCode,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ] else
            const Text("+"),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ],
      ),
    );
  }

  Future<void> _showSearchableCountryDropdown({
    required BuildContext context,
    required String title,
    required List<CountryCodeModel> items,
    required Function(CountryCodeModel) onSelected,
  }) async {
    TextEditingController searchController = TextEditingController();
    List<CountryCodeModel> filtered = List.from(items);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// 🔍 SEARCH
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() {
                          filtered =
                              items
                                  .where(
                                    (e) =>
                                        e.name.toLowerCase().contains(
                                          value.toLowerCase(),
                                        ) ||
                                        e.dialCode.contains(value),
                                  )
                                  .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search country or code",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final country = filtered[index];
                          return ListTile(
                            leading: Text(
                              country.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(country.name),
                            trailing: Text(country.dialCode),
                            onTap: () {
                              Navigator.pop(context);
                              onSelected(country);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget serviceCard(IconData icon, String title) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),

      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.main, size: 26),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.montserratBold.copyWith(
              fontSize: 13,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
