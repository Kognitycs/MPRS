import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
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
import 'package:mprs_android/model/edit_user_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import '../../core/utils/common_data.dart';

class EditUserScreen extends StatefulWidget {
  final UserData? user;
  const EditUserScreen({super.key, this.user});
  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
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
  bool get isRoleEditable {
    final roles = getAllowedUserRoles(userRoleType);
    final otherRoles = roles.where((r) => r != (userRoleType ?? "")).toList();
    return otherRoles.isNotEmpty;
  }

  String? selectedCountry;
  String? selectedRegion;
  String? emailError;
  String? companyNameError;
  String? firstNameError;
  String? lastNameError;
  String? gstinError;
  String? imageError;

  final countries = CountryUtils.getAllCountries();
  final region = CountryUtils.getRegion();

  String? userRoleType = "External";
  String? userRoleTypeError;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  void _initUserData() {
    print(widget.user);
    final userData = widget.user!;
    userNameController.text = userData.username ?? "";
    firstNameController.text = userData.firstName ?? "";
    lastNameController.text = userData.lastName ?? "";
    designationController.text = userData.designation ?? "";
    departmentController.text = userData.department ?? "";
    emailController.text = userData.email ?? "";
    alternateEmailController.text = userData.alternateEmail ?? "";
    mobileNumberController.text = userData.mobile ?? "";
    alternateMobileController.text = userData.alternateMobile ?? "";
    gstinController.text = userData.gstin ?? "";
    landlineNumberController.text = userData.landlineNumber ?? "";
    extensionController.text = userData.extentionNumber ?? "";
    addressController.text = userData.address ?? "";
    companyNameController.text = userData.companyName ?? "";
    selectedRegion = userData.region;
    selectedCountry = userData.country;
    userRoleType = userData.userType ?? "";
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked == null) {
        setState(() {
          imageError = null;
        });
        return;
      }

      final File imageFile = File(picked.path);

