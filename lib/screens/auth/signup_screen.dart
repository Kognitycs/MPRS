import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/core/utils/validation_utils.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/country_code_model.dart';
import 'package:mprs_android/model/signup_response.dart';
import 'package:mprs_android/screens/auth/account_created_screen.dart';
import 'package:mprs_android/screens/auth/login_mobile_screen.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/phone_auth_service.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/common_pin_field.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool acceptTerms = false;
  bool acceptMarketing = false;
  String? termsError;

  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController alternateEmailController =
      TextEditingController();
  final TextEditingController alternateMobileController =
      TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController landlineNumberController =
      TextEditingController();
  final TextEditingController extensionController = TextEditingController();
  final TextEditingController gstinController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController mobileNumberController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? selectedCountry;
  String? selectedRegion;
  CountryCodeModel selectedMobileCountry = CountryCodeModel(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
  );
  final countryCodesList = CountryUtils.countryCodesList;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? emailError;
  String? firstNameError;
  String? lastNameError;
  String? gstinError;
  String? mobileError;
  String? mobileOtpError;
  bool _showMobileOtp = false;
  bool _isMobileVerified = false;
  bool _isVerifyingMobileOtp = false;
  bool _isSendingMobileOtp = false;
  final PhoneAuthService _phoneAuthService = PhoneAuthService();
  String? companyNameError;
  String? addressError;
  String? countryError;
  String? passwordError;
  String? confirmPasswordError;

  final countries = CountryUtils.getAllCountries();
  final region = CountryUtils.getRegion();
  bool _showOptionalFields = false;

  bool get _isMobileComplete =>
      RegExp(r'^[0-9]{10}$').hasMatch(mobileNumberController.text.trim());

  void _resetMobileVerification() {
    _isMobileVerified = false;
    _showMobileOtp = false;
    mobileOtpError = null;
    _phoneAuthService.reset();
  }

  String get _fullMobileNumber =>
      '${selectedMobileCountry.dialCode}${mobileNumberController.text.trim()}';

  Future<void> _completePhoneVerification(String idToken) async {
    try {
      final message = await _phoneAuthService.verifyPhoneWithBackend(idToken);
      if (!mounted) return;

      ProgressLoader.hide(context);

      setState(() {
        _isMobileVerified = true;
        _showMobileOtp = false;
        mobileOtpError = null;
      });
      showSnackBar(
        context,
        message,
        backgroundColor: AppColors.green,
      );
    } finally {
      await _phoneAuthService.signOut();
    }
  }

  Future<void> _sendMobileOtp() async {
    if (!_isMobileComplete || _isMobileVerified || _isSendingMobileOtp) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSendingMobileOtp = true);
    ProgressLoader.show(context);

    try {
      final result = await _phoneAuthService.sendOtp(_fullMobileNumber);
      if (!mounted) return;

      if (result.isAutoVerified) {
        ProgressLoader.hide(context);
        try {
          await _completePhoneVerification(result.autoVerifiedIdToken!);
        } catch (e) {
          if (!mounted) return;
          showSnackBar(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
        return;
      }

      setState(() => _showMobileOtp = true);
      showSnackBar(
        context,
        'OTP sent to ${selectedMobileCountry.dialCode} ${mobileNumberController.text.trim()}',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.message ?? 'Failed to send OTP. Please try again.';
      setState(() => mobileOtpError = message);
      showSnackBar(context, message);
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to send OTP. Please try again.');
    } finally {
      ProgressLoader.hide(context);
      if (mounted) setState(() => _isSendingMobileOtp = false);
    }
  }

  Future<void> _verifyMobileOtp(String otp) async {
    if (otp.length != 6 || _isVerifyingMobileOtp) return;

    setState(() {
      _isVerifyingMobileOtp = true;
      mobileOtpError = null;
    });
    ProgressLoader.show(context);

    try {
      final idToken = await _phoneAuthService.verifySmsCodeAndGetIdToken(otp);
      if (!mounted) return;
      ProgressLoader.hide(context);
      await _completePhoneVerification(idToken);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        mobileOtpError = e.message ?? 'Invalid OTP. Please try again.';
        _showMobileOtp = true;
      });
      await _phoneAuthService.clearFirebaseSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        mobileOtpError = e.toString().replaceFirst('Exception: ', '');
        _showMobileOtp = true;
      });
      await _phoneAuthService.clearFirebaseSession();
    } finally {
      ProgressLoader.hide(context);
      if (mounted) setState(() => _isVerifyingMobileOtp = false);
    }
  }

  void _onMobileNumberChanged(String value) {
    setState(() {
      if (value.trim().isNotEmpty) mobileError = null;
      if (_isMobileVerified || _showMobileOtp) {
        _resetMobileVerification();
      }
    });
  }

  @override
  void dispose() {
    _phoneAuthService.signOut();
    userNameController.dispose();
    emailController.dispose();
    alternateEmailController.dispose();
    alternateMobileController.dispose();
    addressController.dispose();
    landlineNumberController.dispose();
    extensionController.dispose();
    gstinController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    designationController.dispose();
    departmentController.dispose();
    mobileNumberController.dispose();
    companyNameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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
              Image.asset('assets/images/mprs_logo.png', height: 60),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome to your MPRS Registration',
                  style: AppTextStyles.montserratBold.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              // Text(
              //   'Sign up to join',
              //   style: AppTextStyles.montserratBold.copyWith(
              //     fontSize: 28,
              //     fontWeight: FontWeight.bold,
              //   ),
              //   textAlign: TextAlign.center,
              // ),
              const SizedBox(height: 20),

              buildSignupTextField(
                label: "First Name",
                isRequired: true,
                hint: "Enter your First Name",
                controller: firstNameController,
                onChanged: (value) {
                  setState(() {
                    if (value.trim().isNotEmpty) firstNameError = null;
                  });
                },
                errorText: firstNameError,
              ),
              buildSignupTextField(
                label: "Last Name",
                hint: "Enter your Last Name",
                controller: lastNameController,
                isRequired: true,
                onChanged: (value) {
                  setState(() {
                    if (value.trim().isNotEmpty) lastNameError = null;
                  });
                },
                errorText: lastNameError,
              ),
              buildSignupMobileField(
                context: context,
                label: "Mobile Number",
                hint: "Enter your Mobile Number",
                isRequired: true,
                controller: mobileNumberController,
                selectedCountry: selectedMobileCountry,
                countryCodes: countryCodesList,
                showVerifyAction: _isMobileComplete,
                isMobileVerified: _isMobileVerified,
                onVerifyTap: _sendMobileOtp,
                onCountrySelected: (country) {
                  setState(() {
                    selectedMobileCountry = country;
                    _resetMobileVerification();
                  });
                },
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: _onMobileNumberChanged,
                errorText: mobileError,
              ),
              if (_showMobileOtp && !_isMobileVerified) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Enter OTP',
                      style: AppTextStyles.montserratSemiBold.copyWith(
                        fontSize: 14,
                        color: AppColors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedMobileCountry.dialCode} ${mobileNumberController.text.trim()}',
                      style: AppTextStyles.montserratSemiBold.copyWith(
                        fontSize: 13,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CommonPinCodeField(
                  length: 6,
                  obscureText: false,
                  onCompleted: _verifyMobileOtp,
                ),
                if (_isVerifyingMobileOtp)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Verifying...',
                      style: AppTextStyles.montserratRegular.copyWith(
                        fontSize: 13,
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                if (mobileOtpError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      mobileOtpError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
              buildSignupTextField(
                label: "Email",
                hint: "Enter your Email",
                controller: emailController,
                isRequired: true,
                onChanged: (value) {
                  setState(() {
                    if (value.trim().isNotEmpty) emailError = null;
                  });
                },
                errorText: emailError,
              ),
              buildSignupTextField(
                label: "Company Name",
                hint: "Enter your Company Name",
                controller: companyNameController,
                isRequired: true,
                onChanged: (value) {
                  setState(() {
                    if (value.trim().isNotEmpty) companyNameError = null;
                  });
                },
                errorText: companyNameError,
              ),

              buildSignupTextField(
                label: "Company GSTIN Number",
                hint: "Enter your Company's GSTIN Number",
                controller: gstinController,
                isRequired: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
                errorText: gstinError,
              ),

              buildSignupPasswordField(
                label: "New Password",
                obscureText: !_passwordVisible,
                hint: "Enter desired password",
                controller: passwordController,
                isRequired: true,
                onTogglePassword: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    passwordError = ValidationUtils.getPasswordError(value);
                  });
                },
                errorText: passwordError,
              ),
              buildSignupPasswordField(
                obscureText: !_confirmPasswordVisible,
                label: "Confirm New Password",
                hint: "Re-enter desired password",
                controller: confirmPasswordController,
                isRequired: true,
                onTogglePassword: () {
                  setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    confirmPasswordError = ValidationUtils.getPasswordError(
                      value,
                    );

                    if (confirmPasswordError == null) {
                      if (value != passwordController.text.trim()) {
                        confirmPasswordError = "Passwords do not match";
                      }
                    }
                  });
                },
                errorText: confirmPasswordError,
              ),
              buildSignupTextField(
                label: "Address",
                isRequired: true,
                hint: "Enter your Address",
                controller: addressController,
                inputType: TextInputType.streetAddress,
                onChanged: (value) {
                  setState(() {
                    if (value.trim().isNotEmpty) addressError = null;
                  });
                },
                errorText: addressError,
              ),
              buildSignupDropdown(
                context: context,
                label: "Country",
                isRequired: true,
                hint: "Select Country",
                items: countries,
                value: selectedCountry,
                onChanged: (value) {
                  setState(() {
                    selectedCountry = value;
                    if (value != null && value.trim().isNotEmpty) {
                      countryError = null;
                    }
                  });
                },
                errorText: countryError,
              ),
              const SizedBox(height: 10),

              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: Text(
                  "Optional Details",
                  style: AppTextStyles.montserratBold.copyWith(
                    fontSize: 16,
                    color: AppColors.secondary,
                  ),
                ),
                trailing: Icon(
                  _showOptionalFields ? Icons.expand_less : Icons.expand_more,
                ),
                onExpansionChanged: (expanded) {
                  setState(() {
                    _showOptionalFields = expanded;
                  });
                },
                children: [
                  buildSignupTextField(
                    label: "Designation",
                    hint: "Enter your designation (Optional)",
                    controller: designationController,
                  ),

                  buildSignupTextField(
                    label: "Department",
                    hint: "Enter your Department (Optional)",
                    controller: departmentController,
                  ),

                  buildSignupTextField(
                    label: "Alternate Email",
                    hint: "Enter your alternate email (Optional)",
                    controller: alternateEmailController,
                    inputType: TextInputType.emailAddress,
                  ),

                  buildSignupTextField(
                    label: "Alternate Mobile Number",
                    hint: "Enter your alternate mobile number (Optional)",
                    controller: alternateMobileController,
                    inputType: TextInputType.phone,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),

                  buildSignupTextField(
                    label: "Landline Number",
                    hint: "Enter your landline Number (Optional)",
                    controller: landlineNumberController,
                  ),

                  buildSignupTextField(
                    label: "Extension Number",
                    hint: "Enter your Extension Number (Optional)",
                    controller: extensionController,
                  ),

                  buildRoundedDropdown(
                    label: "Region",
                    hint: "Select Region (Optional)",
                    items: region,
                    value: selectedRegion,
                    onChanged: (value) {
                      setState(() {
                        selectedRegion = value;
                      });
                    },
                    context: context,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Terms & Conditions Checkbox (mandatory)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        termsError != null
                            ? Colors.red
                            : const Color(0xFFE4E7EC),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: acceptTerms,
                          activeColor: AppColors.secondary,
                          onChanged: (value) {
                            setState(() {
                              acceptTerms = value ?? false;
                              if (acceptTerms) {
                                termsError = null;
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(
                                    text: '* ',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'I accept the registered ',
                                  ),

                                  TextSpan(
                                    text: 'terms & conditions',
                                    style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            launchUrl(
                                              Uri.parse(
                                                'https://mprsshipping.com/terms-conditions/',
                                              ),
                                              mode:
                                                  LaunchMode
                                                      .externalApplication,
                                            );
                                          },
                                  ),

                                  const TextSpan(text: ' and '),

                                  TextSpan(
                                    text: 'cookie policy',
                                    style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),

                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            launchUrl(
                                              Uri.parse(
                                                'https://mprsshipping.com/cookie-policy/',
                                              ),
                                              mode:
                                                  LaunchMode
                                                      .externalApplication,
                                            );
                                          },
                                  ),

                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (termsError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          termsError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Marketing Checkbox
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: acceptMarketing,
                      activeColor: AppColors.secondary,
                      onChanged: (value) {
                        setState(() {
                          acceptMarketing = value ?? false;
                        });
                      },
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 13,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'I agree to receive logistics related news and marketing updates by phone, email, or similar from MPRS Shipping & Logistics Private Limited and its affiliated and subsidiary companies. I understand that I can opt out of such communications at any time. To see how we process your personal data read our ',
                              ),

                              TextSpan(
                                text: 'Data Privacy Policy',
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        launchUrl(
                                          Uri.parse(
                                            'https://mprsshipping.com/data-privacy/',
                                          ),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                              ),

                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              MainButton(
                text: 'Sign Up',
                onPressed: () {
                  signup();
                },
              ),

              const SizedBox(height: 25),

              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'Have an account? ',
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Sign In',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () {
                                // Navigate to Sign In screen
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginMobileScreen(),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> signup() async {
    if (!validateFields()) return;

    ProgressLoader.show(context);

    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }
    String deviceType = "";
    if (Platform.isAndroid) {
      deviceType = "android";
    } else if (Platform.isIOS) {
      deviceType = "ios";
    }

    try {
      final user = UserData(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        email: emailController.text.trim(),
        alternateEmail: alternateEmailController.text.trim(),
        mobile: mobileNumberController.text.trim(),
        alternateMobile: alternateMobileController.text.trim(),
        designation: designationController.text.trim(),
        department: departmentController.text.trim(),
        companyName: companyNameController.text.trim(),
        landlineNumber: landlineNumberController.text.trim(),
        extentionNumber: extensionController.text.trim(),
        address: addressController.text.trim(),
        country: selectedCountry,
        region: selectedRegion,
        gstin: gstinController.text.trim(),
        termsAccepted: true,
        activeRmsUser: false,
        userType: "External",
        deviceType: deviceType,
      );
      final response = await HttpClientHelper.postWithMultipart(
        ApiConstants.signup,
        fields: {
          'username': user.mobile.toString().trim(),
          'firstName': (user.firstName ?? '').trim(),
          'lastName': (user.lastName ?? '').trim(),
          'email': (user.email ?? '').trim(),
          'alternateEmail': (user.alternateEmail ?? '').trim(),
          'mobile': (user.mobile ?? '').trim(),
          'alternateMobile': (user.alternateMobile ?? '').trim(),
          'designation': (user.designation ?? '').trim(),
          'department': (user.department ?? '').trim(),
          'companyName': (user.companyName ?? '').trim(),
          'landlineNumber': (user.landlineNumber ?? '').trim(),
          'extentionNumber': (user.extentionNumber ?? '').trim(),
          'address': (user.address ?? '').trim(),
          'country': (user.country ?? '').trim(),
          'region': (user.region ?? '').trim(),
          'gstin': (user.gstin ?? '').trim(),
          'termsAccepted': 'true',
          'Active_RMS_User': 'false',
          'isActive': 'true',
          'userType': (user.userType ?? '').trim(),
          'deviceType': (user.deviceType ?? '').trim(),
          'password': passwordController.text.trim(),
        },
        file: user.profileImageFile,
      );

      ProgressLoader.hide(context);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.data) as Map<String, dynamic>;
        final signupResponse = SignupResponse.fromJson(decoded);
        showSnackBar(
          context,
          signupResponse.message ?? 'Account created successfully',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AccountCreatedScreen()),
        );
      } else {
        final errorText = parseApiErrorMessage(
          response.data,
          fallback: response.message ?? 'Sign up failed',
        );
        showSnackBar(context, errorText);
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error during sign up: $e');
    }
  }

  bool validateFields() {
    setState(() {
      firstNameError =
          firstNameController.text.trim().isEmpty
              ? "Please enter first name"
              : null;

      lastNameError =
          lastNameController.text.trim().isEmpty
              ? "Please enter last name"
              : null;

      mobileError =
          mobileNumberController.text.isEmpty
              ? "Please enter mobile number"
              : (!RegExp(
                    r'^[0-9]{10}$',
                  ).hasMatch(mobileNumberController.text.trim())
                  ? "Mobile number must be exactly 10 digits"
                  : (!_isMobileVerified
                      ? "Please verify your mobile number"
                      : null));

      emailError =
          emailController.text.trim().isEmpty
              ? "Please enter email"
              : (!ValidationUtils.isValidEmail(emailController.text.trim())
                  ? "Please enter a valid email"
                  : null);

      companyNameError =
          companyNameController.text.trim().isEmpty
              ? "Please enter company name"
              : null;

      addressError =
          addressController.text.trim().isEmpty
              ? "Please enter address"
              : null;

      countryError =
          (selectedCountry == null || selectedCountry!.trim().isEmpty)
              ? "Please select country"
              : null;

      termsError = !acceptTerms ? "Please accept terms and conditions" : null;

      gstinError =
          gstinController.text.trim().isEmpty
              ? "Please enter gst no"
              : (!RegExp(
                    r'^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                  ).hasMatch(gstinController.text.trim())
                  ? "Invalid GST format"
                  : null);

      passwordError = ValidationUtils.getPasswordError(passwordController.text);
      confirmPasswordError = ValidationUtils.getPasswordError(
        confirmPasswordController.text,
      );
      if (confirmPasswordError == null) {
        if (confirmPasswordController.text != passwordController.text) {
          confirmPasswordError = "Passwords do not match";
        }
      }
    });

    // All correct?
    return emailError == null &&
        firstNameError == null &&
        lastNameError == null &&
        companyNameError == null &&
        addressError == null &&
        countryError == null &&
        mobileError == null &&
        gstinError == null &&
        termsError == null &&
        passwordError == null &&
        confirmPasswordError == null;
  }
}
