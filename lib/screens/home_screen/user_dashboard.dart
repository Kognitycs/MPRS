import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:mprs_android/screens/home_screen/search_routes_screen.dart';
import 'package:mprs_android/screens/main_screen.dart';
import 'package:mprs_android/screens/notification/notification_screen.dart';
import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/controller/banner_refresh_controller.dart';
import 'package:mprs_android/core/utils/banner_list_util.dart';
import 'package:mprs_android/core/utils/banner_image_util.dart';
import 'package:mprs_android/model/banner_item.dart';
import 'package:mprs_android/model/banner_list_response.dart';
import 'package:mprs_android/screens/booking/booking_screen.dart';
import 'package:mprs_android/screens/invoice/invoice_screen.dart';
import 'package:mprs_android/screens/marquee_webview.dart';
import 'package:mprs_android/screens/saved_quotations_screen.dart';
import 'package:mprs_android/screens/subscription/route_subscription_screen.dart';
import 'package:mprs_android/screens/subscription/route_subscription_admin_screen.dart';
import 'package:mprs_android/screens/home_screen/admin_dashboard.dart';
import 'package:mprs_android/service/banner_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/most_used_ports_service.dart';
import 'package:mprs_android/service/port_service.dart';
import 'package:mprs_android/model/port_model.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/screens/user/edit_user_screen.dart';
import 'package:mprs_android/widget/banner_display_image.dart';
import 'package:mprs_android/widget/pricebook_entry_card_details.dart';
import 'package:mprs_android/widget/searchable_dropdown.dart';
import 'package:mprs_android/screens/home_screen/container_size_selection_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mprs_android/screens/home_screen/pricebook_results_screen.dart';
import 'package:mprs_android/screens/quote/get_quote_screen.dart';

import '../../controller/booking_controller.dart';
import '../../controller/saved_quotations_controller.dart';
import '../../core/constants/app_text_styles.dart';
import '../booking/booking_detail_screen.dart';

// Model for simplified pricebook entry used only in UI

