import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/controller/search_routes_controller.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/screens/banner/banner_screen.dart';
import 'package:mprs_android/screens/booking/today_bookings_screen.dart';
import 'package:mprs_android/screens/home_screen/home_actions.dart';
import 'package:mprs_android/screens/home_screen/pending_approvals.dart';
import 'package:mprs_android/screens/marquee_webview.dart';
import 'package:mprs_android/screens/notification/push_notifi.dart';
import 'package:mprs_android/screens/report_analysis/analytics_report_screen.dart';
import 'package:mprs_android/screens/user/user_management_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';

const _homeCardBorder = AppColors.cardBorder;
const _homeFootBlue = Color(0xFF3B82F6);

bool _opensSearchFromRoute() {
  final type = AuthDataHelper.getUserType().toLowerCase().trim();
  return type == 'external' || type == 'internal';
}

Future<void> _openSearchForRoute(
  BuildContext context,
  _SearchRouteRank route,
) async {
  final controller =
      Get.isRegistered<SearchRouteController>()
          ? Get.find<SearchRouteController>()
          : Get.put(SearchRouteController());
  await controller.prefillRoute(
    originName: route.origin,
    destinationName: route.destination,
  );
  if (!context.mounted) return;
  Navigator.of(context).pop();
  HomeActions.openSearch();
}

String _homeAccountId() {
  final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
  if (fromDb.isNotEmpty) return fromDb;
  return AuthDataHelper.getAccountId().trim();
}

/// Quotes for the signed-in account. Admin quote lists include every account,
/// so a row with no account id is left out. Other users already load their
/// own account, and those rows often omit the id.
bool _quoteBelongsToAccount(SavedQuotationsModel quote, String accountId) {
  if (accountId.isEmpty) return false;
  final onQuote = quote.accountId?.trim() ?? '';
  if (onQuote.isEmpty) return !AuthDataHelper.isAdminUser();
  return onQuote == accountId;
}

class HomeOverview extends StatelessWidget {
  final int refreshNonce;