      // Validate file type
      final String extension = picked.path.split('.').last.toLowerCase();
      const List<String> allowedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!allowedFormats.contains(extension)) {
        setState(() {
          imageError = 'Invalid image format. Allowed: JPG, PNG, GIF, WebP';
        });
        return;
      }

      // Validate file size
      final int imageSize = await imageFile.length();
      const int maxImageSize = 1 * 1024 * 1024; // 1 MB
      if (imageSize > maxImageSize) {
        setState(() {
          imageError =
              'Image size exceeds 1 MB limit. Current size: ${(imageSize / (1024 * 1024)).toStringAsFixed(2)} MB';
        });
        return;
      }

      setState(() {
        _pickedImage = imageFile;
        imageError = null;
      });
    } catch (e) {
      setState(() {
        imageError = 'Error selecting image: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(title: "Edit User"),
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

              // Show image error if present
              if (imageError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            imageError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

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
                editable: false,
                controller: mobileNumberController,
                inputType: TextInputType.phone,
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
                editable: false,
                onChanged: (value) {},
                errorText: companyNameError,
              ),
              buildUserTextField(
                label: "Designation",
                hint: "Enter your designation (Optional)",
                controller: designationController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),
              buildUserTextField(
                label: "department",
                hint: "Enter your Department (Optional)",
                controller: departmentController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

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
                errorText: gstinError,
                onChanged: (value) {
                  print("User typed: $value");
                },
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

              buildRoundedDropdownWithArrow(
                label: "Select role",
                hint: "Select role",
                isRequired: true,
                items: getAllowedUserRoles(userRoleType),
                value: userRoleType,
                errorText: userRoleTypeError,
                onChanged:
                    isRoleEditable
                        ? (value) async {
                          if (value == null || value == userRoleType) return;

                          setState(() {
                            userRoleType = value;
                          });

                          await changeRole();
                        }
                        : null,
                context: context,
              ),
              const SizedBox(height: 30),

              MainButton(
                text: 'Save Changes',
                onPressed: () {
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

  Future<void> changeRole() async {
    final body = jsonEncode({
      "userNumber": widget.user?.mobile,
      "newUserType": userRoleType,
    });
    debugPrint("🔁 Changing role for userId: ${widget.user?.userId}");
    debugPrint("📞 User mobile: ${widget.user?.mobile}");
    debugPrint("➡️ New role: $userRoleType");
    Loader.show();
    final response = await HttpClientHelper.patchWithBearer(
      ApiConstants.changeUserType,
      AuthDataHelper.getToken(),
      body: body,
    );
    Loader.hide();
    final decoded = jsonDecode(response.data);

    final userData = AddUserResponse.fromJson(decoded);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        userData.user != null) {
      // Navigator.pop(context, true);
      showSnackBar(context, "Role updated successfully");
    } else {
      showSnackBar(context, "Error: ${userData.message}");
    }
  }

  List<String> getAllowedUserRoles(String? userType) {
    // Compute allowed role changes for the current user type
    List<String> allowedChanges;
    switch (userType) {
      case "Admin":
        allowedChanges = ["Internal"];
        break;
      case "Internal":
        allowedChanges = ["Admin"];
        break;
      case "External":
        allowedChanges = ["VIP", "VVIP"];
        break;
      case "VIP":
        allowedChanges = ["External", "VVIP"];
        break;
      case "VVIP":
        allowedChanges = ["External", "VIP"];
        break;
      default:
        allowedChanges = [];
    }

    // Ensure dropdown items include current role first, then other allowed roles
    final List<String> roles = [];
    if (userType != null && userType.isNotEmpty) roles.add(userType);
    for (final r in allowedChanges) {
      if (!roles.contains(r)) roles.add(r);
    }
    return roles;
  }

  Widget _buildProfileImage() {
    final url = widget.user?.profileImageUrl?.trim() ?? '';
    if (url.isNotEmpty && url.startsWith('http')) {
      return FadeInImage.assetNetwork(
        placeholder: 'assets/icons/default_ic_user.png',
        image: url,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) => _defaultProfileIcon(),
      );
    }
    return _defaultProfileIcon();
  }

  Widget _defaultProfileIcon() {
    return Image.asset(
      'assets/icons/default_ic_user.png',
      width: 120,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  Future<void> saveUser() async {
    if (!validateFields()) return;

    // Check for image errors before saving
    if (imageError != null) {
      showSnackBar(context, imageError!);
      return;
    }

    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    try {
      final user = UserData(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        email: emailController.text.trim(),
        alternateEmail: alternateEmailController.text.trim(),
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
        userType: userRoleType,
      );

      showSnackBar(context, "Updating user...");

      Loader.show();
      final response = await HttpClientHelper.patchWithMultipart(
        '${ApiConstants.updateUser}/${widget.user?.userId}',
        AuthDataHelper.getToken(),
        fields: {
          'firstName': (user.firstName ?? '').trim(),
          'lastName': (user.lastName ?? '').trim(),
          'designation': (user.designation ?? '').trim(),
          'department': (user.department ?? '').trim(),
          'email': (user.email ?? '').trim(),
          'alternateEmail': (user.alternateEmail ?? '').trim(),
          'alternateMobile': (user.alternateMobile ?? '').trim(),
          'landlineNumber': (user.landlineNumber ?? '').trim(),
          'extentionNumber': (user.extentionNumber ?? '').trim(),
          'address': (user.address ?? '').trim(),
          'country': (user.country ?? '').trim(),
          'companyName': (user.companyName ?? '').trim(),
          'region': (user.region ?? '').trim(),
          'gstin': (user.gstin ?? '').trim(),
          'userType': (user.userType ?? '').trim(),
        },
        file: user.profileImageFile,
      );
      debugPrint("Response data: ${response.data}");
      Loader.hide();
      final decoded = jsonDecode(response.data);

      final userData = EditUserResponse.fromJson(decoded);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        showSnackBar(context, "${userData.message}");

        // If admin changed the currently logged-in user's type, invalidate
        // cached quotes so the next load always re-fetches with the fresh type.
        final editedUserId = widget.user?.userId ?? widget.user?.id ?? '';
        final loggedInUserId = AuthDataHelper.getId();
        if (editedUserId.isNotEmpty &&
            editedUserId == loggedInUserId &&
            Get.isRegistered<SavedQuotationsController>()) {
          Get.find<SavedQuotationsController>().fetchSavedQuotes();
        }

        Navigator.pop(context, true);
      } else {
        showSnackBar(context, "Error: ${userData.message}");
      }
    } on SocketException {
      Loader.hide();
      showSnackBar(context, "Network Error: Check your internet connection");
    } on FormatException {
      Loader.hide();
      showSnackBar(context, "Error: Invalid response format from server");
    } catch (e) {
      Loader.hide();
      showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  bool validateFields() {
    setState(() {
      emailError =
          emailController.text.trim().isEmpty
              ? "Please enter email"
              : (!ValidationUtils.isValidEmail(emailController.text.trim())
                  ? "Enter a valid email"
                  : null);

      firstNameError =
          firstNameController.text.trim().isEmpty
              ? "Please enter first name"
              : null;

      lastNameError =
          lastNameController.text.trim().isEmpty
              ? "Please enter last name"
              : null;
    });
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

    // Role selection validation
    userRoleTypeError =
        (userRoleType == null || (userRoleType ?? '').isEmpty)
            ? "Please select role"
            : null;

    return emailError == null &&
        firstNameError == null &&
        lastNameError == null &&
        gstinError == null &&
        userRoleTypeError == null;
  }
}
