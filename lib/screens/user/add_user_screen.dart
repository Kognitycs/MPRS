import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/core/utils/validation_utils.dart';
import 'package:mprs_android/model/add_user_response.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import '../../core/utils/common_data.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController alternateMobileController =
      TextEditingController();
  final TextEditingController alternateEmailController =
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
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? userNameError;
  String? emailError;
  String? companyNameError;
  String? firstNameError;
  String? lastNameError;
  String? mobileError;
  String? countryError;
  String? regionError;
  String? passwordError;
  String? confirmPasswordError;
  String? gstinError;

  final countries = CountryUtils.getAllCountries();
  final region = CountryUtils.getRegion();

  String? userRoleType;
  String? userRoleTypeError;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;
    final File imageFile = File(picked.path);
    final int imageSize = await imageFile.length();
    const int maxImageSize = 2 * 1024 * 1024;
    if (imageSize > maxImageSize) {
      showSnackBar(context, "Image size should not be greater than 2 MB");
      return;
    }
    setState(() {
      _pickedImage = imageFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(title: "Add User"),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child:
                                  _pickedImage != null
                                      ? Image.file(
                                        _pickedImage!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                      : _buildProfileImage(),
                            ),
                          ),
                        ),

                        // Edit button
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.main,
                              ),
                              child: Image.asset(
                                'assets/icons/ic_edit_image.png',
                                width: 30,
                                height: 30,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ═══════════════════════════════════════════════════════════════
              // MANDATORY INFORMATION SECTION
              // ═══════════════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      "Mandatory Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              buildUserTextField(
                label: "First Name",
                isRequired: true,
                hint: "Enter your First Name",
                controller: firstNameController,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: firstNameError,
              ),
              buildUserTextField(
                label: "Last Name",
                hint: "Enter your Last Name",
                controller: lastNameController,
                isRequired: true,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: lastNameError,
              ),
              buildUserTextField(
                label: "Mobile Number",
                hint: "Enter your Mobile Number",
                isRequired: true,
                controller: mobileNumberController,
                inputType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {},
                errorText: mobileError,
              ),
              buildUserTextField(
                label: "Email",
                hint: "Enter your Email",
                controller: emailController,
                isRequired: true,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: emailError,
              ),
              buildUserTextField(
                label: "Company Name",
                hint: "Enter your Company Name",
                controller: companyNameController,
                isRequired: true,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: companyNameError,
              ),

              buildUserTextField(
                label: "Gstin", // Arnima - allow both capital and small letters in gstin and later captial the whole string
                hint:
                    (userRoleType == "External" ||
                            userRoleType == "VIP" ||
                            userRoleType == "VVIP")
                        ? "Enter your GSTIN"
                        : "Enter your GSTIN (Optional)",
                controller: gstinController,
                isRequired:
                    (userRoleType == "External" ||
                        userRoleType == "VIP" ||
                        userRoleType == "VVIP"),
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: gstinError,
              ),

              buildRoundedDropdownWithArrow(
                label: "Select role",
                hint: "Select role",
                isRequired: true,
                items: addUserRoles,
                value: userRoleType,
                onChanged: (value) {
                  setState(() {
                    userRoleType = value;
                    userRoleTypeError = null;
                  });
                },
                errorText: userRoleTypeError,
                context: context,
              ),

              buildPasswordField(
                label: "New Password",
                obscureText: !_passwordVisible,
                hint: "Enter your password",
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
              const SizedBox(height: 16),
              buildPasswordField(
                obscureText: !_confirmPasswordVisible,
                label: "Confirm New Password",
                hint: "Enter your confirm password",
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

              const SizedBox(height: 28),

              // ═══════════════════════════════════════════════════════════════
              // OPTIONAL INFORMATION SECTION
              // ═══════════════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      "Optional Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Professional Information
              Text(
                "Professional Details",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightGrey,
                ),
              ),
              const SizedBox(height: 12),

              buildUserTextField(
                label: "Designation",
                hint: "Enter your designation (Optional)",
                controller: designationController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),
              buildUserTextField(
                label: "Department",
                hint: "Enter your Department (Optional)",
                controller: departmentController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              // role moved to mandatory section
              const SizedBox(height: 20),

              // Contact Information
              Text(
                "Contact Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightGrey,
                ),
              ),
              const SizedBox(height: 12),

              buildUserTextField(
                label: "Alternate Email",
                hint: "Enter your alternate email (Optional)",
                controller: alternateEmailController,
                inputType: TextInputType.emailAddress,
                onChanged: (value) {},
              ),

              buildUserTextField(
                label: "Alternate Mobile Number",
                hint: "Enter your alternate mobile number (Optional)",
                controller: alternateMobileController,
                inputType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {},
              ),

              buildUserTextField(
                label: "Landline Number",
                hint: "Enter your landline Number (Optional)",
                controller: landlineNumberController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              buildUserTextField(
                label: "Extension Number",
                hint: "Enter your Extension Number (Optional)",
                controller: extensionController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              const SizedBox(height: 20),

              Text(
                "Location Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightGrey,
                ),
              ),
              const SizedBox(height: 12),

              buildUserTextField(
                label: "Address",
                hint: "Enter your Address (Optional)",
                controller: addressController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              buildRoundedDropdown(
                label: "Country",
                hint: "Select Country (Optional)",
                items: countries,
                value: selectedCountry,
                onChanged: (value) {
                  setState(() {
                    selectedCountry = value;
                  });
                },
                context: context,
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

              const SizedBox(height: 30),

              MainButton(
                text: 'Save User',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  saveUser();
                },
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    // Default asset image
    return Image.asset(
      'assets/icons/default_ic_user.png',
      width: 120,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  Future<void> saveUser() async {
    if (!validateFields()) {
      // Show specific error message for validation failure
      Future.microtask(() {
        if (gstinError != null) {
          showSnackBar(
            context,
            "Please enter GSTIN for External/VIP/VVIP users",
          );
        } else {
          showSnackBar(context, "Please fill all required fields");
        }
      });
      return;
    }
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
      profileImageFile: _pickedImage,
      termsAccepted: true,
      activeRmsUser: false,
      userType: userRoleType,
      deviceType: deviceType,
    );
    Loader.show();

    showSnackBar(context, "Adding user...");
    final response = await HttpClientHelper.postWithBearerMultipart(
      ApiConstants.addUser,
      AuthDataHelper.getToken(),
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
        'Active_RMS_User': 'true',
        "isActive": "true",
        'userType': (user.userType ?? '').trim(),
        'deviceType': (user.deviceType ?? '').trim(),
        'password': passwordController.text.trim(),
      },
      file: user.profileImageFile,
    );
    Loader.hide();

    final decoded = jsonDecode(response.data);

    final userData = AddUserResponse.fromJson(decoded);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        userData.user != null) {
      showSnackBar(context, userData.message ?? "");
      Navigator.pop(context, true);
    } else {
      showSnackBar(context, "Error: ${userData.message}");
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

      companyNameError =
          companyNameController.text.trim().isEmpty
              ? "Please enter company name"
              : null;

      mobileError =
          mobileNumberController.text.isEmpty
              ? "Please enter mobile number"
              : (mobileNumberController.text.length != 10
                  ? "Mobile number must be 10 digits"
                  : null);

      emailError =
          emailController.text.trim().isEmpty ? "Please enter email" : null;

      // Password validation
      passwordError = ValidationUtils.getPasswordError(passwordController.text);

      // Confirm Password
      confirmPasswordError = ValidationUtils.getPasswordError(
        confirmPasswordController.text,
      );
      if (confirmPasswordError == null) {
        if (confirmPasswordController.text != passwordController.text) {
          confirmPasswordError = "Passwords do not match";
        }
      }

      // GSTIN validation: required only for External / VIP / VVIP
      if (userRoleType == "External" ||
          userRoleType == "VIP" ||
          userRoleType == "VVIP") {
        gstinError =
            gstinController.text.trim().isEmpty
                ? "Please enter gst no"
                : (!RegExp(
                      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                    ).hasMatch(gstinController.text.trim())
                    ? "Invalid GST format"
                    : null);
      } else {
        gstinError = null;
      }

      // Role selection validation (mandatory)
      userRoleTypeError =
          (userRoleType == null || (userRoleType ?? '').isEmpty)
              ? "Please select role"
              : null;
    });

    // All correct?
    return emailError == null &&
        firstNameError == null &&
        lastNameError == null &&
        companyNameError == null &&
        mobileError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        gstinError == null &&
        userRoleTypeError == null;
  }
}
