import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/login_response.dart';

/// -----------------------------
/// Keys for Shared Preferences
/// -----------------------------
const String USER_ID = 'user_id';
const String USERNAME = 'username';
const String FIRST_NAME = 'first_name';
const String LAST_NAME = 'last_name';

const String EMAIL = 'email';
const String ALTERNATE_EMAIL = 'alternate_email';
const String MOBILE = 'mobile';
const String LANDLINE = 'landline';
const String EXTENSION = 'extension';

const String ADDRESS = 'address';
const String COUNTRY = 'country';
const String REGION = 'region';

const String COMPANY_NAME = 'company_name';
const String ACTIVE_RMS_USER = 'active_rms_user';

const String USER_TYPE = 'user_type';
const String DESIGNATION = 'designation';
const String DEPARTMENT = 'department';
const String ID = 'ID';
const String ACCOUNT_ID = 'account_id';
const String CONTACT_ID = 'contact_id';
const String PROFILE_IMAGE = 'profile_image';
const String GSTIN = 'gstin';

const String USER_TOKEN = 'user_token';
const String M_PIN = 'm_pin';

/// --------------------------------------------------
/// AuthDataHelper Class
/// --------------------------------------------------
class AuthDataHelper {
  static void saveUserData(UserData user) {
    PreferenceUtils.setString(USER_ID, user.userId ?? "");
    PreferenceUtils.setString(USERNAME, user.username ?? "");

    PreferenceUtils.setString(FIRST_NAME, user.firstName ?? "");
    PreferenceUtils.setString(LAST_NAME, user.lastName ?? "");

    PreferenceUtils.setString(EMAIL, user.email ?? "");
    PreferenceUtils.setString(ALTERNATE_EMAIL, user.alternateEmail ?? "");
    PreferenceUtils.setString(MOBILE, user.mobile ?? "");
    PreferenceUtils.setString(LANDLINE, user.landlineNumber ?? "");
    PreferenceUtils.setString(EXTENSION, user.extentionNumber ?? "");
    PreferenceUtils.setString(COMPANY_NAME, user.companyName ?? "");
    PreferenceUtils.setBool(ACTIVE_RMS_USER, user.activeRmsUser ?? false);
    PreferenceUtils.setString(ADDRESS, user.address ?? "");
    PreferenceUtils.setString(COUNTRY, user.country ?? "");
    PreferenceUtils.setString(REGION, user.region ?? "");

    PreferenceUtils.setString(COMPANY_NAME, user.companyName ?? "");
    PreferenceUtils.setBool(ACTIVE_RMS_USER, user.activeRmsUser ?? false);

    PreferenceUtils.setString(USER_TYPE, user.userType ?? "");
    PreferenceUtils.setString(DESIGNATION, user.designation ?? "");
    PreferenceUtils.setString(DEPARTMENT, user.department ?? "");
    PreferenceUtils.setString(ID, user.id ?? "");
    if (user.accountId != null && user.accountId!.isNotEmpty) {
      PreferenceUtils.setString(ACCOUNT_ID, user.accountId!);
    }
    PreferenceUtils.setString(CONTACT_ID, user.contactId ?? "");
    PreferenceUtils.setString(PROFILE_IMAGE, user.profileImageUrl ?? "");
    final gstinValue = user.gstin ?? "";
    PreferenceUtils.setString(GSTIN, gstinValue);
  }

  /// -----------------------------
  /// Save Token
  /// -----------------------------
  static void saveUserToken(String token) {
    PreferenceUtils.setString(USER_TOKEN, token);
  }

  /// -----------------------------
  /// Getters
  /// -----------------------------
  static String getUserId() => PreferenceUtils.getString(USER_ID) ?? '';
  static String getUsername() => PreferenceUtils.getString(USERNAME) ?? '';
  static String getFirstName() => PreferenceUtils.getString(FIRST_NAME) ?? '';
  static String getLastName() => PreferenceUtils.getString(LAST_NAME) ?? '';

  static String getEmail() => PreferenceUtils.getString(EMAIL) ?? '';
  static String getAlternateEmail() =>
      PreferenceUtils.getString(ALTERNATE_EMAIL) ?? '';
  static String getMobile() => PreferenceUtils.getString(MOBILE) ?? '';
  static String getLandline() => PreferenceUtils.getString(LANDLINE) ?? '';
  static String getExtension() => PreferenceUtils.getString(EXTENSION) ?? '';

  static String getAddress() => PreferenceUtils.getString(ADDRESS) ?? '';
  static String getCountry() => PreferenceUtils.getString(COUNTRY) ?? '';
  static String getRegion() => PreferenceUtils.getString(REGION) ?? '';

