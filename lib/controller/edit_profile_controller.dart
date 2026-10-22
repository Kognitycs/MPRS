// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:mprs_android/core/auth_data_helper.dart';
// import 'package:mprs_android/core/constants/api_constants.dart';
// import 'package:mprs_android/model/common/user_data.dart';
// import 'package:mprs_android/model/update_profile_response.dart';
// import 'package:mprs_android/service/http_client_helper.dart';
//
// import '../core/utils/snackbar_util.dart';
//
// class EditProfileController extends GetxController {
//
//
//   Rxn<UserData?> userData = Rxn();
//
//
//
//   // Text Controllers
//   final firstNameController = TextEditingController();
//   final lastNameController = TextEditingController();
//   final emailController = TextEditingController();
//   final mobileNumberController = TextEditingController();
//   final companyNameController = TextEditingController();
//   final designationController = TextEditingController();
//   final departmentController = TextEditingController();
//   final alternateEmailController = TextEditingController();
//   final alternateMobileController = TextEditingController();
//   final gstinController = TextEditingController();
//   final landlineNumberController = TextEditingController();
//   final extensionController = TextEditingController();
//   final addressController = TextEditingController();
//
//   // Observable states (Rx)
//   var selectedCountry = Rxn<String>();
//   var selectedRegion = Rxn<String>();
//   var pickedImage = Rxn<File>();
//   var userRole = "".obs;
//   var isLoading = false.obs;
//
//   // Error states (Rx)
//   var firstNameError = Rxn<String>();
//   var lastNameError = Rxn<String>();
//   var emailError = Rxn<String>();
//   var companyNameError = Rxn<String>();
//   var alternateMobileError = Rxn<String>();
//
//   @override
//   void onInit() {
//     super.onInit();
//     initUserData();
//     getProfile();
//   }
//
//   // This is the function you wanted to call from other screens
//   void initUserData() {
//     firstNameController.text = AuthDataHelper.getFirstName();
//     lastNameController.text = AuthDataHelper.getLastName();
//     emailController.text = AuthDataHelper.getEmail();
//     mobileNumberController.text = AuthDataHelper.getMobile();
//     companyNameController.text = AuthDataHelper.getCompanyName();
//     designationController.text = AuthDataHelper.getDesignation();
//     departmentController.text = AuthDataHelper.getDepartment();
//     alternateEmailController.text = AuthDataHelper.getAlternateEmail();
//     alternateMobileController.text = AuthDataHelper.getMobile();
//     gstinController.text = AuthDataHelper.getGstin();
//     landlineNumberController.text = AuthDataHelper.getLandline();
//     extensionController.text = AuthDataHelper.getExtension();
//     addressController.text = AuthDataHelper.getAddress();
//
//     selectedCountry.value = AuthDataHelper.getCountry().isEmpty ? null : AuthDataHelper.getCountry();
//     selectedRegion.value = AuthDataHelper.getRegion().isEmpty ? null : AuthDataHelper.getRegion();
//     userRole.value = AuthDataHelper.getUserType();
//
//     // Clear picked image after a successful refresh/save
//     pickedImage.value = null;
//   }
//
//   Future<void> pickImage() async {
//     final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (picked != null) {
//       final file = File(picked.path);
//       if (await file.length() > 2 * 1024 * 1024) {
//         Get.snackbar("Error", "Image size should not exceed 2MB",
//             snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
//         return;
//       }
//       pickedImage.value = file;
//     }
//   }
//
//   bool validateFields() {
//     firstNameError.value = firstNameController.text.trim().isEmpty ? "Please enter first name" : null;
//     lastNameError.value = lastNameController.text.trim().isEmpty ? "Please enter last name" : null;
//     emailError.value = emailController.text.trim().isEmpty ? "Please enter email" : null;
//     companyNameError.value = companyNameController.text.trim().isEmpty ? "Please enter company name" : null;
//
//     if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileNumberController.text.trim())) {
//       alternateMobileError.value = "Mobile number must be exactly 10 digits";
//     } else {
//       alternateMobileError.value = null;
//     }
//
//     return firstNameError.value == null &&
//         lastNameError.value == null &&
//         emailError.value == null &&
//         companyNameError.value == null &&
//         alternateMobileError.value == null;
//   }
//
//   Future<void> saveUser() async {
//     if (!validateFields()) return;
//
//     // Purane overlays clear karein
//     Get.closeAllSnackbars();
//     isLoading.value = true;
//
//     // Crash-safe Loading Dialog
//     showDialog(
//       context: Get.context!,
//       barrierDismissible: false,
//       builder: (context) => const Center(
//         child: CircularProgressIndicator(color: Colors.blue),
//       ),
//     );
//
//     try {
//       final token = AuthDataHelper.getToken();
//       final response = await HttpClientHelper.patchWithMultipart(
//         ApiConstants.profile,
//         token,
//         fields: {
//           'firstName': firstNameController.text.trim(),
//           'lastName': lastNameController.text.trim(),
//           'email': emailController.text.trim(),
//           'alternateEmail': alternateEmailController.text.trim(),
//           'mobile': mobileNumberController.text.trim(),
//           'alternateMobile': alternateMobileController.text.trim(),
//           'designation': designationController.text.trim(),
//           'department': departmentController.text.trim(),
//           'companyName': companyNameController.text.trim(),
//           'landlineNumber': landlineNumberController.text.trim(),
//           'extentionNumber': extensionController.text.trim(),
//           'address': addressController.text.trim(),
//           'country': selectedCountry.value ?? '',
//           'region': selectedRegion.value ?? '',
//           'termsAccepted': 'true',
//           'Active_RMS_User': 'false',
//           'userType': userRole.value,
//           'deviceType': GetPlatform.isIOS ? "ios" : "android",
//         },
//         file: pickedImage.value,
//       );
//
//       // Dialog band karein (Navigator use karke safe rehta hai)
//       Navigator.of(Get.context!, rootNavigator: true).pop();
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final decoded = jsonDecode(response.data);
//         final updateResponse = UpdateProfileResponse.fromJson(decoded);
//
//         if (updateResponse.user != null) {
//           AuthDataHelper.saveUserData(updateResponse.user!);
//           userData.value = updateResponse.user;
//           initUserData();
//           getProfile();
//         }
//
//         // --- AAPKI CUSTOM SNACKBAR LOGIC ---
//         if (AuthDataHelper.isAdminUser()) {
//           Get.snackbar("Success", "Profile updated successfully",
//               backgroundColor: Colors.green, colorText: Colors.white);
//         } else {
//           // Aapka specific method call
//           showSnackBar(Get.context!, "Request sent to admin for approval");
//         }
//
//       } else if (response.statusCode == 400) {
//         // --- 400 CODE HANDLING ---
//         Get.snackbar(
//             "Notice",
//             "You have already sent a request to admin",
//             backgroundColor: AppColors.main,
//             colorText: Colors.white,
//             snackPosition: SnackPosition.BOTTOM
//         );
//       } else {
//         Get.snackbar(
//             "Error",
//             "Update failed: ${response.statusCode}",
//             backgroundColor: Colors.red,
//             colorText: Colors.white,
//             snackPosition: SnackPosition.BOTTOM
//         );
//       }
//     } catch (e) {
//       // Error handling
//       Navigator.of(Get.context!, rootNavigator: true).pop();
//       debugPrint("SaveUser Error: $e");
//       Get.snackbar("Error", "Something went wrong",
//           backgroundColor: Colors.red, colorText: Colors.white);
//     } finally {
//       isLoading.value = false;
//     }
//   }
// /*
//   Future<void> saveUser() async {
//     if (!validateFields()) return;
//
//     isLoading.value = true;
//     Get.rawSnackbar(message: "Updating profile...", isDismissible: false, showProgressIndicator: true);
//
//     try {
//       final token = AuthDataHelper.getToken();
//       final response = await HttpClientHelper.patchWithMultipart(
//         ApiConstants.profile,
//         token,
//         fields: {
//           'firstName': firstNameController.text.trim(),
//           'lastName': lastNameController.text.trim(),
//           'email': emailController.text.trim(),
//           'alternateEmail': alternateEmailController.text.trim(),
//           'mobile': mobileNumberController.text.trim(),
//           'alternateMobile': alternateMobileController.text.trim(),
//           'designation': designationController.text.trim(),
//           'department': departmentController.text.trim(),
//           'companyName': companyNameController.text.trim(),
//           'landlineNumber': landlineNumberController.text.trim(),
//           'extentionNumber': extensionController.text.trim(),
//           'address': addressController.text.trim(),
//           'country': selectedCountry.value ?? '',
//           'region': selectedRegion.value ?? '',
//           'termsAccepted': 'true',
//           'Active_RMS_User': 'false',
//           'userType': userRole.value,
//           'deviceType': GetPlatform.isIOS ? "ios" : "android",
//         },
//         file: pickedImage.value,
//       );
//
//       // Get.closeCurrentSnapshot(); // Close loading snackbar
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final decoded = jsonDecode(response.data);
//         final updateResponse = UpdateProfileResponse.fromJson(decoded);
//
//         if (AuthDataHelper.isAdminUser()) {
//           if (updateResponse.user != null) {
//             AuthDataHelper.saveUserData(updateResponse.user!);
//             initUserData(); // Refresh UI with new data
//           }
//           Get.snackbar("Success", updateResponse.message ?? "Profile updated successfully.");
//         } else {
//           Get.snackbar("Pending", "Request sent to admin for approval", backgroundColor: AppColors.main);
//         }
//       } else {
//         Get.snackbar("Error", "Update failed: ${response.statusCode}", backgroundColor: Colors.red, colorText: Colors.white);
//       }
//     } catch (e) {
//       Get.snackbar("Error", "Something went wrong: $e", backgroundColor: Colors.red, colorText: Colors.white);
//     } finally {
//       isLoading.value = false;
//     }
//   }
// */
//
//   @override
//   void onClose() {
//     firstNameController.dispose();
//     lastNameController.dispose();
//     // ... dispose all other controllers ...
//     super.onClose();
//   }
//
//   Future<void> getProfile() async {
//     try {
//       isLoading.value = true;
//       final token = AuthDataHelper.getToken();
//
//       var response = await HttpClientHelper.getWithBearer(
//           ApiConstants.profile,
//           token
//       );
//
//       if (response.statusCode == 200) {
//         final decodedData = jsonDecode(response.data);
//
//         final userModel = UserData.fromJson(decodedData['user'] ?? decodedData);
//
//         userData.value = userModel;
//
//         AuthDataHelper.saveUserData(userModel);
//         firstNameController.text = userData.value?.firstName??"";
//         lastNameController.text = userData.value?.lastName??"";
//
//         initUserData();
//       } else {
//         Get.snackbar("Error", response.message ?? "Failed to fetch profile");
//       }
//     } catch (e) {
//       debugPrint("❌ Error in getProfile: $e");
//       Get.snackbar("Error", "Something went wrong while fetching profile");
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//
// }
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/update_profile_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';