  const HomeOverview({super.key, this.refreshNonce = 0});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BookingController>(
      tag: 'all_bookings',
      builder: (bookings) {
        return GetBuilder<SavedQuotationsController>(
          builder: (quotes) {
            final firstLoad =
                (bookings.isBookedLoading.value &&
                    bookings.allBookings.isEmpty &&
                    bookings.inProgressBookings.isEmpty) ||
                (quotes.isLoading && quotes.quotesList.isEmpty);
            final stats = HomeTodayStats.from(
              bookings: bookings,
              quotes: quotes,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "What's happening today",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 8),
                if (!firstLoad &&
                    (stats.usingSampleShipments || stats.usingSampleQuotes))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Sample figures shown because live data could not be loaded.',
                      style: AppTextStyles.montserratRegular.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF98A2B3),
                      ),
                    ),
                  ),
                if (firstLoad)
                  const _StatsSkeleton()
                else
                  _StatsRow(
                    stats: stats,
                    todayOrders: HomeTodayStats.ordersBookedToday(bookings),
                  ),
                _HomeSearchActivity(refreshNonce: refreshNonce),
                const SizedBox(height: 22),
                const Text(
                  'Quick actions',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 10),
                _QuickActions(),
                if (AuthDataHelper.isAdminUser()) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Workspace',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _WorkspaceRow(),
                ],
                const SizedBox(height: 22),
                const Text(
                  'Your activity',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 12),
                if (firstLoad)
                  const _ActivityChartSkeleton()
                else
                  _AccountActivityChart(stats: stats),
                const SizedBox(height: 22),
                const Text(
                  'Our services',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _homeCardBorder),
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: MarqueeWebView(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class HomeTodayStats {
  final String bookedValue;
  final String acceptedValue;
  final String todayValue;
  final String draftValue;
  final int bookedCount;
  final int acceptedCount;
  final int draftCount;
  final bool usingSampleShipments;
  final bool usingSampleQuotes;

  const HomeTodayStats({
    required this.bookedValue,
    required this.acceptedValue,
    required this.todayValue,
    required this.draftValue,
    required this.bookedCount,
    required this.acceptedCount,
    required this.draftCount,
    required this.usingSampleShipments,
    required this.usingSampleQuotes,
  });

  /// Quote tabs on Book: 0 all, 1 draft, 2 accepted.
  static const acceptedQuoteFilter = 2;
  static const draftQuoteFilter = 1;

  static HomeTodayStats from({
    required BookingController bookings,
    required SavedQuotationsController quotes,
  }) {
    final orders = _orderRecords(bookings);
    final shipmentsFailed = bookings.confirmedLoadFailed && orders.isEmpty;
    final quoteRows = _visibleQuotes(bookings, quotes);
    final useSampleQuotes =
        quotes.quotesLoadFailed &&
        bookings.inProgressLoadFailed &&
        quoteRows.isEmpty;
    final useSampleShipments = shipmentsFailed && orders.isEmpty;

    if (useSampleShipments && useSampleQuotes) {
      return _sample();
    }

    final booked = orders.length;
    final bookedToday = ordersBookedToday(bookings).length;
    final accepted =
        quoteRows
            .where((row) => SavedQuotationsModel.isAcceptedStatus(row.status))
            .length;
    final draft =
        quoteRows
            .where((row) => SavedQuotationsModel.isDraftStatus(row.status))
            .length;

    return HomeTodayStats(
      bookedValue: useSampleShipments ? '12' : '$booked',
      acceptedValue: useSampleQuotes ? '4' : '$accepted',
      todayValue: useSampleShipments ? '2' : '$bookedToday',
      draftValue: useSampleQuotes ? '3' : '$draft',
      bookedCount: useSampleShipments ? 12 : booked,
      acceptedCount: useSampleQuotes ? 4 : accepted,
      draftCount: useSampleQuotes ? 3 : draft,
      usingSampleShipments: useSampleShipments,
      usingSampleQuotes: useSampleQuotes,
    );
  }

  static HomeTodayStats _sample() {
    return const HomeTodayStats(
      bookedValue: '12',
      acceptedValue: '4',
      todayValue: '2',
      draftValue: '3',
      bookedCount: 12,
      acceptedCount: 4,
      draftCount: 3,
      usingSampleShipments: true,
      usingSampleQuotes: true,
    );
  }

  /// Confirmed orders on Shipments → Booked. Reserved quotes waiting for an
  /// order are not included.
  static List<Records> _orderRecords(BookingController bookings) {
    final seen = <String>{};
    final rows = <Records>[];
    for (final record in bookings.allBookings) {
      if (!_isOrderRecord(record)) continue;
      final id = record.id?.toString().trim() ?? '';
      final key =
          id.isNotEmpty
              ? id
              : '${record.orderNumber ?? ''}|${record.quoteId ?? ''}';
      if (!seen.add(key)) continue;
      rows.add(record);
    }
    return rows;
  }

  static bool _isOrderRecord(Records record) {
    final status =
        (record.trackingStatusC ?? '').toString().trim().toLowerCase();
    if (status == 'reserved') return false;
    final id = record.id?.toString().trim() ?? '';
    final quoteId = record.quoteId?.toString().trim() ?? '';
    final orderNo =
        (record.orderNumber ?? record.orderReferenceNumber ?? '')
            .toString()
            .trim();
    if (orderNo.isNotEmpty) return true;
    if (id.startsWith('801')) return true;
    if (quoteId.isNotEmpty && quoteId == id) return false;
    return id.isNotEmpty;
  }

  static List<_QuoteCountRow> _visibleQuotes(
    BookingController bookings,
    SavedQuotationsController quotes,
  ) {
    final bookedQuoteIds = <String>{
      for (final order in _orderRecords(bookings))
        if ((order.quoteId?.toString().trim() ?? '').isNotEmpty)
          order.quoteId.toString().trim(),
    };
    final byId = <String, _QuoteCountRow>{};

    void add(String? rawId, String status, bool visible) {
      final id = rawId?.trim() ?? '';
      if (id.isEmpty || !visible || bookedQuoteIds.contains(id)) return;
      final normalized = SavedQuotationsModel.normalizeQuoteListStatus(status);
      if (normalized.isEmpty) return;
      final current = byId[id];
      if (current == null || current.status.isEmpty) {
        byId[id] = _QuoteCountRow(id, normalized);
      }
    }

    final countEveryAccount = AuthDataHelper.isAdminUser();
    for (final record in bookings.inProgressBookings) {
      if (_isTestBooking(record, bookings)) continue;
      final id = record.id?.toString().trim() ?? '';
      final seed = bookings.inProgressAdminQuoteById[id];
      add(
        id,
        _bookingQuoteStatus(record, bookings),
        _hasQuoteRoute(record, bookings) ||
            (seed?.shouldShowInQuotationsList ?? false),
      );
    }

    final accountId = _homeAccountId();
    for (final quote in quotes.quotesList) {
      if (countEveryAccount) {
        if (!quote.isOpportunityFromRms) continue;
      } else if (!_quoteBelongsToAccount(quote, accountId)) {
        continue;
      }
      add(quote.id, quote.status ?? '', quote.shouldShowInQuotationsList);
    }
    for (final quote in bookings.inProgressAdminQuoteById.values) {
      if (!countEveryAccount && !_quoteBelongsToAccount(quote, accountId)) {
        continue;
      }
      add(quote.id, quote.status ?? '', quote.shouldShowInQuotationsList);
    }
    return byId.values.toList();
  }

  static bool _isTestBooking(Records record, BookingController bookings) {
    final id = record.id?.toString().trim() ?? '';
    final seed = bookings.inProgressAdminQuoteById[id];
    if (seed?.isTestQuoteData == true) return true;
    return SavedQuotationsModel.isTestQuoteLabel(
      record.quoteName?.toString() ?? record.orderNumber?.toString(),
      opportunityName: record.opportunityName?.toString(),
    );
  }

  static String _bookingQuoteStatus(
    Records record,
    BookingController bookings,
  ) {
    final id = record.id?.toString().trim() ?? '';
    final seed = bookings.inProgressAdminQuoteById[id];
    for (final raw in [
      record.trackingStatusC,
      record.customStatusC,
      seed?.status,
    ]) {
      final normalized = SavedQuotationsModel.normalizeQuoteListStatus(
        raw?.toString(),
      );
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  static bool _hasQuoteRoute(Records record, BookingController bookings) {
    final id = record.id?.toString().trim() ?? '';
    final seed = bookings.inProgressAdminQuoteById[id];
    final pol =
        (record.portOfLoadingC ?? seed?.originPortR?.name ?? '')
            .toString()
            .trim();
    final pod =
        (record.portOfDestinationC ?? seed?.destinationPortR?.name ?? '')
            .toString()
            .trim();
    return pol.isNotEmpty && pod.isNotEmpty;
  }

  /// Orders created today. Uses the Salesforce today query when it has loaded.
  static List<Records> ordersBookedToday(BookingController bookings) {
    if (bookings.todayBookingsReady) return bookings.todayBookings;
    final today = DateTime.now();
    return _orderRecords(bookings).where((order) {
      final created = _parseDate(order.createdDate);
      final booked = _parseDate(order.bookedDateC);
      return _isSameDay(created ?? booked, today);
    }).toList();
  }

  static bool _isSameDay(DateTime? date, DateTime day) {
    if (date == null) return false;
    return date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  static DateTime? _calendarDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime(year, month, day);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is num) {
      final millis =
          value > 100000000000 ? value.toInt() : (value * 1000).round();
      final local = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: false);
      return DateTime(local.year, local.month, local.day);
    }
    var text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return null;
    final datePart = text.split('T').first.split(' ').first;
    final iso = datePart.split('-');
    if (iso.length == 3 && iso[0].length == 4) {
      final calendar = _calendarDate(
        int.tryParse(iso[0]),
        int.tryParse(iso[1]),
        int.tryParse(iso[2]),
      );
      if (calendar != null) return calendar;
    }
    final localParts = datePart.split(RegExp(r'[/\-]'));
    if (localParts.length == 3 && localParts[2].length == 4) {
      final calendar = _calendarDate(
        int.tryParse(localParts[2]),
        int.tryParse(localParts[1]),
        int.tryParse(localParts[0]),
      );
      if (calendar != null) return calendar;
    }
    text = text.replaceFirst(' ', 'T');
    text = text.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (match) => '${match[1]}:${match[2]}',
    );
    final parsed = DateTime.tryParse(text)?.toLocal();
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}

class _QuoteCountRow {
  final String id;
  final String status;

  const _QuoteCountRow(this.id, this.status);
}

class _StatsRow extends StatelessWidget {
  final HomeTodayStats stats;
  final List<Records> todayOrders;

  const _StatsRow({required this.stats, required this.todayOrders});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_shipping_outlined,
                value: stats.bookedValue,
                label: 'Booked',
                foot: 'Orders',
                onTap: () => HomeActions.openTrack(shipmentsTab: 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.task_alt_outlined,
                value: stats.acceptedValue,
                label: 'Accepted Quote',
                foot: 'Quotes',
                onTap:
                    () => HomeActions.openBook(
                      bookTab: 1,
                      quoteFilter: HomeTodayStats.acceptedQuoteFilter,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_outlined,
                value: stats.todayValue,
                label: 'Today Booking',
                foot: 'Booked today',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TodayBookingsScreen(orders: todayOrders),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.edit_note_outlined,
                value: stats.draftValue,
                label: 'Draft quote',
                foot: 'Quotes',
                onTap:
                    () => HomeActions.openBook(
                      bookTab: 1,
                      quoteFilter: HomeTodayStats.draftQuoteFilter,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String foot;
  final VoidCallback onTap;
  final bool wrapValue;
  final double? valueFontSize;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.foot,
    required this.onTap,
    this.wrapValue = false,
    this.valueFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _homeCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.main, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.montserratMedium.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: wrapValue ? null : 1,
                overflow:
                    wrapValue ? TextOverflow.visible : TextOverflow.ellipsis,
                style: AppTextStyles.montserratBold.copyWith(
                  fontSize: valueFontSize ?? (wrapValue ? 13 : 22),
                  height: wrapValue ? 1.25 : 1.1,
                  color: const Color(0xFF1C2434),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      foot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.montserratMedium.copyWith(
                        fontSize: 12,
                        color: _homeFootBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile(int index) {
      return Expanded(
        child: Container(
          height: 96,
          margin: EdgeInsets.only(left: index.isOdd ? 12 : 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _homeCardBorder),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [tile(0), tile(1)]),
        const SizedBox(height: 12),
        Row(children: [tile(2), tile(3)]),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        icon: Icons.local_shipping_outlined,
        label: 'Bookings',
        color: const Color(0xFF7C3AED),
        background: const Color(0xFFF3E8FF),
        onTap: () => HomeActions.openBook(bookTab: 1, quoteFilter: 1),
      ),
      _Action(
        icon: Icons.inventory_2_outlined,
        label: 'My shipments',
        color: const Color(0xFF0891B2),
        background: const Color(0xFFE0F7FA),
        onTap: () => HomeActions.openTrack(),
      ),
      _Action(
        icon: Icons.payments_outlined,
        label: 'Search rates',
        color: const Color(0xFF16A34A),
        background: const Color(0xFFE8F8EE),
        onTap: HomeActions.openSearch,
      ),
      _Action(
        icon: Icons.headset_mic_outlined,
        label: 'Support',
        color: AppColors.main,
        background: const Color(0xFFE8F0FE),
        onTap: () => HomeActions.openSupport(context),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in actions)
          Expanded(child: _QuickActionButton(action: action)),
      ],
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });
}

class _QuickActionButton extends StatelessWidget {
  final _Action action;

  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _homeCardBorder),
              ),
              child: Icon(action.icon, color: AppColors.main, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.montserratMedium.copyWith(
                fontSize: 10,
                height: 1.2,
                color: const Color(0xFF344054),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow();

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthDataHelper.isAdminUser();
    final items = <_Action>[
      if (isAdmin)
        _Action(
          icon: Icons.group_outlined,
          label: 'Users',
          color: AppColors.main,
          background: const Color(0xFFE8F0FE),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserManagementScreen(),
                ),
              ),
        ),
      if (isAdmin)
        _Action(
          icon: Icons.fact_check_outlined,
          label: 'Approvals',
          color: const Color(0xFFEA580C),
          background: const Color(0xFFFFF1E8),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PendingApprovals()),
              ),
        ),
      _Action(
        icon: Icons.notifications_active_outlined,
        label: 'Push',
        color: const Color(0xFF7C3AED),
        background: const Color(0xFFF3E8FF),
        onTap:
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PushNotifi())),
      ),
      _Action(
        icon: Icons.local_offer_outlined,
        label: 'Banners',
        color: const Color(0xFF0891B2),
        background: const Color(0xFFE0F7FA),
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BannerScreen()),
            ),
      ),
      _Action(
        icon: Icons.inventory_outlined,
        label: 'Open\nquotes',
        color: const Color(0xFF16A34A),
        background: const Color(0xFFE8F8EE),
        onTap: () => HomeActions.openTrack(),
      ),
      if (isAdmin)
        _Action(
          icon: Icons.insights_outlined,
          label: 'Reports',
          color: const Color(0xFFDC2626),
          background: const Color(0xFFFEECEC),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AnalyticsReportScreen(),
                ),
              ),
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            SizedBox(width: 72, child: _QuickActionButton(action: item)),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _ActivitySlice {
  final String label;
  final int count;
  final Color color;

  const _ActivitySlice({
    required this.label,
    required this.count,
    required this.color,
  });
}

