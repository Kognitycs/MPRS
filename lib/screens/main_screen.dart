import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/service/fcm_token_service.dart';
import 'package:mprs_android/service/notification/notification_poll_service.dart';
import 'package:mprs_android/service/notification/notification_service.dart';
import 'package:mprs_android/screens/home_screen/home_screen.dart';
import 'package:mprs_android/screens/support_screen.dart';
import 'package:mprs_android/screens/home_screen/search_routes_screen.dart';
import 'package:mprs_android/screens/main_tabs.dart';
import 'package:mprs_android/screens/notification/notification_screen.dart';
import 'package:mprs_android/screens/notification/push_notifi.dart';
import 'booking/booking_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;

  /// Book tab inner screen: 0 = Search Rates, 1 = Quotations.
  final int? initialBookTab;

  /// Quotations filter: 0 = All, 1 = Draft, 2 = Accepted.
  final int? initialBookQuoteFilter;

  /// Shipments inner tab: 0 = Booked, 1 = In Progress.
  final int? initialShipmentsTab;

  const MainScreen({
    super.key,
    this.initialTab = MainTabs.home,
    this.initialBookTab,
    this.initialBookQuoteFilter,
    this.initialShipmentsTab,
  });

  // Stable navigator key for the Home tab — used by sub-screens to push
  // routes while keeping the bottom nav bar visible.
  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _selectedIndex;
  NotificationServices? _notificationServices;
  bool _fcmSetupDone = false;
  Timer? _notificationPollTimer;
  int? _bookTab;
  int? _bookQuoteFilter;
  int? _shipmentsTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialTab.clamp(0, 4);
    _bookTab = widget.initialBookTab;
    _bookQuoteFilter = widget.initialBookQuoteFilter;
    _shipmentsTab = widget.initialShipmentsTab;
    // Fresh navigator for the opened tab (e.g. Track after quote submit).
    if (_selectedIndex != MainTabs.home) {
      _navigatorKeys[_selectedIndex] = GlobalKey<NavigatorState>();
    }
    MainTabs.bind(onOpenTab: _openTab, onOpenNotifications: _openNotifications);
    // Push taps open the notification screen that used to live in the bottom bar.
    NotificationServices.onOpenNotificationTab = _openNotifications;

    if (Firebase.apps.isNotEmpty) {
      _notificationServices = NotificationServices();
      _initFCM();
      _startNotificationPolling();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _fcmSetupDone || _notificationServices == null) return;
        _fcmSetupDone = true;
        _notificationServices!.setupNotification(context);
      });
    }
  }

  // Each tab has its own navigator key. Home stays stable so pushed routes survive.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    MainScreen.homeTabNavigatorKey,
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  List<Widget Function()> get _screens => [
    () => const HomeScreen(),
    () => const _SearchTab(),
    () => BookingScreen(
      mode: BookingScreenMode.book,
      initialSelectedTab: _bookTab,
      initialQuoteFilterIndex: _bookQuoteFilter,
    ),
    () => BookingScreen(
      mode: BookingScreenMode.shipments,
      initialSelectedTab: _shipmentsTab,
    ),
    () => const SupportScreen(),
  ];

  void _openTab(MainTabRequest request) {
    if (!mounted) return;
    setState(() {
      if (request.index == MainTabs.book) {
        _bookTab = request.bookTab;
        _bookQuoteFilter = request.bookQuoteFilter;
      }
      if (request.index == MainTabs.track) {
        _shipmentsTab = request.shipmentsTab;
      }
      if (request.index == MainTabs.home) {
        MainScreen.homeTabNavigatorKey.currentState?.popUntil(
          (route) => route.isFirst,
        );
      } else {
        _navigatorKeys[request.index] = GlobalKey<NavigatorState>();
      }
      _selectedIndex = request.index;
    });
  }

  void _openNotifications() {
    if (!mounted) return;
    _refreshNotificationsInBackground();
    final page =
        AuthDataHelper.isInternalUser()
            ? const PushNotifi()
            : const NotificationScreen();
    _navigatorKeys[_selectedIndex].currentState?.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == MainTabs.home) {
      MainScreen.homeTabNavigatorKey.currentState?.popUntil(
        (route) => route.isFirst,
      );
    } else {
      if (index == MainTabs.book) {
        _bookTab = 1;
        _bookQuoteFilter = 1;
      }
      if (index == MainTabs.track) _shipmentsTab = null;
      _navigatorKeys[index] = GlobalKey<NavigatorState>();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  // Build nested navigator
  Widget _buildOffstageNavigator(int index) {
    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (settings) {
          return MaterialPageRoute(builder: (_) => _screens[index]());
        },
      ),
    );
  }

  // Back button handler
  Future<bool> _onWillPop() async {
    final isFirstRoute =
        !await _navigatorKeys[_selectedIndex].currentState!.maybePop();

    if (isFirstRoute) {
      if (_selectedIndex != MainTabs.home) {
        setState(() => _selectedIndex = MainTabs.home);
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationServices.onOpenNotificationTab = null;
    MainTabs.unbind(_openTab);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationsInBackground();
    }
  }

  Future<void> _refreshNotificationsInBackground() async {
    await NotificationPollService.syncAndAlert();
  }

  void _startNotificationPolling() {
    final role = AuthDataHelper.getUserType().trim().toLowerCase();
    if (role.isEmpty) return;

    _notificationPollTimer?.cancel();
    // Local FCM cache sync — no 404 user inbox API for External/VIP/VVIP.
    _notificationPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => NotificationPollService.syncAndAlert(),
    );
    NotificationPollService.syncAndAlert();
  }

  Future<void> _initFCM() async {
    if (Firebase.apps.isEmpty) return;
    await FcmTokenService.syncToBackend();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            _buildOffstageNavigator(0),
            _buildOffstageNavigator(1),

            _buildOffstageNavigator(2),
            _buildOffstageNavigator(3),
            _buildOffstageNavigator(4),
          ],
        ),
        bottomNavigationBar: _HomeBottomBar(
          selectedIndex: _selectedIndex,
          onTap: _onBottomNavTapped,
        ),
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: SearchRouteScreen(embedded: true)),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _HomeBottomBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            _item(MainTabs.home, Icons.home_rounded, 'Home'),
            _item(MainTabs.search, Icons.search, 'Search'),
            _bookButton(),
            _item(MainTabs.track, Icons.directions_boat_outlined, 'Track'),
            _item(MainTabs.genie, Icons.headset_mic_outlined, 'Support'),
          ],
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, String label) {
    final selected = selectedIndex == index;
    final color = selected ? AppColors.main : const Color(0xFF98A2B3);
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookButton() {
    final selected = selectedIndex == MainTabs.book;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(MainTabs.book),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.main,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 2),
            Text(
              'Book',
              style: TextStyle(
                color: selected ? AppColors.main : const Color(0xFF98A2B3),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