import '../core/utils/snackbar_util.dart';

class EditProfileController extends GetxController {


  Rxn<UserData?> userData = Rxn();



  // Text Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final mobileNumberController = TextEditingController();
  final companyNameController = TextEditingController();
  final designationController = TextEditingController();
  final departmentController = TextEditingController();
  final alternateEmailController = TextEditingController();
  final alternateMobileController = TextEditingController();
  final gstinController = TextEditingController();
  final landlineNumberController = TextEditingController();
  final extensionController = TextEditingController();
  final addressController = TextEditingController();

  // Observable states (Rx)
  var selectedCountry = Rxn<String>();
  var selectedRegion = Rxn<String>();
  var pickedImage = Rxn<File>();
  var userRole = "".obs;
  var isLoading = false.obs;

  // Avatar header observables — these are what Obx listens to in the screen
  var displayName = "".obs;
  var displayEmail = "".obs;

  // Error states (Rx)
  var firstNameError = Rxn<String>();
  var lastNameError = Rxn<String>();
  var emailError = Rxn<String>();
  var companyNameError = Rxn<String>();
  var alternateMobileError = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    initUserData();
    getProfile();
  }

  // This is the function you wanted to call from other screens
  void initUserData() {
    firstNameController.text = AuthDataHelper.getFirstName();
    lastNameController.text = AuthDataHelper.getLastName();
    emailController.text = AuthDataHelper.getEmail();
    mobileNumberController.text = AuthDataHelper.getMobile();
    companyNameController.text = AuthDataHelper.getCompanyName();
    designationController.text = AuthDataHelper.getDesignation();
    departmentController.text = AuthDataHelper.getDepartment();
    alternateEmailController.text = AuthDataHelper.getAlternateEmail();
    alternateMobileController.text = AuthDataHelper.getMobile();
    gstinController.text = AuthDataHelper.getGstin();
    landlineNumberController.text = AuthDataHelper.getLandline();
    extensionController.text = AuthDataHelper.getExtension();
    addressController.text = AuthDataHelper.getAddress();

    selectedCountry.value = AuthDataHelper.getCountry().isEmpty ? null : AuthDataHelper.getCountry();
    selectedRegion.value = AuthDataHelper.getRegion().isEmpty ? null : AuthDataHelper.getRegion();
    userRole.value = AuthDataHelper.getUserType();

    // Keep avatar header in sync
    displayName.value =
        "${firstNameController.text} ${lastNameController.text}".trim();
    displayEmail.value = emailController.text;

    // Clear picked image after a successful refresh/save
    pickedImage.value = null;
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      if (await file.length() > 2 * 1024 * 1024) {
        Get.snackbar("Error", "Image size should not exceed 2MB",
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      pickedImage.value = file;
    }
  }

  bool validateFields() {
    firstNameError.value = firstNameController.text.trim().isEmpty ? "Please enter first name" : null;
    lastNameError.value = lastNameController.text.trim().isEmpty ? "Please enter last name" : null;
    emailError.value = emailController.text.trim().isEmpty ? "Please enter email" : null;
    companyNameError.value = companyNameController.text.trim().isEmpty ? "Please enter company name" : null;

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileNumberController.text.trim())) {
      alternateMobileError.value = "Mobile number must be exactly 10 digits";
    } else {
      alternateMobileError.value = null;
    }

    return firstNameError.value == null &&
        lastNameError.value == null &&
        emailError.value == null &&
        companyNameError.value == null &&
        alternateMobileError.value == null;
  }

  Future<void> saveUser() async {
    if (!validateFields()) return;

    Get.closeAllSnackbars();
    isLoading.value = true;

    try {
      final token = AuthDataHelper.getToken();
      final response = await HttpClientHelper.patchWithMultipart(
        ApiConstants.profile,
        token,
        fields: {
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'email': emailController.text.trim(),
          'alternateEmail': alternateEmailController.text.trim(),
          'mobile': mobileNumberController.text.trim(),
          'alternateMobile': alternateMobileController.text.trim(),
          'designation': designationController.text.trim(),
          'department': departmentController.text.trim(),
          'companyName': companyNameController.text.trim(),
          'landlineNumber': landlineNumberController.text.trim(),
          'extentionNumber': extensionController.text.trim(),
          'address': addressController.text.trim(),
          'country': selectedCountry.value ?? '',
          'region': selectedRegion.value ?? '',
          'termsAccepted': 'true',
          'Active_RMS_User': 'true', // Arnima
          'userType': userRole.value,
          'deviceType': GetPlatform.isIOS ? "ios" : "android",
        },
        file: pickedImage.value,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.data);
        final updateResponse = UpdateProfileResponse.fromJson(decoded);

        if (updateResponse.user != null) {
          AuthDataHelper.saveUserData(updateResponse.user!);
          userData.value = updateResponse.user;
          initUserData(); // refreshes displayName, displayEmail, all fields
        }

        if (AuthDataHelper.isAdminUser()) {
          Get.snackbar("Success", "Profile updated successfully",
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          showSnackBar(Get.context!, "Request sent to admin for approval");
        }
      } else if (response.statusCode == 400) {
        Get.snackbar("Notice", "You have already sent a request to admin",
            backgroundColor: AppColors.main,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar("Error", "Update failed: ${response.statusCode}",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("SaveUser Error: $e");
      Get.snackbar("Error", "Something went wrong",
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileNumberController.dispose();
    companyNameController.dispose();
    designationController.dispose();
    departmentController.dispose();
    alternateEmailController.dispose();
    alternateMobileController.dispose();
    gstinController.dispose();
    landlineNumberController.dispose();
    extensionController.dispose();
    addressController.dispose();
    super.onClose();
  }

  Future<void> getProfile() async {
    try {
      isLoading.value = true;
      final token = AuthDataHelper.getToken();

      final response = await HttpClientHelper.getWithBearer(
          ApiConstants.profile, token);

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.data);
        final userModel = UserData.fromJson(decodedData['user'] ?? decodedData);

        // The profile endpoint may not return accountId / contactId.
        // Preserve them from the existing DbHelper record so data fetching
        // (savedQuotations, bookings) never loses the Salesforce account link.
        final existing = DbHelper().getUserModel();
        final mergedAccountId = (userModel.accountId?.isNotEmpty == true)
            ? userModel.accountId
            : existing?.accountId;
        final mergedContactId = (userModel.contactId?.isNotEmpty == true)
            ? userModel.contactId
            : existing?.contactId;

        final merged = UserData(
          userId: userModel.userId,
          username: userModel.username,
          firstName: userModel.firstName,
          lastName: userModel.lastName,
          designation: userModel.designation,
          department: userModel.department,
          email: userModel.email,
          alternateEmail: userModel.alternateEmail,
          mobile: userModel.mobile,
          alternateMobile: userModel.alternateMobile,
          landlineNumber: userModel.landlineNumber,
          extentionNumber: userModel.extentionNumber,
          address: userModel.address,
          country: userModel.country,
          region: userModel.region,
          termsAccepted: userModel.termsAccepted,
          isActive: userModel.isActive,
          companyName: userModel.companyName,
          activeRmsUser: userModel.activeRmsUser,
          userType: userModel.userType,
          deviceType: userModel.deviceType,
          profileImageUrl: userModel.profileImageUrl,
          fcmToken: userModel.fcmToken,
          lastUpdatedBy: userModel.lastUpdatedBy,
          id: userModel.id,
          gstin: userModel.gstin,
          createdAt: userModel.createdAt,
          updatedAt: userModel.updatedAt,
          v: userModel.v,
          accountId: mergedAccountId,
          contactId: mergedContactId,
        );

        // Keep both caches in sync so userType and accountId are always fresh.
        AuthDataHelper.saveUserData(merged);
        DbHelper().saveUserModel(merged);
        userData.value = merged;

        initUserData(); // pulls fresh data from AuthDataHelper + syncs displayName/displayEmail
      } else {
        Get.snackbar("Error", response.message ?? "Failed to fetch profile");
      }
    } catch (e) {
      debugPrint("❌ Error in getProfile: $e");
      Get.snackbar("Error", "Something went wrong while fetching profile");
    } finally {
      isLoading.value = false;
    }
  }


}