class _AccountActivityChart extends StatelessWidget {
  final HomeTodayStats stats;

  const _AccountActivityChart({required this.stats});

  static const _accepted = Color(0xFFC4B5FD);
  static const _booked = Color(0xFF8EBEF6);
  static const _draft = Color(0xFF8ED9A8);

  @override
  Widget build(BuildContext context) {
    final slices = _slices();
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.count);
    final drawn = slices.where((slice) => slice.count > 0).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homeCardBorder),
      ),
      child: Column(
        children: [
          Center(
            child: SizedBox(
              height: 156,
              width: 156,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      startDegreeOffset: -90,
                      sections:
                          drawn.isEmpty
                              ? [
                                PieChartSectionData(
                                  color: const Color(0xFFE8EEF6),
                                  value: 1,
                                  title: '',
                                  radius: 26,
                                ),
                              ]
                              : drawn.map((slice) {
                                return PieChartSectionData(
                                  color: slice.color,
                                  value: slice.count.toDouble(),
                                  title: '',
                                  radius: 28,
                                  titleStyle: AppTextStyles.montserratBold
                                      .copyWith(
                                        fontSize: 11,
                                        color: const Color(0xFF1C2434),
                                      ),
                                );
                              }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: AppTextStyles.montserratBold.copyWith(
                          fontSize: 16,
                          color: const Color(0xFF1C2434),
                        ),
                      ),
                      Text(
                        'Total',
                        style: AppTextStyles.montserratMedium.copyWith(
                          fontSize: 10,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final slice in slices) ...[
            const SizedBox(height: 8),
            _LegendRow(slice: slice),
          ],
        ],
      ),
    );
  }

  List<_ActivitySlice> _slices() {
    return [
      _ActivitySlice(
        label: 'Accepted quotes',
        count: stats.acceptedCount,
        color: _accepted,
      ),
      _ActivitySlice(label: 'Booked', count: stats.bookedCount, color: _booked),
      _ActivitySlice(
        label: 'Draft quotes',
        count: stats.draftCount,
        color: _draft,
      ),
    ];
  }
}

