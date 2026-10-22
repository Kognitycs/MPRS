import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/screens/booking/booking_detail_screen.dart';
import 'package:mprs_android/screens/notification/notification_detail_screen.dart';
import 'package:mprs_android/screens/notification/notification_theme.dart';
import 'package:mprs_android/service/notification/fcm_inbox_service.dart';
import 'package:mprs_android/service/notification/notification_poll_service.dart';
import 'package:mprs_android/service/notification/notification_inbox_store.dart';
import 'package:mprs_android/service/notification/shipment_status_notification_service.dart';
import 'package:mprs_android/widget/common_appbar.dart';

/// Notifications tab — holds previous cards; only adds new ones when they arrive.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with WidgetsBindingObserver {
  final _store = NotificationInboxStore.instance;

  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  bool get _usesRemoteInbox => FcmInboxService.usesRemoteInboxApi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onInboxChanged);
    _hydrateInbox();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _store.reloadFromDatabase().then((_) {
        if (!mounted) return;
        setState(() {
          _notifications = List<NotificationItem>.from(_store.items);
        });
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onInboxChanged);
    super.dispose();
  }

  void _onInboxChanged() {
    if (!mounted) return;
    setState(() {
      _notifications = List<NotificationItem>.from(_store.items);
      _isLoading = false;
      _error = null;
    });
  }

  /// Load SQLite instantly; remote API only for Admin/Internal.
  Future<void> _hydrateInbox({bool forceDb = false}) async {
    setState(() {
      if (_notifications.isEmpty) _isLoading = true;
      _error = null;
    });

    NotificationPollService.syncAndAlert(showBannerForNew: false).catchError((_) {});

    try {
      await ShipmentStatusNotificationService.syncInboxFromBookings();
    } catch (_) {}

    try {
      await _store.reloadFromDatabase();
      if (!mounted) return;
      setState(() {
        _notifications = List<NotificationItem>.from(_store.items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }

    if (_usesRemoteInbox) {
      _syncFromRemoteInBackground();
    }
  }

  void _syncFromRemoteInBackground() {
    FcmInboxService.syncInbox(tryRemote: true)
        .then((_) async {
          if (!mounted) return;
          await _store.reloadFromDatabase();
          if (!mounted) return;
          setState(() {
            _notifications = List<NotificationItem>.from(_store.items);
          });
        })
        .catchError((_) {});
  }

  Future<void> _refreshFromRemote() async {
    setState(() => _isLoading = true);
    try {
      await FcmInboxService.syncInbox(tryRemote: _usesRemoteInbox);
      await _store.reloadFromDatabase();
      if (!mounted) return;
      setState(() {
        _notifications = List<NotificationItem>.from(_store.items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(title: 'Notification', onActionPressed: () {}),
      body: RefreshIndicator(
        color: NotificationTheme.orange,
        onRefresh: _refreshFromRemote,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(
            child: CircularProgressIndicator(color: NotificationTheme.orange),
          ),
        ],
      );
    }

    if (_error != null && _notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'Could not load notifications',
              style: TextStyle(color: NotificationTheme.orange),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _hydrateInbox,
              child: const Text(
                'Retry',
                style: TextStyle(color: NotificationTheme.orange),
              ),
            ),
          ),
        ],
      );
    }

    final displayList =
        _notifications.where((n) => n.hasDisplayContent).toList();

    if (displayList.isEmpty) {
      const hint = 'No notifications yet';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NotificationTheme.orange,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final sections = _groupByDate(displayList);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final entry = sections.entries.elementAt(index);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.key,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 10),
            ...entry.value.map((item) => NotificationCard(item: item)),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Map<String, List<NotificationItem>> _groupByDate(
    List<NotificationItem> notifications,
  ) {
    final grouped = <String, List<NotificationItem>>{};
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in notifications) {
      final date = item.statusUpdatedAt;
      String key;
      if (_isSameDay(date, today)) {
        key = 'Today';
      } else if (_isSameDay(date, yesterday)) {
        key = 'Yesterday';
      } else {
        key = DateFormat('dd MMM yyyy').format(date);
      }
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

void _openNotification(BuildContext context, NotificationItem item) {
  try {
    if (item.link.trim().isNotEmpty) {
      final decoded = jsonDecode(item.link);
      if (decoded is Map && decoded['type']?.toString() == 'shipmentStatus') {
        final orderId = decoded['orderId']?.toString() ?? '';
        final accountId = decoded['accountId']?.toString() ?? '';
        if (orderId.isNotEmpty) {
          Get.to(
            () => const BookingDetailScreen(),
            arguments: {
              'orderId': orderId,
              'accountId': accountId,
              'fromNotification': true,
            },
          );
          return;
        }
      }
    }
  } catch (_) {}

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NotificationDetailScreen()),
  );
}

/// Status updated date from timeline (e.g. 21 May 2026).
String _formatStatusUpdatedTime(DateTime dateTime) {
  return DateFormat('dd MMM yyyy').format(dateTime);
}

class NotificationCard extends StatelessWidget {
  final NotificationItem item;

  const NotificationCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openNotification(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: NotificationTheme.cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.isShipmentAlert && item.statusStepTitle.isNotEmpty) ...[
              Text(
                item.statusStepTitle,
                style: NotificationTheme.shipmentStatusStepStyle,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style:
                        item.isShipmentAlert
                            ? NotificationTheme.shipmentStatusTitleStyle
                            : NotificationTheme.titleStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ),
                Text(
                  _formatStatusUpdatedTime(item.statusUpdatedAt),
                  style: NotificationTheme.captionStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (item.displayBody.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.displayBody, style: NotificationTheme.bodyStyle),
            ],
          ],
        ),
      ),
    );
  }
}