  static String getCompanyName() =>
      PreferenceUtils.getString(COMPANY_NAME) ?? '';
  static bool getActiveRmsUser() =>
      PreferenceUtils.getBool(ACTIVE_RMS_USER) ?? false;

  static String getUserType() => PreferenceUtils.getString(USER_TYPE) ?? '';
  static String getDesignation() =>
      PreferenceUtils.getString(DESIGNATION) ?? '';
  static String getDepartment() => PreferenceUtils.getString(DEPARTMENT) ?? '';
  static String getId() => PreferenceUtils.getString(ID) ?? '';
  static String getAccountId() => PreferenceUtils.getString(ACCOUNT_ID) ?? '';
  static String getContactId() => PreferenceUtils.getString(CONTACT_ID) ?? '';
  static String getProfileImage() =>
      PreferenceUtils.getString(PROFILE_IMAGE) ?? '';
  static String getGstin() => PreferenceUtils.getString(GSTIN) ?? '';

  final companyName = AuthDataHelper.getCompanyName();
  final activeRmsUser = AuthDataHelper.getActiveRmsUser();

  static String getToken() => PreferenceUtils.getString(USER_TOKEN) ?? '';

  static String getMPin() => PreferenceUtils.getString(M_PIN) ?? '';
  static void saveMPin(String mPin) => PreferenceUtils.setString(M_PIN, mPin);
  static void saveAccountId(String accountID) =>
      PreferenceUtils.setString(ACCOUNT_ID, accountID);

  static bool isAdminUser() {
    final userType = getUserType().toLowerCase() ?? "";
    return userType == "admin";
  }

  static bool isInternalUser() {
    final userType = getUserType().toLowerCase() ?? "";
    return userType == "admin" || userType == "internal";
  }

  static bool usesPersonalizedDashboardGreeting() {
    final userType = getUserType().toLowerCase().trim();
    return userType == 'admin' ||
        userType == 'internal' ||
        userType == 'vip' ||
        userType == 'vvip';
  }

  static String getFullName() {
    final parts = [
      getFirstName().trim(),
      getLastName().trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(' ');
  }

  static String getDashboardGreetingName({
    String? firstName,
    String? lastName,
    String? companyName,
    String? userType,
  }) {
    final type = (userType ?? getUserType()).toLowerCase().trim();

    if (type == 'admin' ||
        type == 'internal' ||
        type == 'vip' ||
        type == 'vvip') {
      final parts = [
        (firstName ?? getFirstName()).trim(),
        (lastName ?? getLastName()).trim(),
      ].where((part) => part.isNotEmpty);
      final fullName = parts.join(' ');
      if (fullName.isNotEmpty) return fullName;
    }

    return (companyName ?? getCompanyName()).trim();
  }

  /// -----------------------------
  /// Check Login
  /// -----------------------------
  static bool isUserLoggedIn() {
    return getToken().isNotEmpty;
  }

  /// -----------------------------
  /// Logout (Clear All)
  /// -----------------------------
  static Future<void> logoutUser() async {
    await PreferenceUtils.remove(USER_ID);
    await PreferenceUtils.remove(USERNAME);
    await PreferenceUtils.remove(FIRST_NAME);
    await PreferenceUtils.remove(LAST_NAME);

    await PreferenceUtils.remove(EMAIL);
    await PreferenceUtils.remove(ALTERNATE_EMAIL);
    await PreferenceUtils.remove(MOBILE);
    await PreferenceUtils.remove(LANDLINE);
    await PreferenceUtils.remove(EXTENSION);

    await PreferenceUtils.remove(ADDRESS);
    await PreferenceUtils.remove(COUNTRY);
    await PreferenceUtils.remove(REGION);

    await PreferenceUtils.remove(COMPANY_NAME);
    await PreferenceUtils.remove(ACTIVE_RMS_USER);

    await PreferenceUtils.remove(USER_TYPE);
    await PreferenceUtils.remove(DESIGNATION);
    await PreferenceUtils.remove(DEPARTMENT);
    await PreferenceUtils.remove(ID);
    await PreferenceUtils.remove(ACCOUNT_ID);
    await PreferenceUtils.remove(CONTACT_ID);
    await PreferenceUtils.remove(PROFILE_IMAGE);
    await PreferenceUtils.remove(GSTIN);

    await PreferenceUtils.remove(USER_TOKEN);
    await PreferenceUtils.remove(M_PIN);
  }

  static Future<void> clearAllData() async {
    await PreferenceUtils.clear();
    print("🔥 All user data and preferences have been deleted.");
  }
}