class _LegendRow extends StatelessWidget {
  final _ActivitySlice slice;

  const _LegendRow({required this.slice});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.label,
            style: AppTextStyles.montserratMedium.copyWith(
              fontSize: 13,
              color: const Color(0xFF344054),
            ),
          ),
        ),
        Text(
          '${slice.count}',
          style: AppTextStyles.montserratBold.copyWith(
            fontSize: 13,
            color: const Color(0xFF1C2434),
          ),
        ),
      ],
    );
  }
}

class _ActivityChartSkeleton extends StatelessWidget {
  const _ActivityChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homeCardBorder),
      ),
    );
  }
}

class _SearchRouteRank {
  final String origin;
  final String destination;
  final int count;

  const _SearchRouteRank({
    required this.origin,
    required this.destination,
    required this.count,
  });

  String get route => '$origin → $destination';
}

/// App opportunities (Opp_From_RMS_App__c). Admin sees every account.
/// External and internal users see only their account. Routes are ranked here.
class _HomeSearchActivity extends StatefulWidget {
  final int refreshNonce;

  const _HomeSearchActivity({required this.refreshNonce});

  @override
  State<_HomeSearchActivity> createState() => _HomeSearchActivityState();
}

class _HomeSearchActivityState extends State<_HomeSearchActivity> {
  bool _loading = true;
  int _opportunityCount = 0;
  List<_SearchRouteRank> _topRoutes = const [];

