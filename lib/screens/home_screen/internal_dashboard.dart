import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/screens/home_screen/home_actions.dart';
import 'package:mprs_android/screens/marquee_webview.dart';
import 'package:mprs_android/screens/report_analysis/analytics_report_screen.dart';
import 'package:mprs_android/service/internal_home_stats_service.dart';
import 'package:mprs_android/service/sales_account_directory.dart';
import 'package:mprs_android/screens/user/add_user_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';

const _cardBorder = AppColors.cardBorder;
const _footBlue = Color(0xFF3B82F6);

/// Home for an internal sales user.
class InternalDashboard extends StatefulWidget {
  final int refreshNonce;

  const InternalDashboard({super.key, required this.refreshNonce});

  @override
  State<InternalDashboard> createState() => _InternalDashboardState();
}

class _InternalDashboardState extends State<InternalDashboard> {
  bool _statsLoading = true;
  InternalHomeStats _stats = InternalHomeStats.empty;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant InternalDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadBusinessStats();
  }

  Future<void> _loadBusinessStats() async {
    setState(() => _statsLoading = true);
    final stats = await InternalHomeStatsService.load();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _statsLoading = false;
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
        _StatsGrid(stats: _stats, loading: _statsLoading),
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
        if (_statsLoading)
          const _ChartSkeleton()
        else
          _UserTypeChart(
            normal: _stats.customerTiers.normal,
            vip: _stats.customerTiers.vip,
            vvip: _stats.customerTiers.vvip,
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

class _DataNote extends StatelessWidget {
  final String text;

  const _DataNote(this.text);

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
  final InternalHomeStats stats;
  final bool loading;

  const _StatsGrid({required this.stats, this.loading = false});

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
                value: '${stats.accountCount}',
                label: 'Accounts',
                foot: 'Assigned',
                loading: loading,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) =>
                              _AssignedAccountsScreen(accounts: stats.accounts),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_shipping_outlined,
                value: '${stats.orderCount}',
                label: 'Orders',
                foot: 'Active',
                loading: loading,
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
                value: '${stats.openQuoteCount}',
                label: 'Open quotes',
                foot: 'Quotes',
                loading: loading,
                onTap: () => HomeActions.openBook(bookTab: 1, quoteFilter: 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.task_alt_outlined,
                value: '${stats.acceptedQuoteCount}',
                label: 'Accepted quotes',
                foot: 'Quotes',
                loading: loading,
                onTap: () => HomeActions.openBook(bookTab: 1, quoteFilter: 3),
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
  final bool loading;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.foot,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
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
              SizedBox(
                height: 26,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      loading
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.main,
                            ),
                          )
                          : Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.montserratBold.copyWith(
                              fontSize: 22,
                              height: 1.1,
                              color: const Color(0xFF1C2434),
                            ),
                          ),
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
        label: 'Quotes',
        onTap: () => HomeActions.openBook(bookTab: 1),
      ),
      _Action(
        icon: Icons.person_add_outlined,
        label: 'Add user',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddUserScreen(restrictToExternal: true),
            ),
          );
        },
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

  const _Action({required this.icon, required this.label, required this.onTap});
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

  const _Slice({required this.label, required this.count, required this.color});
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

class _AccountTierChip extends StatelessWidget {
  final String label;

  const _AccountTierChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final bg = switch (label) {
      'VVIP' => const Color(0xFFEDE9FE),
      'VIP' => const Color(0xFFE0EFFF),
      _ => const Color(0xFFE8F6ED),
    };
    final fg = switch (label) {
      'VVIP' => const Color(0xFF6D28D9),
      'VIP' => const Color(0xFF2563EB),
      _ => const Color(0xFF047857),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.montserratMedium.copyWith(fontSize: 11, color: fg),
      ),
    );
  }
}

class _AssignedAccountsScreen extends StatelessWidget {
  final List<SalesAccountChoice> accounts;

  const _AssignedAccountsScreen({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Accounts'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (accounts.isEmpty)
            const _DataNote('No customer accounts for your OwnerId yet.')
          else
            for (final account in accounts) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.name,
                        style: AppTextStyles.montserratMedium.copyWith(
                          fontSize: 14,
                          color: const Color(0xFF1C2434),
                        ),
                      ),
                    ),
                    _AccountTierChip(label: account.customerTierLabel),
                  ],
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.main,
        ),
      ),
    );
  }
}
