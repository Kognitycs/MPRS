import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/model/admin_user_count_model.dart';
import 'package:mprs_android/screens/home_screen/home_actions.dart';
import 'package:mprs_android/screens/marquee_webview.dart';
import 'package:mprs_android/screens/report_analysis/analytics_report_screen.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';

const _cardBorder = AppColors.cardBorder;
const _footBlue = Color(0xFF3B82F6);

/// Placeholder book of business until a sales-person API exists.
const _sampleAccounts = <String>[
  'Apex Traders',
  'Blue Harbor Logistics',
  'Crescent Exports',
  'Delta Freight',
  'Eastern Mills',
  'Falcon Cargo',
];

const _sampleAccountCount = 18;
const _sampleOrderCount = 42;
const _sampleOpenQuotes = 11;
const _sampleAcceptedQuotes = 7;

/// Home for an internal sales user.
class InternalDashboard extends StatefulWidget {
  final int refreshNonce;

  const InternalDashboard({super.key, required this.refreshNonce});

  @override
  State<InternalDashboard> createState() => _InternalDashboardState();
}

class _InternalDashboardState extends State<InternalDashboard> {
  bool _usersLoading = true;
  bool _usersAreSample = false;
  int _normalUsers = 0;
  int _vipUsers = 0;
  int _vvipUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void didUpdateWidget(covariant InternalDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _usersLoading = true);
    final counts = await _fetchUserTypeCounts();
    if (!mounted) return;
    setState(() {
      _normalUsers = counts.normal;
      _vipUsers = counts.vip;
      _vvipUsers = counts.vvip;
      _usersAreSample = counts.sample;
      _usersLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What's happening",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2434),
          ),
        ),
        const SizedBox(height: 8),
        const _SampleNote(
          'Sample figures. No API yet for accounts tagged to this sales person.',
        ),
        const SizedBox(height: 8),
        const _StatsGrid(),
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
        const _QuickActions(),
        const SizedBox(height: 22),
        const Text(
          'Users by type',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2434),
          ),
        ),
        const SizedBox(height: 8),
        if (_usersAreSample && !_usersLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _SampleNote(
              'Sample user counts. The app user-count API did not return data.',
            ),
          ),
        if (_usersLoading)
          const _ChartSkeleton()
        else
          _UserTypeChart(
            normal: _normalUsers,
            vip: _vipUsers,
            vvip: _vvipUsers,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: MarqueeWebView(),
          ),
        ),
      ],
    );
  }
}

class _UserTypeCounts {
  final int normal;
  final int vip;
  final int vvip;
  final bool sample;

  const _UserTypeCounts({
    required this.normal,
    required this.vip,
    required this.vvip,
    required this.sample,
  });
}

/// Normal customers are stored as userType External in the app database.
Future<_UserTypeCounts> _fetchUserTypeCounts() async {
  final results = await Future.wait([
    _countUsers('External'),
    _countUsers('VIP'),
    _countUsers('VVIP'),
  ]);
  if (results.any((count) => count == null)) {
    return const _UserTypeCounts(normal: 24, vip: 9, vvip: 3, sample: true);
  }
  return _UserTypeCounts(
    normal: results[0]!,
    vip: results[1]!,
    vvip: results[2]!,
    sample: false,
  );
}

Future<int?> _countUsers(String userType) async {
  final token = AuthDataHelper.getToken();
  try {
    final response = await HttpClientHelper.getWithBearer(
      ApiConstants.adminUserCount(userType: userType),
      token,
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.data);
      return AdminUserCountResponse.fromJson(
        decoded,
        userType: userType,
      ).count;
    }
  } catch (e) {
    debugPrint('user/count $userType failed: $e');
  }

  try {
    final fallback =
        '${ApiConstants.allUsers}?page=1&limit=1&userType=${Uri.encodeQueryComponent(userType)}';
    final response = await HttpClientHelper.getWithBearer(fallback, token);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.data);
    if (decoded is Map && decoded['totalRecords'] is num) {
      return (decoded['totalRecords'] as num).toInt();
    }
  } catch (e) {
    debugPrint('all-users count $userType failed: $e');
  }
  return null;
}

