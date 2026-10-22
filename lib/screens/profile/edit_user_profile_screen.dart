// /*
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:mprs_android/core/auth_data_helper.dart';
// import 'package:mprs_android/core/constants/api_constants.dart';
// import 'package:mprs_android/core/constants/app_colors.dart';
// import 'package:mprs_android/core/utils/country_utils.dart';
// import 'package:mprs_android/core/utils/snackbar_util.dart';
// import 'package:mprs_android/model/common/user_data.dart';
// import 'package:mprs_android/model/update_profile_response.dart';
// import 'package:mprs_android/screens/preferences_screen.dart';
// import 'package:mprs_android/service/http_client_helper.dart';
// import 'package:mprs_android/widget/common_appbar.dart';
// import 'package:mprs_android/widget/common_fields.dart';
// import 'package:mprs_android/widget/custom_buttons.dart';
//
// class EditUserProfileScreen extends StatefulWidget {
//   const EditUserProfileScreen({super.key});
//
//   @override
//   State<EditUserProfileScreen> createState() => _EditUserProfileScreenState();
// }
//
// class _EditUserProfileScreenState extends State<EditUserProfileScreen> {
//   final TextEditingController userNameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController alternateEmailController =
//       TextEditingController();
//   final TextEditingController alternateMobileController =
//       TextEditingController();
//   final TextEditingController addressController = TextEditingController();
//   final TextEditingController landlineNumberController =
//       TextEditingController();
//   final TextEditingController extensionController = TextEditingController();
//   final TextEditingController gstinController = TextEditingController();
//   final TextEditingController firstNameController = TextEditingController();
//   final TextEditingController lastNameController = TextEditingController();
//   final TextEditingController designationController = TextEditingController();
//   final TextEditingController departmentController = TextEditingController();
//   final TextEditingController mobileNumberController = TextEditingController();
//   final TextEditingController companyNameController = TextEditingController();
//
//   String? selectedCountry;
//   String? selectedRegion;
//   String? userNameError;
//   String? emailError;
//   String? firstNameError;
//   String? lastNameError;
//   String? alternateMobileError;
//   String? companyNameError;
//   String userRole = "";
//
//   final countries = CountryUtils.getAllCountries();
//   final region = CountryUtils.getRegion();
//   File? _pickedImage;
//
//   @override
//   void initState() {
//     super.initState();
//     _initUserData();
//   }
//
//   void _initUserData() {
//     userNameController.text = AuthDataHelper.getUsername();
//     firstNameController.text = AuthDataHelper.getFirstName();
//     lastNameController.text = AuthDataHelper.getLastName();
//     designationController.text = AuthDataHelper.getDesignation();
//     departmentController.text = AuthDataHelper.getDepartment();
//     emailController.text = AuthDataHelper.getEmail();
//     alternateEmailController.text = AuthDataHelper.getAlternateEmail();
//     mobileNumberController.text = AuthDataHelper.getMobile();
//     alternateMobileController.text = AuthDataHelper.getMobile();
//     gstinController.text = AuthDataHelper.getGstin();
//     landlineNumberController.text = AuthDataHelper.getLandline();
//     extensionController.text = AuthDataHelper.getExtension();
//     addressController.text = AuthDataHelper.getAddress();
//     companyNameController.text = AuthDataHelper.getCompanyName();
//     if (AuthDataHelper.getRegion() != "") {
//       selectedRegion = AuthDataHelper.getRegion();
//     }
//     if (AuthDataHelper.getCountry() != "") {
//       selectedCountry = AuthDataHelper.getCountry();
//     }
//     userRole = AuthDataHelper.getUserType();
//   }
//
//   @override
//   void dispose() {
//     userNameController.dispose();
//     emailController.dispose();
//     alternateEmailController.dispose();
//     alternateMobileController.dispose();
//     addressController.dispose();
//     landlineNumberController.dispose();
//     extensionController.dispose();
//     gstinController.dispose();
//     firstNameController.dispose();
//     lastNameController.dispose();
//     designationController.dispose();
//     departmentController.dispose();
//     mobileNumberController.dispose();
//     companyNameController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     final picked = await picker.pickImage(source: ImageSource.gallery);
//
//     if (picked == null) return;
//     final File imageFile = File(picked.path);
//     final int imageSize = await imageFile.length();
//     const int maxImageSize = 2 * 1024 * 1024;
//     if (imageSize > maxImageSize) {
//       showSnackBar(context, "Image size should not be greater than 2 MB");
//       return;
//     }
//     setState(() {
//       _pickedImage = imageFile;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: CommonAppBar(
//         title: "Profile",
//
//         onActionPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (_) => const PreferencesScreen()),
//           );
//         },
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     Stack(
//                       alignment: Alignment.bottomRight,
//                       children: [
//                         Container(
//                           width: 130,
//                           height: 130,
//                           decoration: const BoxDecoration(
//                             shape: BoxShape.circle,
//                           ),
//                           child: CircleAvatar(
//                             radius: 60,
//                             backgroundColor: Colors.white,
//                             child: ClipOval(
//                               child:
//                                   _pickedImage != null
//                                       ? Image.file(
//                                         _pickedImage!,
//                                         width: 120,
//                                         height: 120,
//                                         fit: BoxFit.cover,
//                                       )
//                                       : _buildProfileImage(),
//                             ),
//                           ),
//                         ),
//
//                         // Edit button
//                         Positioned(
//                           bottom: 10,
//                           right: 10,
//                           child: InkWell(
//                             onTap: _pickImage,
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color: AppColors.main,
//                               ),
//                               child: Image.asset(
//                                 'assets/icons/ic_edit_image.png',
//                                 width: 30,
//                                 height: 30,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//
//               buildUserTextField(
//                 label: "First Name",
//                 isRequired: true,
//                 hint: "Enter your First Name",
//                 controller: firstNameController,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//                 errorText: firstNameError,
//               ),
//               buildUserTextField(
//                 label: "Last Name",
//                 hint: "Enter your Last Name",
//                 controller: lastNameController,
//                 isRequired: true,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//                 errorText: lastNameError,
//               ),
//               buildUserTextField(
//                 label: "Mobile Number",
//                 hint: "Enter your Mobile Number",
//                 isRequired: true,
//                 editable: false,
//                 controller: mobileNumberController,
//                 inputType: TextInputType.phone,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//               buildUserTextField(
//                 label: "Email",
//                 hint: "Enter your Email",
//                 controller: emailController,
//                 isRequired: true,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//                 errorText: emailError,
//               ),
//               buildUserTextField(
//                 label: "Company Name",
//                 hint: "Enter your Company Name",
//                 controller: companyNameController,
//                 isRequired: true,
//                 editable: false,
//                 onChanged: (value) {},
//                 errorText: companyNameError,
//               ),
//               buildUserTextField(
//                 label: "Designation",
//                 hint: "Enter your designation (Optional)",
//                 controller: designationController,
//                 editable: false,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//               buildUserTextField(
//                 label: "department",
//                 hint: "Enter your Department (Optional)",
//                 controller: departmentController,
//                 editable: false,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//
//               buildUserTextField(
//                 label: "Alternate Email",
//                 hint: "Enter your alternate email (Optional)",
//                 controller: alternateEmailController,
//                 inputType: TextInputType.emailAddress,
//                 editable: false,
//                 onChanged: (value) {},
//               ),
//
//               buildUserTextField(
//                 label: "Alternate Mobile Number",
//                 hint: "Enter your alternate mobile number (Optional)",
//                 controller: alternateMobileController,
//                 inputType: TextInputType.phone,
//                 editable: false,
//                 inputFormatters: [
//                   LengthLimitingTextInputFormatter(10),
//                   FilteringTextInputFormatter.digitsOnly,
//                 ],
//                 onChanged: (value) {},
//               ),
//               buildUserTextField(
//                 label: "Gstin",
//                 hint: "Enter your gstin (Optional)",
//                 controller: gstinController,
//                 editable: false,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//
//               buildUserTextField(
//                 label: "Landline Number",
//                 hint: "Enter your landline Number (Optional)",
//                 controller: landlineNumberController,
//                 editable: false,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//
//               buildUserTextField(
//                 label: "Extension Number",
//                 hint: "Enter your Extension Number (Optional)",
//                 controller: extensionController,
//                 editable: false,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//
//               buildUserTextField(
//                 label: "Address",
//                 hint: "Enter your Address (Optional)",
//                 controller: addressController,
//                 editable: false,
//                 onChanged: (value) {
//                   print("User typed: $value");
//                 },
//               ),
//
//               buildRoundedDropdown(
//                 label: "Country",
//                 hint: "Select Country (Optional)",
//                 items: countries,
//                 value: selectedCountry,
//                 enabled: false,
//                 onChanged: (value) {
//                   setState(() {
//                     selectedCountry = value;
//                   });
//                 },
//                 context: context,
//               ),
//
//               buildRoundedDropdown(
//                 label: "Region",
//                 hint: "Select Region (Optional)",
//                 items: region,
//                 value: selectedRegion,
//                 enabled: false,
//                 onChanged: (value) {
//                   setState(() {
//                     selectedRegion = value;
//                   });
//                 },
//                 context: context,
//               ),
//
//               const SizedBox(height: 30),
//
//               MainButton(
//                 text: 'Save',
//                 onPressed: () {
//                   saveUser();
//                 },
//               ),
//
//               const SizedBox(height: 25),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProfileImage() {
//     String profileImageUrl = AuthDataHelper.getProfileImage();
//
//     // No image → show placeholder
//     if (profileImageUrl.isEmpty) {
//       return Image.asset(
//         'assets/icons/default_ic_user.png',
//         width: 120,
//         height: 120,
//         fit: BoxFit.cover,
//       );
//     }
//
//     // If valid network URL
//     if (profileImageUrl.startsWith("http")) {
//       return FadeInImage.assetNetwork(
//         placeholder: 'assets/icons/default_ic_user.png',
//         image: profileImageUrl,
//         fit: BoxFit.cover,
//         width: 120,
//         height: 120,
//         imageErrorBuilder: (_, __, ___) {
//           return Image.asset(
//             'assets/icons/default_ic_user.png',
//             width: 120,
//             height: 120,
//             fit: BoxFit.cover,
//           );
//         },
//       );
//     }
//
//     // If it's a local file path
//     final file = File(profileImageUrl);
//     if (file.existsSync()) {
//       return Image.file(file, width: 120, height: 120, fit: BoxFit.cover);
//     }
//
//     // Default fallback
//     return Image.asset(
//       'assets/icons/default_ic_user.png',
//       width: 120,
//       height: 120,
//       fit: BoxFit.cover,
//     );
//   }
//
//   Future<void> saveUser() async {
//     if (!validateFields()) return;
//
//     final user = UserData(
//       firstName: firstNameController.text.trim(),
//       lastName: lastNameController.text.trim(),
//       email: emailController.text.trim(),
//       alternateEmail: alternateEmailController.text.trim(),
//       mobile: mobileNumberController.text.trim(),
//       alternateMobile: alternateMobileController.text.trim(),
//       designation: designationController.text.trim(),
//       department: departmentController.text.trim(),
//       companyName: companyNameController.text.trim(),
//       landlineNumber: landlineNumberController.text.trim(),
//       extentionNumber: extensionController.text.trim(),
//       address: addressController.text.trim(),
//       country: selectedCountry,
//       region: selectedRegion,
//       profileImageFile: _pickedImage,
//       termsAccepted: true,
//       activeRmsUser: false,
//       userType: userRole,
//       deviceType: "ios",
//     );
//
//     showSnackBar(context, "Updating profile...");
//
//     final token = AuthDataHelper.getToken();
//     final response = await HttpClientHelper.patchWithMultipart(
//       ApiConstants.profile,
//       token,
//       fields: {
//         'firstName': user.firstName ?? '',
//         'lastName': user.lastName ?? '',
//         'email': user.email ?? '',
//         'alternateEmail': user.alternateEmail ?? '',
//         'mobile': user.mobile ?? '',
//         'alternateMobile': user.alternateMobile ?? '',
//         'designation': user.designation ?? '',
//         'department': user.department ?? '',
//         'companyName': user.companyName ?? '',
//         'landlineNumber': user.landlineNumber ?? '',
//         'extentionNumber': user.extentionNumber ?? '',
//         'address': user.address ?? '',
//         'country': user.country ?? '',
//         'region': user.region ?? '',
//         'termsAccepted': user.termsAccepted.toString(),
//         'Active_RMS_User': user.activeRmsUser.toString(),
//         'userType': user.userType ?? '',
//         'deviceType': user.deviceType ?? '',
//       },
//       file: user.profileImageFile,
//     );
//
//     final decoded = jsonDecode(response.data);
//
//     final userData = UpdateProfileResponse.fromJson(decoded);
//     if (response.statusCode >= 200 || response.statusCode <= 300) {
//       if (AuthDataHelper.isAdminUser()) {
//         AuthDataHelper.saveUserData(userData.user!);
//         showSnackBar(
//           context,
//           userData.message ?? "Profile updated successfully.",
//         );
//       } else {
//         showSnackBar(context, "Request sent to admin for approval");
//       }
//     } else {
//       showSnackBar(context, "Error: ${userData.message}");
//     }
//   }
//
//   bool validateFields() {
//     setState(() {
//       emailError =
//           emailController.text.trim().isEmpty ? "Please enter email" : null;
//       firstNameError =
//           firstNameController.text.trim().isEmpty
//               ? "Please enter first name"
//               : null;
//       lastNameError =
//           lastNameController.text.trim().isEmpty
//               ? "Please enter last name"
//               : null;
//       companyNameError =
//           companyNameController.text.trim().isEmpty
//               ? "Please enter company name"
//               : null;
//
//       alternateMobileError =
//           (!RegExp(r'^[0-9]{10}$').hasMatch(mobileNumberController.text.trim())
//               ? "Mobile number must be exactly 10 digits"
//               : null);
//     });
//
//     // All correct?
//     return emailError == null &&
//         firstNameError == null &&
//         lastNameError == null &&
//         companyNameError == null &&
//         alternateMobileError == null;
//   }
// }
// */
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:mprs_android/core/auth_data_helper.dart';
// import 'package:mprs_android/core/constants/app_colors.dart';
// import 'package:mprs_android/core/utils/country_utils.dart';
// import 'package:mprs_android/screens/preferences_screen.dart';
// import 'package:mprs_android/widget/common_appbar.dart';
// import 'package:mprs_android/widget/common_fields.dart';
// import 'package:mprs_android/widget/custom_buttons.dart';
//
// import '../../controller/edit_profile_controller.dart';
//
// class EditUserProfileScreen extends StatelessWidget {
//   const EditUserProfileScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     // Inject Controller
//     final controller = Get.put(EditProfileController());
//     final countries = CountryUtils.getAllCountries();
//     final regions = CountryUtils.getRegion();
//
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: CommonAppBar(
//         title: "Profile",
//         onActionPressed: () => Get.to(() => const PreferencesScreen()),
//       ),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // --- PROFILE IMAGE SECTION ---
//                   Center(
//                     child: Stack(
//                       alignment: Alignment.bottomRight,
//                       children: [
//                         Obx(() => Container(
//                           width: 130,
//                           height: 130,
//                           decoration: const BoxDecoration(shape: BoxShape.circle),
//                           child: CircleAvatar(
//                             radius: 60,
//                             backgroundColor: Colors.grey[200],
//                             child: ClipOval(
//                               child: controller.pickedImage.value != null
//                                   ? Image.file(
//                                 controller.pickedImage.value!,
//                                 width: 120,
//                                 height: 120,
//                                 fit: BoxFit.cover,
//                               )
//                                   : _buildNetworkImage(),
//                             ),
//                           ),
//                         )),
//                         Positioned(
//                           bottom: 10,
//                           right: 10,
//                           child: InkWell(
//                             onTap: controller.pickImage,
//                             child: CircleAvatar(
//                               radius: 18,
//                               backgroundColor: AppColors.main,
//                               child: const Icon(
//                                 Icons.camera_alt,
//                                 color: Colors.white,
//                                 size: 18,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   const SizedBox(height: 30),
//
//                   // --- EDITABLE FIELDS ---
//                   Obx(() => buildUserTextField(
//                     label: "First Name",
//                     isRequired: true,
//                     controller: controller.firstNameController,
//                     errorText: controller.firstNameError.value,
//                   )),
//
//                   Obx(() => buildUserTextField(
//                     label: "Last Name",
//                     isRequired: true,
//                     controller: controller.lastNameController,
//                     errorText: controller.lastNameError.value,
//                   )),
//
//                   buildUserTextField(
//                     label: "Mobile Number",
//                     isRequired: true,
//                     editable: false, // Read-only
//                     controller: controller.mobileNumberController,
//                     inputType: TextInputType.phone,
//                   ),
//
//                   Obx(() => buildUserTextField(
//                     label: "Email",
//                     isRequired: true,
//                     controller: controller.emailController,
//                     errorText: controller.emailError.value,
//                   )),
//
//                   buildUserTextField(
//                     label: "Company Name",
//                     isRequired: true,
//                     editable: false, // Read-only
//                     controller: controller.companyNameController,
//                   ),
//
//                   // --- OPTIONAL / DROPDOWN FIELDS ---
//                   Obx(() => buildRoundedDropdown(
//                     label: "Country",
//                     hint: "Select Country (Optional)",
//                     items: countries,
//                     value: controller.selectedCountry.value,
//                     onChanged: (val) => controller.selectedCountry.value = val,
//                     context: context,
//                   )),
//
//                   Obx(() => buildRoundedDropdown(
//                     label: "Region",
//                     hint: "Select Region (Optional)",
//                     items: regions,
//                     value: controller.selectedRegion.value,
//                     onChanged: (val) => controller.selectedRegion.value = val,
//                     context: context,
//                   )),
//
//                   const SizedBox(height: 40),
//
//                   // --- SAVE BUTTON ---
//                   Obx(() => MainButton(
//                     text: controller.isLoading.value ? 'Saving...' : 'Save',
//                     onPressed: () {
//                       if (controller.isLoading.value) return;
//                       controller.saveUser();
//                     },
//                   )),
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//
//             // --- GLOBAL LOADING OVERLAY ---
//             Obx(() => controller.isLoading.value
//                 ? Container(
//               color: Colors.black26,
//               child: const Center(
//                 child: CircularProgressIndicator(),
//               ),
//             )
//                 : const SizedBox.shrink()),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildNetworkImage() {
//     String profileImageUrl = AuthDataHelper.getProfileImage();
//
//     if (profileImageUrl.isEmpty) {
//       return Image.asset(
//         'assets/icons/default_ic_user.png',
//         width: 120,
//         height: 120,
//         fit: BoxFit.cover,
//       );
//     }
//
//     return FadeInImage.assetNetwork(
//       placeholder: 'assets/icons/default_ic_user.png',
//       image: profileImageUrl,
//       width: 120,
//       height: 120,
//       fit: BoxFit.cover,
//       imageErrorBuilder: (context, error, stackTrace) {
//         return Image.asset(
//           'assets/icons/default_ic_user.png',
//           width: 120,
//           height: 120,
//           fit: BoxFit.cover,
//         );
//       },
//     );
//   }
// }
// //controller.isLoading.value ? null : controller.saveUser
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/screens/preferences_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

import '../../controller/edit_profile_controller.dart';
import '../auth/ChangePasswordScreen.dart';

class EditUserProfileScreen extends StatelessWidget {
  const EditUserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditProfileController());
    final countries = CountryUtils.getAllCountries();
    final regions = CountryUtils.getRegion();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(
        title: "Profile",
        actionWidget: const Text(
          "Settings",
          style: TextStyle(
            color: AppColors.main,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        onActionPressed: () => Get.to(() => const PreferencesScreen()),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // PROFILE IMAGE
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Obx(() => Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.main.withOpacity(0.3),
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 58,
                            backgroundColor: Colors.grey[200],
                            child: ClipOval(
                              child: controller.pickedImage.value != null
                                  ? Image.file(
                                controller.pickedImage.value!,
                                width: 116,
                                height: 116,
                                fit: BoxFit.cover,
                              )
                                  : _buildNetworkImage(),
                            ),
                          ),
                        )),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: controller.pickImage,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.main,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Name + email below avatar — uses Rx strings from controller
                  const SizedBox(height: 10),
                  Obx(() => Text(
                    "${controller.displayName.value}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  )),
                  Obx(() => Text(
                    controller.displayEmail.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  )),

                  const SizedBox(height: 28),

                  // SECTION: Basic Information
                  _sectionHeader("Basic Information"),
                  const SizedBox(height: 12),

                  Obx(() => buildUserTextField(
                    label: "First Name",
                    hint: "Enter your First Name",
                    isRequired: true,
                    controller: controller.firstNameController,
                    errorText: controller.firstNameError.value,
                    onChanged: (_) => controller.firstNameError.value = null,
                  )),

                  Obx(() => buildUserTextField(
                    label: "Last Name",
                    hint: "Enter your Last Name",
                    isRequired: true,
                    controller: controller.lastNameController,
                    errorText: controller.lastNameError.value,
                    onChanged: (_) => controller.lastNameError.value = null,
                  )),

                  buildUserTextField(
                    label: "Mobile Number",
                    hint: "Your registered mobile",
                    isRequired: true,
                    editable: false,
                    controller: controller.mobileNumberController,
                    inputType: TextInputType.phone,
                  ),

                  Obx(() => buildUserTextField(
                    label: "Email",
                    hint: "Enter your Email",
                    isRequired: true,
                    controller: controller.emailController,
                    inputType: TextInputType.emailAddress,
                    errorText: controller.emailError.value,
                    onChanged: (_) => controller.emailError.value = null,
                  )),

                  buildUserTextField(
                    label: "Company Name",
                    hint: "Your company name",
                    isRequired: true,
                    editable: false,
                    controller: controller.companyNameController,
                  ),

                  // SECTION: Work Details
                  const SizedBox(height: 8),
                  _sectionHeader("Work Details"),
                  const SizedBox(height: 12),

                  buildUserTextField(
                    label: "Designation",
                    hint: "Enter your Designation (Optional)",
                    editable: false,
                    controller: controller.designationController,
                  ),

                  buildUserTextField(
                    label: "Department",
                    hint: "Enter your Department (Optional)",
                    editable: false,
                    controller: controller.departmentController,
                  ),

                  buildUserTextField(
                    label: "Landline Number",
                    hint: "Enter Landline Number (Optional)",
                    editable: false,
                    controller: controller.landlineNumberController,
                    inputType: TextInputType.phone,
                  ),

                  buildUserTextField(
                    label: "Extension Number",
                    hint: "Enter Extension Number (Optional)",
                    editable: false,
                    controller: controller.extensionController,
                    inputType: TextInputType.number,
                  ),

                  // SECTION: Additional Information
                  const SizedBox(height: 8),
                  _sectionHeader("Additional Information"),
                  const SizedBox(height: 12),

                  buildUserTextField(
                    label: "Alternate Email",
                    hint: "Enter alternate email (Optional)",
                    editable: false,
                    controller: controller.alternateEmailController,
                    inputType: TextInputType.emailAddress,
                  ),

                  buildUserTextField(
                    label: "Alternate Mobile",
                    hint: "Enter alternate mobile (Optional)",
                    editable: false,
                    controller: controller.alternateMobileController,
                    inputType: TextInputType.phone,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),

                  buildUserTextField(
                    label: "GSTIN",
                    hint: "Enter your GSTIN (Optional)",
                    editable: false,
                    controller: controller.gstinController,
                  ),

                  buildUserTextField(
                    label: "Address",
                    hint: "Enter your Address (Optional)",
                    editable: false,
                    controller: controller.addressController,
                  ),

                  // SECTION: Location
                  const SizedBox(height: 8),
                  _sectionHeader("Location"),
                  const SizedBox(height: 12),

                  Obx(() => buildRoundedDropdown(
                    label: "Country",
                    hint: "Select Country (Optional)",
                    items: countries,
                    value: controller.selectedCountry.value,
                    onChanged: (val) =>
                    controller.selectedCountry.value = val,
                    context: context,
                  )),

                  Obx(() => buildRoundedDropdown(
                    label: "Region",
                    hint: "Select Region (Optional)",
                    items: regions,
                    value: controller.selectedRegion.value,
                    onChanged: (val) =>
                    controller.selectedRegion.value = val,
                    context: context,
                  )),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // STICKY SAVE BUTTON + CHANGE PASSWORD
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.cardBorder)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() => MainButton(
                      text: controller.isLoading.value
                          ? 'Saving...'
                          : 'Save Changes',
                      onPressed: controller.isLoading.value
                          ? () {}
                          : controller.saveUser,
                    )),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Get.to(() => const ChangePasswordScreen()),
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: const Text('Change Password'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.main,
                        side: const BorderSide(color: AppColors.main),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // LOADING OVERLAY
            Obx(() => controller.isLoading.value
                ? Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.main),
              ),
            )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.main,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.main,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImage() {
    final profileImageUrl = AuthDataHelper.getProfileImage();

    if (profileImageUrl.isEmpty) {
      return _placeholderImage();
    }

    if (profileImageUrl.startsWith("http")) {
      return FadeInImage.assetNetwork(
        placeholder: 'assets/icons/default_ic_user.png',
        image: profileImageUrl,
        width: 116,
        height: 116,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) => _placeholderImage(),
      );
    }

    final file = File(profileImageUrl);
    if (file.existsSync()) {
      return Image.file(file, width: 116, height: 116, fit: BoxFit.cover);
    }

    return _placeholderImage();
  }

  Widget _placeholderImage() {
    return Image.asset(
      'assets/icons/default_ic_user.png',
      width: 116,
      height: 116,
      fit: BoxFit.cover,
    );
  }
}