  bool get _isAdmin => AuthDataHelper.isAdminUser();

  bool get _showsSection {
    final type = AuthDataHelper.getUserType().toLowerCase().trim();
    return type == 'admin' || type == 'external' || type == 'internal';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _HomeSearchActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) _load();
  }

  Future<void> _load() async {
    if (!_showsSection) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final accountId = _isAdmin ? '' : _homeAccountId();
      if (!_isAdmin && accountId.isEmpty) {
        debugPrint('❌ Search activity: account id is empty');
        if (mounted) {
          setState(() {
            _opportunityCount = 0;
            _topRoutes = const [];
            _loading = false;
          });
        }
        return;
      }

      final url = ApiConstants.rmsAppOpportunities(
        accountId: _isAdmin ? null : accountId,
      );
      debugPrint('📡 RMS opportunities: $url');
      final response = await HttpClientHelper.getWithBearer(
        url,
        AuthDataHelper.getToken(),
      );
      if (response.statusCode != 200) {
        debugPrint(
          '❌ RMS opportunities HTTP ${response.statusCode}: ${response.data}',
        );
        throw Exception('HTTP ${response.statusCode}');
      }
      final parsed = _parseOpportunities(response.data, accountId);
      debugPrint(
        '✅ RMS opportunities: total=${parsed.$1} routes=${parsed.$2.length}',
      );
      if (!mounted) return;
      setState(() {
        _opportunityCount = parsed.$1;
        _topRoutes = parsed.$2;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ RMS opportunities failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _opportunityCount = 0;
        _topRoutes = const [];
        _loading = false;
      });
    }
  }

  (int, List<_SearchRouteRank>) _parseOpportunities(
    dynamic body,
    String accountId,
  ) {
    final decoded = body is String ? jsonDecode(body) : body;
    final records = _recordList(decoded);
    final kept = <Map<String, dynamic>>[];
    for (final item in records) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      if (!_isAdmin && accountId.isNotEmpty) {
        final onRow = row['AccountId']?.toString().trim() ?? '';
        if (onRow.isNotEmpty && onRow != accountId) continue;
      }
      kept.add(row);
    }

    final counts = <String, int>{};
    final origins = <String, String>{};
    final destinations = <String, String>{};
    for (final row in kept) {
      final origin = _portName(row['Origin_Port__r']);
      final destination = _portName(row['Destination_Port__r']);
      if (origin.isEmpty || destination.isEmpty) continue;
      final label = '$origin → $destination';
      counts[label] = (counts[label] ?? 0) + 1;
      origins[label] = origin;
      destinations[label] = destination;
    }
    final ranked =
        counts.entries.toList()..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });
    final top =
        ranked
            .take(10)
            .map(
              (entry) => _SearchRouteRank(
                origin: origins[entry.key] ?? '',
                destination: destinations[entry.key] ?? '',
                count: entry.value,
              ),
            )
            .toList();
    final reported = _totalSize(decoded);
    final dropped = records.whereType<Map>().length != kept.length;
    final total =
        !dropped && reported != null && reported >= kept.length
            ? reported
            : kept.length;
    return (total, top);
  }

  int? _totalSize(dynamic decoded) {
    if (decoded is! Map) return null;
    final direct = decoded['totalSize'];
    if (direct is num) return direct.toInt();
    for (final key in ['data', 'body', 'result']) {
      final value = decoded[key];
      if (value is Map && value['totalSize'] is num) {
        return (value['totalSize'] as num).toInt();
      }
    }
    return null;
  }

  List<dynamic> _recordList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is! Map) return const [];
    for (final key in ['records', 'data', 'body', 'result']) {
      final value = decoded[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = value['records'] ?? value['data'];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  String _portName(dynamic port) {
    if (port is Map) return port['Name']?.toString().trim() ?? '';
    return '';
  }

  void _openRouteList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MostSearchRatesScreen(routes: _topRoutes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showsSection) return const SizedBox.shrink();
    final topName = _topRoutes.isEmpty ? '—' : _topRoutes.first.route;
    final topFoot =
        _loading
            ? 'Loading'
            : _topRoutes.isEmpty
            ? 'No searches'
            : '${_topRoutes.first.count} searches';
    final mostSearched = _StatCard(
      icon: Icons.route_outlined,
      value: _loading ? '—' : topName,
      label: 'Most search rates',
      foot: topFoot,
      wrapValue: true,
      valueFontSize: _isAdmin ? null : 16,
      onTap: _loading ? () {} : _openRouteList,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isAdmin) ...[
            Expanded(
              child: _StatCard(
                icon: Icons.work_outline,
                value: _loading ? '—' : '$_opportunityCount',
                label: 'Opportunity created',
                foot: 'Total',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: mostSearched),
        ],
      ),
    );
  }
}

class _MostSearchRatesScreen extends StatelessWidget {
  final List<_SearchRouteRank> routes;

  const _MostSearchRatesScreen({required this.routes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Most search rates'),
      body:
          routes.isEmpty
              ? Center(
                child: Text(
                  'No searches yet',
                  style: AppTextStyles.montserratMedium.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF667085),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: routes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final opensSearch = _opensSearchFromRoute();
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap:
                          opensSearch
                              ? () => _openSearchForRoute(context, route)
                              : null,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _homeCardBorder),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${index + 1}',
                              style: AppTextStyles.montserratBold.copyWith(
                                fontSize: 16,
                                color: AppColors.main,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                route.route,
                                style: AppTextStyles.montserratMedium.copyWith(
                                  fontSize: 14,
                                  color: const Color(0xFF1C2434),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${route.count}',
                              style: AppTextStyles.montserratBold.copyWith(
                                fontSize: 16,
                                color: const Color(0xFF1C2434),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
