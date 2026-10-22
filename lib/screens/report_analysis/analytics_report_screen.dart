import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/model/admin_user_count_model.dart';
import 'package:mprs_android/model/port_model.dart';
import 'package:mprs_android/service/admin_booking_counts_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/port_service.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/inline_dropdown_overlay.dart';

class AnalyticsReportScreen extends StatefulWidget {
  const AnalyticsReportScreen({super.key});

  @override
  State<AnalyticsReportScreen> createState() => _AnalyticsReportScreenState();
}

class _AnalyticsReportScreenState extends State<AnalyticsReportScreen> {
  static const _reachFilterOptions = [
    'All time',
    'This week',
    'This month',
    'This year',
  ];

  // ---------- Bookings analytics (this year only) ----------
  Map<String, int> _bookingCounts = AdminBookingCountsService.emptyCounts();
  bool isBookingLoading = false;

  // ---------- Routes ----------
  List<Map<String, dynamic>> routeData = [];
  bool isRouteLoading = false;
  String _selectedOrigin = '';
  String _selectedDestination = '';
  List<PortModel> _allPorts = [];

  // ---------- User analytics (admin/user/count) ----------
  AdminUserCountResult _userCount = AdminUserCountResult.empty;
  bool isUserCountLoading = false;
  String _reachFilter = 'All time';
  final _countNumberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _fetchUserCount();
    _fetchBookingCounts();
    _fetchRouteReports();
    _loadPorts();
  }

  Future<void> _fetchBookingCounts({bool forceRefresh = false}) async {
    setState(() => isBookingLoading = true);
    try {
      final counts = await AdminBookingCountsService.fetchForPeriod(
        BookingAnalyticsPeriod.thisYear,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() => _bookingCounts = counts);
    } catch (e, st) {
      debugPrint('❌ _fetchBookingCounts error: $e');
      debugPrint('$st');
    } finally {
      if (mounted) setState(() => isBookingLoading = false);
    }
  }

  /// `{ "count": N, "message": "..." }` — omit [userType] for all users, `VIP` for VIP.
  Future<AdminUserCountResponse> _fetchCountForUserType({
    String? userType,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final label = userType?.trim().isNotEmpty == true ? userType!.trim() : 'ALL';
    final url = ApiConstants.adminUserCount(
      userType: userType,
      fromDate: fromDate,
      toDate: toDate,
    );

    debugPrint('══════════ admin/user/count ══════════');
    debugPrint('📡 URL: $url');
    debugPrint('👤 userType: $label');
    if (fromDate != null) {
      debugPrint('📅 fromDate: ${fromDate.toIso8601String().split('T').first}');
    }
    if (toDate != null) {
      debugPrint('📅 toDate: ${toDate.toIso8601String().split('T').first}');
    }

    try {
      final response = await HttpClientHelper.getWithBearer(
        url,
        AuthDataHelper.getToken(),
      );

      debugPrint('📥 HTTP status: ${response.statusCode}');
      debugPrint('📥 raw body: ${response.data}');

      if (response.statusCode != 200) {
        debugPrint('❌ user/count failed for $label (${response.statusCode})');
        return AdminUserCountResponse(userType: label);
      }

      final decoded = jsonDecode(response.data);
      final parsed = AdminUserCountResponse.fromJson(
        decoded,
        userType: label,
      );

      debugPrint('✅ parsed [$label] count=${parsed.count}');
      debugPrint('✅ parsed [$label] message=${parsed.message}');
      debugPrint('══════════════════════════════════════');

      return parsed;
    } catch (e, st) {
      debugPrint('❌ user/count error [$label]: $e');
      debugPrint('$st');
      debugPrint('══════════════════════════════════════');
      return AdminUserCountResponse(userType: label);
    }
  }

  Future<void> _fetchUserCount() async {
    setState(() => isUserCountLoading = true);
    try {
      final period = ReachAnalyticsPeriod.fromLabel(_reachFilter);
      final fromDate = period.fromDate;
      final toDate = period.toDate;

      debugPrint('🔄 Fetching user counts (${period.label})');

      final results = await Future.wait([
        _fetchCountForUserType(fromDate: fromDate, toDate: toDate),
        _fetchCountForUserType(
          userType: 'VIP',
          fromDate: fromDate,
          toDate: toDate,
        ),
        _fetchCountForUserType(
          userType: 'External',
          fromDate: fromDate,
          toDate: toDate,
        ),
        _fetchCountForUserType(
          userType: 'VVIP',
          fromDate: fromDate,
          toDate: toDate,
        ),
      ]);

      final allResult = results[0];
      final vipResult = results[1];
      final externalResult = results[2];
      final vvipResult = results[3];

      final aggregated = AdminUserCountResult(
        allUsers: allResult.count,
        vipUsers: vipResult.count,
        newCustomer: externalResult.count,
        repeatedCustomer: vvipResult.count,
      );

      debugPrint('📊 Aggregated user analytics (${period.label}):');
      debugPrint('   All user (no userType): ${aggregated.allUsers}');
      debugPrint('   VIP user (userType=VIP): ${aggregated.vipUsers}');
      debugPrint('   Total Reach — New Customer (External): ${aggregated.newCustomer}');
      debugPrint('   Total Reach — Repeated (VVIP): ${aggregated.repeatedCustomer}');

      if (!mounted) return;
      setState(() => _userCount = aggregated);
    } catch (e, st) {
      debugPrint('❌ _fetchUserCount error: $e');
      debugPrint('$st');
    } finally {
      if (mounted) {
        setState(() => isUserCountLoading = false);
      }
    }
  }

  String _formatCount(int value, {required bool loading}) =>
      loading ? '—' : _countNumberFormat.format(value);

  Future<void> _loadPorts() async {
    final result = await PortService.getAllPorts();
    if (result?.data != null && mounted) {
      setState(() => _allPorts = result!.data!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─────────────────────────────────────────
  // ROUTE REPORT API
  // ─────────────────────────────────────────
  Future<void> _fetchRouteReports({String? origin, String? destination}) async {
    setState(() => isRouteLoading = true);
    try {
      final params = <String>[];
      if (origin != null && origin.trim().isNotEmpty) {
        params.add('origin=${Uri.encodeComponent(origin.trim())}');
      }
      if (destination != null && destination.trim().isNotEmpty) {
        params.add('destination=${Uri.encodeComponent(destination.trim())}');
      }
      final url = params.isEmpty
          ? ApiConstants.searchReports
          : '${ApiConstants.searchReports}?${params.join('&')}';

      final response = await HttpClientHelper.getWithBearer(
        url,
        AuthDataHelper.getToken(),
      );

      debugPrint('Route report status: ${response.statusCode}');
      debugPrint('Route report data: ${response.data}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.data);

        // Support: array at root, or wrapped under any of these keys
        List raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          raw = decoded['records'] ??
              decoded['data'] ??
              decoded['routes'] ??
              decoded['result'] ??
              decoded['results'] ??
              [];
        }

        debugPrint('Route report raw count: ${raw.length}');

        // Group by "Origin → Destination" and count occurrences
        final Map<String, int> grouped = {};
        for (final item in raw) {
          final originName =
              (item['Origin_Port__r']?['Name'] ?? '').toString().trim();
          final destName =
              (item['Destination_Port__r']?['Name'] ?? '').toString().trim();
          if (originName.isEmpty && destName.isEmpty) continue;
          final label = (originName.isNotEmpty && destName.isNotEmpty)
              ? '$originName → $destName'
              : (originName.isNotEmpty ? originName : destName);
          grouped[label] = (grouped[label] ?? 0) + 1;
        }

        setState(() {
          routeData = grouped.entries
              .map((e) => {'label': e.key, 'count': e.value})
              .toList();
          routeData.sort(
              (a, b) => (b['count'] as int).compareTo(a['count'] as int));
        });
      }
    } catch (e) {
      debugPrint('Route report error: $e');
    } finally {
      setState(() => isRouteLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Analytics & Report",
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: userStatCard(
                      title: "All user",
                      value: _formatCount(
                        _userCount.allUsers,
                        loading: isUserCountLoading,
                      ),
                      icon: Icons.group,
                      iconBgColor: const Color(0xFFDDE6FF),
                      iconColor: const Color(0xFF6479FF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: userStatCard(
                      title: "VIP user",
                      value: _formatCount(
                        _userCount.vipUsers,
                        loading: isUserCountLoading,
                      ),
                      icon: Icons.groups_3,
                      iconBgColor: const Color(0xFFFFE4E4),
                      iconColor: const Color(0xFFFF4A4A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTotalReachCard(),
              const SizedBox(height: 10),
              _topReachRout(),
              const SizedBox(height: 10),
              _buildBookingCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // BOOKING CARD
  // ─────────────────────────────────────────
  Widget _buildBookingCard() {
    final colorMap = {
      'Delivered': AppColors.darkGray,
      'Shipped': AppColors.main,
      'Cancelled': AppColors.lightGrey,
      'Scheduled': AppColors.orange,
    };

    final bookingCounts = AdminBookingCountsService.orderedCounts(_bookingCounts);
    final pieSlices = AdminBookingCountsService.pieSliceValues(bookingCounts);
    final total = AdminBookingCountsService.totalOf(bookingCounts);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bookings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                'This year',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          isBookingLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: pieSlices.isEmpty
                              ? [
                                  PieChartSectionData(
                                    color: AppColors.lightGrey,
                                    value: 1,
                                    title: '',
                                    radius: 50,
                                  ),
                                ]
                              : pieSlices.map((entry) {
                                  return PieChartSectionData(
                                    color: colorMap[entry.key],
                                    value: entry.value,
                                    title: '',
                                    radius: 50,
                                  );
                                }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCount(total, loading: isBookingLoading),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Bookings',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: bookingCounts.entries.map((entry) {
              return _legend(
                '${entry.key} (${entry.value})',
                colorMap[entry.key]!,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // TOP REACHED ROUTES CARD
  // ─────────────────────────────────────────
  Widget _topReachRout() {
    // Max count for bar width calculation
    final maxCount = routeData.isEmpty
        ? 1
        : routeData
        .map((e) => e['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Top Reached Routes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              // SizedBox(
              //   width: 120,
              //   child: InlineDropdownOverlay(
              //     items: ["This week", "2025", "2024", "2023"],
              //     selectedItem: "This week",
              //     onChanged: (value) {},
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _portPickerField(
                  hint: 'Origin',
                  value: _selectedOrigin,
                  onTap: () => _openPortPicker(isOrigin: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _portPickerField(
                  hint: 'Destination',
                  value: _selectedDestination,
                  onTap: () => _openPortPicker(isOrigin: false),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _fetchRouteReports(
                  origin: _selectedOrigin,
                  destination: _selectedDestination,
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isRouteLoading
              ? const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          )
              : routeData.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                "No route data available",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
              : Column(
            children: routeData
                .take(7) // show top 7
                .map((route) {
              final count = route['count'] as int;
              final label = route['label'] as String;
              final percent =
              (count / maxCount * 100).clamp(0, 100).toDouble();
              return _routeBar(label, percent, count);
            })
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _routeBar(String label, double percent, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.main),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth * (percent / 100);
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: barWidth,
                      decoration: BoxDecoration(
                        color: AppColors.main,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget userStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: iconBgColor, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalReachCard() {
    final newCount = _userCount.newCustomer.toDouble();
    final repeatCount = _userCount.repeatedCustomer.toDouble();
    final centerTotal = _userCount.totalReach;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Reach',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(
                width: 130,
                child: InlineDropdownOverlay(
                  key: ValueKey(_reachFilter),
                  items: _reachFilterOptions,
                  selectedItem: _reachFilter,
                  onChanged: (value) {
                    if (_reachFilter == value) return;
                    setState(() => _reachFilter = value);
                    _fetchUserCount();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          isUserCountLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 50,
                          sections: [
                            PieChartSectionData(
                              color: AppColors.main,
                              value: newCount == 0 ? 0.0001 : newCount,
                              title: '',
                              radius: 50,
                            ),
                            PieChartSectionData(
                              color: AppColors.greyBlue,
                              value: repeatCount == 0 ? 0.0001 : repeatCount,
                              title: '',
                              radius: 50,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCount(
                              centerTotal,
                              loading: isUserCountLoading,
                            ),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _reachLegend(
                  "New Customer",
                  _formatCount(
                    _userCount.newCustomer,
                    loading: isUserCountLoading,
                  ),
                  AppColors.main,
                ),
                _reachLegend(
                  "Repeated",
                  _formatCount(
                    _userCount.repeatedCustomer,
                    loading: isUserCountLoading,
                  ),
                  AppColors.greyBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reachLegend(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(color: Colors.black54, fontSize: 20)),
        const SizedBox(width: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 6, backgroundColor: color),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _legend(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }

  // ─────────────────────────────────────────
  // PORT PICKER HELPERS
  // ─────────────────────────────────────────
  Widget _portPickerField({
    required String hint,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                style: TextStyle(
                  fontSize: 13,
                  color: value.isEmpty ? Colors.grey : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _openPortPicker({required bool isOrigin}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PortPickerSheet(
        ports: _allPorts,
        onSelected: (portName) {
          setState(() {
            if (isOrigin) {
              _selectedOrigin = portName;
            } else {
              _selectedDestination = portName;
            }
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Port picker bottom sheet with local search
// ─────────────────────────────────────────────────────────────────────────────
class _PortPickerSheet extends StatefulWidget {
  final List<PortModel> ports;
  final ValueChanged<String> onSelected;

  const _PortPickerSheet({required this.ports, required this.onSelected});

  @override
  State<_PortPickerSheet> createState() => _PortPickerSheetState();
}

class _PortPickerSheetState extends State<_PortPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<PortModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.ports;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.ports
          : widget.ports
              .where((p) => (p.name ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Select Port',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search port...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.main, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No ports found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final port = _filtered[i];
                      final name = port.name ?? '';
                      return ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: port.country != null
                            ? Text(port.country!, style: const TextStyle(fontSize: 11))
                            : null,
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        onTap: () {
                          widget.onSelected(name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}