import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/edit_profile_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/screens/auth/login_mobile_screen.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/screens/home_screen/home_overview.dart';
import 'package:mprs_android/screens/main_tabs.dart';
import 'package:mprs_android/screens/preferences_screen.dart';
import 'package:mprs_android/screens/profile/edit_user_profile_screen.dart';
import 'package:mprs_android/screens/support_screen.dart';
import 'package:mprs_android/service/notification/notification_inbox_store.dart';
import 'package:mprs_android/widget/common_dialog.dart';

import '../../controller/booking_controller.dart';
import '../../core/constants/api_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // String name = "";
  bool isInternalUser = true;
  String userRole = "";

  final EditProfileController controller = Get.put(EditProfileController());
  final BookingController bookingController = Get.put(
    BookingController(),
    tag: "all_bookings",
  );
  final SavedQuotationsController _quotesController = Get.put(
    SavedQuotationsController(),
  );
  final NotificationInboxStore _inbox = NotificationInboxStore.instance;

  @override
  void initState() {
    super.initState();
    loadUserData();
    controller.getProfile();
    _refreshHome();
    _inbox.addListener(_onInbox);
    _inbox.ensureLoaded();
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInbox);
    super.dispose();
  }

  void _onInbox() {
    if (mounted) setState(() {});
  }

  int _activityRefresh = 0;

  Future<void> _refreshHome() async {
    await Future.wait([
      bookingController.getConfirmedBookings(accountScoped: true),
      bookingController.loadTodayBookings(),
      bookingController.getInProgressBookings(
        accountScoped: !AuthDataHelper.isAdminUser(),
      ),
      _quotesController.fetchSavedQuotes(),
    ]);
    if (mounted) setState(() => _activityRefresh++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: buildSideDrawer(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.main,
          onRefresh: _refreshHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                HomeOverview(refreshNonce: _activityRefresh),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      final user = controller.userData.value;
      final firstName =
          (user?.firstName ?? AuthDataHelper.getFirstName()).trim();
      final fallback = AuthDataHelper.getDashboardGreetingName(
        firstName: user?.firstName,
        lastName: user?.lastName,
        companyName:
            user?.companyName ?? DbHelper().getUserModel()?.companyName,
        userType: user?.userType ?? userRole,
      );
      final name = firstName.isNotEmpty ? firstName : fallback;
      final badgeCount = _inbox.items.length;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${getGreeting()}, $name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.montserratBold.copyWith(
                    fontSize: 18,
                    color: const Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Welcome to ',
                        style: AppTextStyles.montserratBold.copyWith(
                          fontSize: 26,
                          color: const Color(0xFF1C2434),
                          height: 1.15,
                        ),
                      ),
                      TextSpan(
                        text: 'MPRS',
                        style: AppTextStyles.montserratBold.copyWith(
                          fontSize: 26,
                          color: AppColors.main,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Let's move the world, together.",
                  style: AppTextStyles.montserratRegular.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _notificationButton(badgeCount),
          const SizedBox(width: 10),
          Builder(
            builder:
                (context) => GestureDetector(
                  onTap: () => Scaffold.of(context).openEndDrawer(),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: getProfileImage(),
                  ),
                ),
          ),
        ],
      );
    });
  }

  Widget _notificationButton(int count) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const CircleBorder(side: BorderSide(color: AppColors.cardBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => MainTabs.openNotifications?.call(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.main,
                size: 22,
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  Widget buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.main, width: 1.5),
        ),
      ),
    );
  }

  ImageProvider getProfileImage() {
    final String image = AuthDataHelper.getProfileImage();

    if (image.isNotEmpty) {
      // Network image (API image)
      if (image.startsWith('http')) {
        return NetworkImage(image);
      }

      // Local file image
      return FileImage(File(image));
    }

    // Default asset image
    return const AssetImage('assets/icons/default_ic_user.png');
  }

  Drawer buildSideDrawer(BuildContext context) {
    return Drawer(
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75, // drawer width
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95), // light background
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: AppColors.main.withOpacity(0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(0),
                    topRight: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                ),
                accountName: Obx(() {
                  String fName =
                      controller.userData.value?.firstName ??
                      AuthDataHelper.getFirstName();
                  String lName =
                      controller.userData.value?.lastName ??
                      AuthDataHelper.getLastName();

                  return Text(
                    "$fName $lName",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  );
                }),
                accountEmail: Text(userRole),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: getProfileImage(),
                ),
              ),
              drawerItem(Icons.person, "Profile", () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditUserProfileScreen()),
                ).then((_) {
                  // This is called when coming back from the profile screen
                  loadUserData();
                });
              }),
              drawerItem(Icons.settings, "Preferences", () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PreferencesScreen()),
                );
              }),
              drawerItem(Icons.headset_mic_outlined, "Support", () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                );
              }),
              drawerItem(Icons.logout, "Logout", () {
                CommonDialog.showByType(
                  context,
                  type: DialogType.logout,
                  onConfirm: () async {
                    performLogout();

                    // Clear login data
                    // await AuthDataHelper.logoutUser();
                    // await AuthDataHelper.clearAllData();

                    // Close only the drawer
                  },
                );
              }),

              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  "v1.0.0",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void loadUserData() {
    setState(() {
      // name = "${AuthDataHelper.getFirstName()} ${AuthDataHelper.getLastName()}";
      isInternalUser = AuthDataHelper.isInternalUser();
      userRole = AuthDataHelper.getUserType();
    });
  }

  Widget drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.main),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  void performLogout() async {
    var response = await ApiProvider().logout();

    if (response.success) {
      Get.offAllNamed('/login');

      Get.snackbar(
        "Success",
        "You have been logged out",
        snackPosition: SnackPosition.BOTTOM,
      );
      Navigator.of(context).pop();

      // Destroy MainScreen completely
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginMobileScreen()),
        (route) => false,
      );
    } else {
      Get.snackbar("Error", response.message ?? "Logout failed");
    }
  }
}