class UserDashboard extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const UserDashboard({super.key, this.onNavigateToTab});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _searchRouteKey = GlobalKey();
  final controller = Get.put(SavedQuotationsController());
  final TextEditingController destination1 = TextEditingController();
  final TextEditingController destination2 = TextEditingController();
  final TextEditingController origin1 = TextEditingController();
  final TextEditingController origin2 = TextEditingController();
  bool isStandard = false;
  bool isHaz = false;
  bool isReefer = false;
  List<PortModel> allPorts = [];
  List<String> sectorNames = [];
  List<PricebookEntryModel> pricebookEntries = [];
  String? selectedOriginSector;
  String? selectedOriginPort;
  String? selectedDestinationSector;
  String? selectedDestinationPort;
  bool isPortsLoading = true;
  bool isSearchingPricebook = false;
  int totalPendingCount = 0;
  bool isPendingCountLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
    _fetchPorts();
    // Always force-refresh so a newly-logged-in user never sees a previous
    // user's quotations cached in the GetX singleton.
    controller.ensureQuotesLoaded(forceRefresh: true);
  }

  Future<void> _fetchPorts() async {
    setState(() => isPortsLoading = true);
    try {
      final response = await PortService.getAllPorts();
      if (response != null && response.data != null) {
        setState(() {
          allPorts = response.data!;
          sectorNames = PortService.getUniqueSectors(allPorts);
          isPortsLoading = false;
        });
      } else {
        setState(() => isPortsLoading = false);
      }
    } catch (e) {
      setState(() => isPortsLoading = false);
      debugPrint('Error fetching ports: $e');
    }
  }

  List<PortModel> getFilteredPorts(String? sectorName) {
    if (sectorName == null || sectorName.isEmpty) return allPorts;
    return PortService.getPortsBySector(allPorts, sectorName);
  }

  String? getSectorFromPortName(String? portName) {
    if (portName == null || portName.isEmpty) return null;
    final port = allPorts.firstWhere(
      (p) => (p.name ?? '').toLowerCase() == portName.toLowerCase(),
      orElse: () => PortModel(),
    );
    return (port.sectorName ?? port.sectorId);
  }

  Widget buildSectorDropdown(
    String hint,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    if (sectorNames.isEmpty) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text(
          'No sectors available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final items = <String>[];
    items.add('None');
    items.addAll(sectorNames);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (_) => _scrollSearchRouteIntoView(),
      child: SearchableDropdown(
        hint: hint,
        selectedValue: selectedValue ?? 'None',
        items: items,
        onChanged: (value) {
          if (value == 'None') {
            onChanged(null);
          } else {
            onChanged(value);
          }
        },
        label: hint,
      ),
    );
  }

  Widget buildPortDropdown(
    String hint,
    String? selectedValue,
    List<PortModel> ports,
    ValueChanged<String?> onChanged,
  ) {
    final portNames = ports.map((p) => p.name ?? '').toList();
    if (portNames.isEmpty) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text(
          'No ports available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (_) => _scrollSearchRouteIntoView(),
      child: SearchableDropdown(
        hint: hint,
        selectedValue: selectedValue,
        items: portNames,
        onChanged: onChanged,
        label: hint,
      ),
    );
  }

  Future<void> _fetchPendingCount() async {
    if (mounted) setState(() => isPendingCountLoading = true);

    try {
      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.pendingStats,
        AuthDataHelper.getToken(),
      );

      debugPrint("Pending stats response status: ${response.statusCode}");
      debugPrint("Pending stats response data: ${response.data}");

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.data);
        debugPrint("Parsed JSON: $jsonBody");
        if (mounted) {
          setState(() {
            totalPendingCount = jsonBody['totalPendingRecords'] ?? 0;
          });
        }
        debugPrint("Total pending count set to: $totalPendingCount");
      } else {
        debugPrint("Failed to fetch pending stats: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error fetching pending stats: $e');
    } finally {
      if (mounted) setState(() => isPendingCountLoading = false);
    }
  }

  void _scrollSearchRouteIntoView() {
    final ctx = _searchRouteKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  Future<void> _searchPricebook() async {
    if ((selectedOriginPort == null || selectedOriginPort!.isEmpty) ||
        (selectedDestinationPort == null || selectedDestinationPort!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select origin and destination ports'),
        ),
      );
      return;
    }

    setState(() => isSearchingPricebook = true);

    try {
      // Ensure we send port NAMES (API expects names). If user selection is a port code,
      // map it back to the corresponding port name.
      String originParam = selectedOriginPort!;
      String destinationParam = selectedDestinationPort!;

      try {
        final originModel = allPorts.firstWhere(
          (p) =>
              (p.name ?? '').toLowerCase() ==
                  selectedOriginPort!.toLowerCase() ||
              (p.portCode ?? '').toLowerCase() ==
                  selectedOriginPort!.toLowerCase(),
          orElse: () => PortModel(),
        );
        // Prefer name for API; if we matched by code, replace with the port's name
        originParam =
            (originModel.name != null && originModel.name!.isNotEmpty)
                ? originModel.name!
                : originParam;
      } catch (_) {}

      try {
        final destModel = allPorts.firstWhere(
          (p) =>
              (p.name ?? '').toLowerCase() ==
                  selectedDestinationPort!.toLowerCase() ||
              (p.portCode ?? '').toLowerCase() ==
                  selectedDestinationPort!.toLowerCase(),
          orElse: () => PortModel(),
        );
        // Prefer name for API; if we matched by code, replace with the port's name
        destinationParam =
            (destModel.name != null && destModel.name!.isNotEmpty)
                ? destModel.name!
                : destinationParam;
      } catch (_) {}

      final origin = Uri.encodeComponent(originParam);
      final destination = Uri.encodeComponent(destinationParam);

      String url =
          '${ApiConstants.baseUrl}/user/pricebook/for/ports?originPort=$origin&destinationPort=$destination';
      // Only add containerType if a type is selected
      if (isStandard || isHaz || isReefer) {
        final containerType = Uri.encodeComponent(
          isStandard
              ? 'Standard'
              : isHaz
              ? 'Haz'
              : isReefer
              ? 'Reefer'
              : '',
        );
        url += '&containerType=$containerType';
      }
      debugPrint('Searching pricebook with URL: $url');
      // Diagnostic logs to help debug mismatched responses vs Postman
      debugPrint('🔍 PRICEBOOK - Request URL: $url');
      try {
        final tokenForDebug = AuthDataHelper.getToken();
        debugPrint(
          '🔍 PRICEBOOK - Using token (first 20 chars): ${tokenForDebug.isNotEmpty ? tokenForDebug.substring(0, (tokenForDebug.length > 20 ? 20 : tokenForDebug.length)) : '<empty>'}',
        );
      } catch (_) {}

      final resp = await HttpClientHelper.getWithBearer(
        url,
        AuthDataHelper.getToken(),
      );

      debugPrint('🔍 PRICEBOOK - Response status: ${resp.statusCode}');
      debugPrint('🔍 PRICEBOOK - Response body: ${resp.data}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.data);
        final entries = body['data'] as List<dynamic>? ?? [];

        // collect unique ports and build pricebook models
        final Map<String, PortModel> newPortsByCode = {
          for (var p in allPorts.where((e) => e.portCode != null))
            p.portCode!: p,
        };
        final List<PricebookEntryModel> parsed = [];

        for (final e in entries) {
          try {
            final entryMap = Map<String, dynamic>.from(e as Map);
            final product = entryMap['Product2'] as Map<String, dynamic>?;

            if (product != null) {
              final originPort =
                  product['Origin_Port__r'] as Map<String, dynamic>?;
              final destPort =
                  product['Destination_Port__r'] as Map<String, dynamic>?;

              if (originPort != null) {
                final originName = originPort['Name']?.toString() ?? '';
                final originCode = originPort['Port_Code__c']?.toString() ?? '';
                if (originCode.isNotEmpty &&
                    !newPortsByCode.containsKey(originCode)) {
                  newPortsByCode[originCode] = PortModel(
                    portId: null,
                    name: originName,
                    country: null,
                    portCode: originCode,
                    sectorId: null,
                    sectorName: null,
                    isActive: null,
                  );
                }
              }

              if (destPort != null) {
                final destName = destPort['Name']?.toString() ?? '';
                final destCode = destPort['Port_Code__c']?.toString() ?? '';
                if (destCode.isNotEmpty &&
                    !newPortsByCode.containsKey(destCode)) {
                  newPortsByCode[destCode] = PortModel(
                    portId: null,
                    name: destName,
                    country: null,
                    portCode: destCode,
                    sectorId: null,
                    sectorName: null,
                    isActive: null,
                  );
                }
              }
            }

            parsed.add(PricebookEntryModel.fromJson(entryMap));
          } catch (err) {
            debugPrint('Error parsing pricebook entry: $err');
          }
        }

        // update state with parsed entries and ports/sectors
        setState(() {
          allPorts = newPortsByCode.values.toList();
          sectorNames = PortService.getUniqueSectors(allPorts);
          pricebookEntries = parsed;
        });

        if (parsed.isNotEmpty) {
          await MostUsedPortsService.recordPortUsage(
            portOfLoading: selectedOriginPort,
            portOfDischarge: selectedDestinationPort,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${entries.length} pricebook entries — results updated',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${resp.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error calling pricebook API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching pricebook')),
      );
    } finally {
      if (mounted) setState(() => isSearchingPricebook = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final bottomSafePadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      controller: _scrollController,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: bottomInset > 0 ? bottomInset + 12 : bottomSafePadding + 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            /// Features Grid
            _featuresGrid(),
            const SizedBox(height: 28),

            /// Search Route
            // _searchRoute(),
            //
            // // Embedded preview exists inside Search Route; remove external results section
            // const SizedBox(height: 16),

            /// Pending Actions
            // _pendingAction(),

            // const SizedBox(height: 16),
            //RecentBookingsSection(),

            /// Orders / Quotations
            _seeOrder(),

            const SizedBox(height: 28),

            /// Promotional Banner / Offers (hidden for all users for now)
            // if (!isExternalUser) ...[
            //   UserPromotionalBanner(onNavigateToTab: widget.onNavigateToTab),
            //   const SizedBox(height: 16),
            // ],

            /// Our Services
            _ourServices(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _featuresGrid() {
    // Determine the correct route subscription screen based on user type
    final userType = AuthDataHelper.getUserType().toLowerCase();
    final Widget routeSubscriptionScreen;

    if (userType == 'admin' || userType == 'internal') {
      routeSubscriptionScreen = RouteSubscriptionAdminScreen();
    } else {
      // External, VIP, VVIP users
      routeSubscriptionScreen = RouteSubscriptionScreen();
    }

    final features = [
      // {
      //   'icon': 'assets/icons/invoices_ic.png',
      //   'title': 'Invoice',
      //   'route': InvoiceScreen(),
      // },
      {
        'icon': 'assets/icons/open_booking.png',
        'title': 'My Shipments',
        'route': null,
        'mainTabIndex': 3,
      },
      // {
      //   'icon': 'assets/icons/route_icon.png',
      //   'title': 'Favourites Routes',
      //   'route': null,
      // },
      // {
      //   'icon': 'assets/icons/saved_questions.png',
      //   'title': 'Saved Quotations',
      //   'route': SavedQuotationsScreen(),
      // },
      // {
      //   'icon': 'assets/icons/add_subscription.png',
      //   'title': 'Add Subscription',
      //   'route': routeSubscriptionScreen,
      // },
      {
        'icon': 'assets/icons/pending_task.png',
        'title': 'Saved Quotations',
        'route': null,
        'mainTabIndex': 2,
        'bookTabIndex': 1,
      },
      {
        'icon': 'assets/icons/search_routes.png',
        'title': 'Search Rates',
        'route': SearchRouteScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 16,
      children:
          features.map((f) {
            return _buildFeatureCard(
              f['icon'] as String,
              f['title'] as String,
              onTap: () {
                final tabIndex = f['mainTabIndex'];
                if (tabIndex is int) {
                  final bookTabIndex = f['bookTabIndex'] as int?;
                  Get.offAll(
                    () => MainScreen(
                      initialTab: tabIndex,
                      initialBookTab: bookTabIndex,
                    ),
                  );
                  return;
                }
                if (f['route'] != null) {
                  MainScreen.homeTabNavigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (_) => f['route'] as Widget),
                  );
                }
              },
            );
          }).toList(),
      ),
    );
  }

  Widget _pricebookResults() {
    if (pricebookEntries.isEmpty) return const SizedBox.shrink();

    final previewCount =
        pricebookEntries.length > 3 ? 3 : pricebookEntries.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pricebookEntries.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => PricebookResultsScreen(
                            entries: pricebookEntries,
                            allPorts: allPorts,
                            sectorNames: sectorNames,
                          ),
                    ),
                  );
                },
                child: const Text('View More'),
              ),
            ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewCount,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final e = pricebookEntries[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.anchor,
                                  color: AppColors.main,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    e.originName.isNotEmpty
                                        ? e.originName
                                        : e.originCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 2,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    e.destinationName.isNotEmpty
                                        ? e.destinationName
                                        : e.destinationCode,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.main,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PricebookEntryCardDetails(entry: e),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'USD ${e.unitPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppColors.main,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${e.containerSize} ${e.containerType}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'USD ${e.unitPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${e.containerSize} ${e.containerType}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'MLO Code: ${e.mloCode.isNotEmpty ? e.mloCode : '1000'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  // Find all unique container sizes/types for this route
                                  final allMatching =
                                      pricebookEntries
                                          .where(
                                            (entry) =>
                                                entry.originCode ==
                                                    e.originCode &&
                                                entry.destinationCode ==
                                                    e.destinationCode,
                                          )
                                          .toList();
                                  final uniqueSizes =
                                      allMatching
                                          .map(
                                            (entry) =>
                                                "${entry.containerSize} ${entry.containerType}"
                                                    .trim(),
                                          )
                                          .toSet()
                                          .toList();
                                  return ContainerSizeSelectionScreen(
                                    origin:
                                        e.originName.isNotEmpty
                                            ? e.originName
                                            : e.originCode,
                                    destination:
                                        e.destinationName.isNotEmpty
                                            ? e.destinationName
                                            : e.destinationCode,
                                    routing:
                                        PricebookEntryCardDetails.routingLabel(
                                          e,
                                        ),
                                    transitTime:
                                        PricebookEntryCardDetails.transitLabel(
                                          e,
                                        ),
                                    unitPrice: e.unitPrice,
                                    onConfirm: (selectedLoadType) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => GetQuoteScreen(
                                                initialLoadType:
                                                    selectedLoadType,
                                              ),
                                        ),
                                      );
                                    },
                                    availableSizes: uniqueSizes,
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.main,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              'Proceed',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String imagePath,
    String title, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 40, height: 40),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchRoute() {
    return Stack(
      key: _searchRouteKey,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header (full-width inside card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "Search Rates",
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              // Padded content below the header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    const Text(
                      "Origin",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: buildSectorDropdown(
                            "Select Sector",
                            selectedOriginSector,
                            (value) {
                              setState(() {
                                selectedOriginSector = value;
                                selectedOriginPort = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildPortDropdown(
                            "Select Port",
                            selectedOriginPort,
                            getFilteredPorts(selectedOriginSector),
                            (value) {
                              setState(() {
                                selectedOriginPort = value;
                                if (value != null && value.isNotEmpty)
                                  selectedOriginSector = getSectorFromPortName(
                                    value,
                                  );
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      "Destination",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: buildSectorDropdown(
                            "Select Sector",
                            selectedDestinationSector,
                            (value) {
                              setState(() {
                                selectedDestinationSector = value;
                                selectedDestinationPort = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildPortDropdown(
                            "Select Port",
                            selectedDestinationPort,
                            getFilteredPorts(selectedDestinationSector),
                            (value) {
                              setState(() {
                                selectedDestinationPort = value;
                                if (value != null && value.isNotEmpty)
                                  selectedDestinationSector =
                                      getSectorFromPortName(value);
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Transport type options (boxed style)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: buildOptionBox(
                            'Standard',
                            isStandard,
                            () => setState(() => isStandard = !isStandard),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: buildOptionBox(
                            'Haz',
                            isHaz,
                            () => setState(() => isHaz = !isHaz),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: buildOptionBox(
                            'Reefer',
                            isReefer,
                            () => setState(() => isReefer = !isReefer),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSearchingPricebook ? null : _searchPricebook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.main,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isSearchingPricebook
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Search',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),

                    // Top-3 pricebook preview inside Search Route box
                    if (pricebookEntries.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Top Matches',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            pricebookEntries.length >= 3
                                ? 3
                                : pricebookEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final e = pricebookEntries[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.anchor,
                                            color: AppColors.main,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              e.originName.isNotEmpty
                                                  ? e.originName
                                                  : e.originCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 40,
                                      height: 2,
                                      color: Colors.grey[300],
                                    ),
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e.destinationName.isNotEmpty
                                                  ? e.destinationName
                                                  : e.destinationCode,
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.location_on,
                                            color: AppColors.main,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                PricebookEntryCardDetails(entry: e),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'USD ${e.unitPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppColors.main,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${e.containerSize} ${e.containerType}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) {
                                            final allMatching =
                                                pricebookEntries
                                                    .where(
                                                      (entry) =>
                                                          entry.originCode ==
                                                              e.originCode &&
                                                          entry.destinationCode ==
                                                              e.destinationCode,
                                                    )
                                                    .toList();
                                            final uniqueSizes =
                                                allMatching
                                                    .map(
                                                      (entry) =>
                                                          "${entry.containerSize} ${entry.containerType}"
                                                              .trim(),
                                                    )
                                                    .toSet()
                                                    .toList();
                                            return ContainerSizeSelectionScreen(
                                              origin:
                                                  e.originName.isNotEmpty
                                                      ? e.originName
                                                      : e.originCode,
                                              destination:
                                                  e.destinationName.isNotEmpty
                                                      ? e.destinationName
                                                      : e.destinationCode,
                                              routing:
                                                  PricebookEntryCardDetails.routingLabel(
                                                    e,
                                                  ),
                                              transitTime:
                                                  PricebookEntryCardDetails.transitLabel(
                                                    e,
                                                  ),
                                              unitPrice: e.unitPrice,
                                              onConfirm: (
                                                selectedContainerString,
                                              ) {
                                                // Map the selected string to a valid load type
                                                String? mappedLoadType;
                                                if (selectedContainerString !=
                                                    null) {
                                                  if (selectedContainerString
                                                      .contains('FCL')) {
                                                    mappedLoadType = 'FCL';
                                                  } else if (selectedContainerString
                                                      .contains('LCL')) {
                                                    mappedLoadType = 'LCL';
                                                  } else if (selectedContainerString
                                                      .contains('AIR')) {
                                                    mappedLoadType = 'AIR';
                                                  }
                                                }
                                                final pol =
                                                    e.originName.isNotEmpty
                                                        ? e.originName
                                                        : e.originCode;
                                                final pod =
                                                    e.destinationName.isNotEmpty
                                                        ? e.destinationName
                                                        : e.destinationCode;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) => GetQuoteScreen(
                                                          initialLoadType:
                                                              mappedLoadType,
                                                          initialPol: pol,
                                                          initialPod: pod,
                                                        ),
                                                  ),
                                                );
                                              },
                                              availableSizes: uniqueSizes,
                                            );
                                          },
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.main,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Proceed',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'MLO Code: ${e.mloCode.isNotEmpty ? e.mloCode : '1000'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => PricebookResultsScreen(
                                      entries: pricebookEntries,
                                      allPorts: allPorts,
                                      sectorNames: sectorNames,
                                      initialOriginSector: selectedOriginSector,
                                      initialOriginPort: selectedOriginPort,
                                      initialDestinationSector:
                                          selectedDestinationSector,
                                      initialDestinationPort:
                                          selectedDestinationPort,
                                    ),
                              ),
                            );
                          },
                          child: const Text('View More'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // Loading overlay
        if (isPortsLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading ports...',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildTextField(String hint, TextEditingController controller) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.main, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget buildOptionBox(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: selected ? AppColors.main : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected ? AppColors.main : const Color(0xFFBDBDBD),
                width: 1.2,
              ),
            ),
            child:
                selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: selected ? AppColors.main : AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pending Action",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              isPendingCountLoading
                  ? const SizedBox(
                    height: 28,
                    child: CircularProgressIndicator(),
                  )
                  : Text(
                    totalPendingCount.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.secondary,
                    ),
                  ),
            ],
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.main),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              "View More",
              style: TextStyle(color: AppColors.main),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seeOrder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Quotations",
                style: AppTextStyles.montserratBold.copyWith(fontSize: 18),
              ),
              OutlinedButton(
                onPressed: () {
                  Get.offAll(
                    () => const MainScreen(initialTab: 2, initialBookTab: 1),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2E5AAC), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  "View More",
                  style: AppTextStyles.montserratSemiBold.copyWith(
                    color: const Color(0xFF2E5AAC),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          GetBuilder<SavedQuotationsController>(
            builder: (ctrl) {
              if (ctrl.isLoading) {
                return _buildDashboardShimmer();
              }

              // 2. Empty State
              if (ctrl.quotesList.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "No recent quotations found",
                        style: AppTextStyles.montserratMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final displayList = ctrl.quotesList.take(2).toList();

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 28,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final accentColor =
                      index % 2 == 0
                          ? Colors.deepOrange
                          : const Color(0xFF2456D5);
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: QuotationCard(
                      data: displayList[index],
                      accentColor: accentColor,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget RecentBookingsSection() {
  //   final BookingController controller = Get.put(BookingController());
  //   controller.fetchBookings(onlyNewRequests: false);
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  //     child: Column(
  //       children: [
  //         /// 1. Header Row (Same as Screenshot)
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text(
  //               "Recent bookings",
  //               style: AppTextStyles.montserratBold.copyWith(
  //                 fontSize: 18,
  //                 color: const Color(0xFF333333),
  //               ),
  //             ),
  //             OutlinedButton(
  //               onPressed: () {
  //                 Get.to(() => BookingScreen());
  //               },
  //               style: OutlinedButton.styleFrom(
  //                 side: const BorderSide(color: Color(0xFF2E5AAC), width: 1.2),
  //                 shape: RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 padding: const EdgeInsets.symmetric(horizontal: 16),
  //               ),
  //               child: Text(
  //                 "View More",
  //                 style: AppTextStyles.montserratSemiBold.copyWith(
  //                   color: const Color(0xFF2E5AAC),
  //                   fontSize: 14,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 12),
  //
  //         Obx(() {
  //           if (controller.isLoading.value) {
  //             return _buildDashboardShimmer();
  //
  //             // return const Center(child: CircularProgressIndicator());
  //           }
  //
  //           final recentItems = controller.filteredBookings.take(3).toList();
  //
  //           if (recentItems.isEmpty) {
  //             return Container(
  //               width: double.infinity,
  //               padding: const EdgeInsets.all(30),
  //               decoration: BoxDecoration(
  //                 color: Colors.grey[100],
  //                 borderRadius: BorderRadius.circular(16),
  //                 border: Border.all(color: const Color(0xFFE4E7EC)),
  //               ),
  //               child: Column(
  //                 children: [
  //                   Icon(
  //                     Icons.inventory_2_outlined, // ✅ booking-related icon
  //                     color: Colors.grey[400],
  //                     size: 40,
  //                   ),
  //                   const SizedBox(height: 10),
  //                   Text(
  //                     "No recent bookings found",
  //                     style: AppTextStyles.montserratMedium.copyWith(
  //                       color: Colors.grey[600],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             );
  //           }
  //           return Container(
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(16),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black.withOpacity(0.05),
  //                   blurRadius: 15,
  //                   offset: const Offset(0, 5),
  //                 ),
  //               ],
  //             ),
  //             child: ListView.separated(
  //               shrinkWrap: true,
  //               physics: const NeverScrollableScrollPhysics(),
  //               itemCount: recentItems.length,
  //               separatorBuilder:
  //                   (context, index) => Divider(
  //                     height: 1,
  //                     thickness: 0.5,
  //                     color: Colors.grey.shade200,
  //                     indent: 16,
  //                     endIndent: 16,
  //                   ),
  //               itemBuilder: (context, index) {
  //                 final booking = recentItems[index];
  //                 return _buildSingleBookingRow(booking, index);
  //               },
  //             ),
  //           );
  //         }),
  //       ],
  //     ),
  //   );
  // }

  /// Individual Row inside the Card (Matching Screenshot)
  Widget _buildSingleBookingRow(dynamic booking, int index) {
    const Color themeColor = Color(0xFF2E5AAC);

    return InkWell(
      onTap: () async {
        Map<String, dynamic>? detailData;
        try {
          detailData = Map<String, dynamic>.from(booking.toJson() as Map);
        } catch (_) {
          if (booking is Map) {
            detailData = Map<String, dynamic>.from(booking);
          }
        }

        final orderId =
            detailData?['Id']?.toString() ?? booking.id?.toString() ?? '';

        await Get.to(
          () => const BookingDetailScreen(),
          arguments: {
            'orderId': orderId,
            if (detailData != null) 'detailData': detailData,
            'index': index,
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ID & Category (Blue text)
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.montserratBold.copyWith(
                        fontSize: 14,
                        color: themeColor,
                      ),
                      children: [
                        const TextSpan(
                          text: "Booking ID#",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: "${booking.orderNumber ?? '—'} ",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  /// Route Row (Orange Icons + Port Names + Loaded)
                  Row(
                    children: [
                      Image.asset("assets/images/boat.png", height: 20),
                      // const Icon(
                      //   Icons.directions_boat,
                      //   size: 18,
                      //   color: Colors.deepOrange,
                      // ),
                      const SizedBox(width: 6),
                      Text(
                        booking.portOfLoadingC?.toString() ?? '—',
                        style: AppTextStyles.montserratRegular.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      Spacer(),
                      Image.asset("assets/images/boat.png", height: 20),

                      // const Icon(
                      //   Icons.directions_boat,
                      //   size: 18,
                      //   color: Colors.deepOrange,
                      // ),
                      const SizedBox(width: 6),
                      Text(
                        booking.portOfDestinationC?.toString() ?? '—',
                        style: AppTextStyles.montserratRegular.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 20),
                    ],
                  ),
                ],
              ),
            ),

            /// Download Button (Solid Blue)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(110, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                "Download Invoice",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dashboard ke liye chota Shimmer Loader
  Widget _buildDashboardShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: 2,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _ourServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            "Our Services",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        MarqueeWebView(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _serviceCard(String title, String imageUrl) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(1);
                }
              },
              child: const Text(
                "Get quote",
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class UserPromotionalBanner extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const UserPromotionalBanner({super.key, this.onNavigateToTab});

  @override
  State<UserPromotionalBanner> createState() => _UserPromotionalBannerState();
}

class _UserPromotionalBannerState extends State<UserPromotionalBanner> {
  int _currentIndex = 0;
  bool isLoading = false;
  List<BannerItem> banners = [];
  int _imageCacheKey = 0;
  late final BannerRefreshController _refreshController;
  Worker? _refreshWorker;

  @override
  void initState() {
    super.initState();
    Get.put(SavedQuotationsController());
    _refreshController = BannerRefreshController.ensureRegistered();
    _refreshWorker = ever(_refreshController.refreshTick, (_) {
      if (mounted) getBanner();
    });
    getBanner();
  }

  @override
  void dispose() {
    _refreshWorker?.dispose();
    super.dispose();
  }

  Future<void> getBanner() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final bannerResponse = await BannerService.fetchBannerListResponse(
        page: 1,
        isActive: true,
        status: 'Approved',
      );

      if (bannerResponse != null && mounted) {
        setState(() {
          banners = BannerListUtil.finalizeFetchedBanners(
            bannerResponse.data.where((b) => b.isActive == true).toList(),
          );
          _imageCacheKey++;
          if (_currentIndex >= banners.length) {
            _currentIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint("🎯 USER DASHBOARD - Banner API error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppColors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Offers",
              style: AppTextStyles.montserratBold.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 12),

          /// 🎯 Updated Banner Slider with CTA
          CarouselSlider(
            key: ValueKey('user_banner_carousel_$_imageCacheKey'),
            items:
                banners.map((banner) {
                  return GestureDetector(
                    onTap: () => _handleBannerTap(banner),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // 1. Background Image (Increased Height)
                            BannerDisplayImage(
                              bannerId: banner.bannerId,
                              imageUrl: banner.bannerImageUrl,
                              updatedAt: banner.updatedAt,
                              cacheKey: _imageCacheKey,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),

                            // 2. Gradient Overlay for readability
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),

                            // 3. Title and CTA Button
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Text Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          banner.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (banner.description != null)
                                          Text(
                                            banner.description!,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  // 🎯 MPRS Orange CTA Button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF26234,
                                      ), // MPRS Orange
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE4E7EC)),
                                    ),
                                    child: const Text(
                                      "View More",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
            options: CarouselOptions(
              height: 200, // Matching the stack height
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: 0.92,
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
              },
            ),
          ),

          const SizedBox(height: 12),

          /// ● Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                banners.asMap().entries.map((entry) {
                  return Container(
                    width: _currentIndex == entry.key ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color:
                          _currentIndex == entry.key
                              ? const Color(0xFF2E59A8) // MPRS Blue
                              : Colors.grey.withOpacity(0.4),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Logic for Banner Taps (CTA Action) ---
  void _handleBannerTap(BannerItem banner) {
    debugPrint('🎯 Banner tapped: ${banner.title} → Search Rates');
    _navigateToSearchRates();
  }

  void _navigateToSearchRates() {
    Get.offAll(() => const MainScreen(initialTab: 1));
  }
}