class _SampleNote extends StatelessWidget {
  final String text;

  const _SampleNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.montserratRegular.copyWith(
        fontSize: 11,
        color: const Color(0xFF98A2B3),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.apartment_outlined,
                value: '$_sampleAccountCount',
                label: 'Accounts',
                foot: 'Assigned',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _SampleAccountsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_shipping_outlined,
                value: '$_sampleOrderCount',
                label: 'Orders',
                foot: 'Active',
                onTap: () => HomeActions.openTrack(shipmentsTab: 0),
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
                icon: Icons.request_quote_outlined,
                value: '$_sampleOpenQuotes',
                label: 'Open quotes',
                foot: 'Quotes',
                onTap: () => HomeActions.openBook(bookTab: 1, quoteFilter: 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.task_alt_outlined,
                value: '$_sampleAcceptedQuotes',
                label: 'Accepted quotes',
                foot: 'Quotes',
                onTap: () => HomeActions.openBook(bookTab: 1, quoteFilter: 2),
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

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.foot,
    required this.onTap,
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
            border: Border.all(color: _cardBorder),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.montserratBold.copyWith(
                  fontSize: 22,
                  height: 1.1,
                  color: const Color(0xFF1C2434),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                foot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.montserratMedium.copyWith(
                  fontSize: 12,
                  color: _footBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        icon: Icons.payments_outlined,
        label: 'Search rate',
        onTap: HomeActions.openSearch,
      ),
      _Action(
        icon: Icons.inventory_2_outlined,
        label: 'Orders',
        onTap: () => HomeActions.openTrack(),
      ),
      _Action(
        icon: Icons.event_note_outlined,
        label: 'Bookings',
        onTap: () => HomeActions.openBook(bookTab: 1),
      ),
      _Action(
        icon: Icons.bar_chart_outlined,
        label: 'Reports',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AnalyticsReportScreen(),
            ),
          );
        },
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
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
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
                border: Border.all(color: _cardBorder),
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

class _UserTypeChart extends StatelessWidget {
  final int normal;
  final int vip;
  final int vvip;

  const _UserTypeChart({
    required this.normal,
    required this.vip,
    required this.vvip,
  });

  static const _normalColor = Color(0xFF8ED9A8);
  static const _vipColor = Color(0xFF8EBEF6);
  static const _vvipColor = Color(0xFFC4B5FD);

  @override
  Widget build(BuildContext context) {
    final slices = [
      _Slice(label: 'Normal', count: normal, color: _normalColor),
      _Slice(label: 'VIP', count: vip, color: _vipColor),
      _Slice(label: 'VVIP', count: vvip, color: _vvipColor),
    ];
    final drawn = slices.where((slice) => slice.count > 0).toList();
    final total = normal + vip + vvip;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
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
                              : drawn
                                  .map(
                                    (slice) => PieChartSectionData(
                                      color: slice.color,
                                      value: slice.count.toDouble(),
                                      title: '',
                                      radius: 28,
                                    ),
                                  )
                                  .toList(),
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
}

class _Slice {
  final String label;
  final int count;
  final Color color;

  const _Slice({
    required this.label,
    required this.count,
    required this.color,
  });
}

class _LegendRow extends StatelessWidget {
  final _Slice slice;

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

class _SampleAccountsScreen extends StatelessWidget {
  const _SampleAccountsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Accounts'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _SampleNote('Sample account names. No sales-person API yet.'),
          const SizedBox(height: 12),
          for (final name in _sampleAccounts) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Text(
                name,
                style: AppTextStyles.montserratMedium.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF1C2434),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
    );
  }
}
