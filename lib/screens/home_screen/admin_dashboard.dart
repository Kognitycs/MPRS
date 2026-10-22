import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/screens/user/edit_user_screen.dart';
import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/controller/banner_refresh_controller.dart';
import 'package:mprs_android/core/utils/banner_list_util.dart';
import 'package:mprs_android/model/banner_item.dart';
import 'package:mprs_android/screens/banner/add_banner_screen.dart';
import 'package:mprs_android/screens/banner/banner_screen.dart';
import 'package:mprs_android/screens/booking/route_booking_screen.dart';
import 'package:mprs_android/screens/home_screen/pending_approvals.dart';
import 'package:mprs_android/screens/notification/push_notifi.dart';
import 'package:mprs_android/screens/main_screen.dart';
import 'package:mprs_android/screens/report_analysis/analytics_report_screen.dart';
import 'package:mprs_android/screens/subscription/route_subscription_admin_screen.dart';
import 'package:mprs_android/screens/user/user_management_screen.dart';
import 'package:mprs_android/controller/admin_booking_counts_controller.dart';
import 'package:mprs_android/service/admin_booking_counts_service.dart';
import 'package:mprs_android/service/banner_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/banner_display_image.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/widget/inline_dropdown_overlay.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool isAdmin = AuthDataHelper.isAdminUser();

  int totalPendingCount = 0;
  bool isPendingCountLoading = false;
  final _bookingCountFormat = NumberFormat('#,###');
  late final AdminBookingCountsController _bookingCountsCtrl;

  @override
  void initState() {
    super.initState();
    _bookingCountsCtrl = AdminBookingCountsController.ensureRegistered();
    _bookingCountsCtrl.load(forceRefresh: true);
    _fetchPendingCount();
  }

  Future<void> _fetchPendingCount() async {
    setState(() => isPendingCountLoading = true);

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
        setState(() {
          totalPendingCount = jsonBody['totalPendingRecords'] ?? 0;
        });
        debugPrint("Total pending count set to: $totalPendingCount");
      } else {
        debugPrint(
          "Error: Status code ${response.statusCode}, Message: ${response.message}",
        );
      }
    } catch (e) {
      debugPrint("Pending stats API error: $e");
    } finally {
      setState(() => isPendingCountLoading = false);
    }
  }

  Widget _featuresGrid() {
    final List<Map<String, dynamic>> features = [];

    if (isAdmin) {
      features.add({
        'icon': 'assets/icons/user_icon.png',
        'title': 'User management',
        'routeBuilder': () => const UserManagementScreen(),
      });
    }
    if (isAdmin) {
      features.add({
        'icon': 'assets/icons/offer_icon.png',
        'title': 'Pending Approvals',
        'routeBuilder': () => PendingApprovals(),
      });
    }

    features.addAll([
      {
        'icon': 'assets/icons/push_notification.png',
        'title': 'Push notifications',
        'routeBuilder': () => const PushNotifi(),
      },
      {
        'icon': 'assets/icons/route_icon.png',
        'title': 'Open quotes',
        'onTap': () => Get.offAll(() => const MainScreen(initialTab: 3)),
      },
      {
        'icon': 'assets/icons/new_product.png',
        'title': 'Manage Offer/Banner',
        'routeBuilder': () => const BannerScreen(),
      },
    ]);

    if (isAdmin) {
      features.add({
        'icon': 'assets/icons/report_icon.png',
        'title': 'Report & analytics',
        'routeBuilder': () => const AnalyticsReportScreen(),
      });
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children:
          features.map((f) {
            return _buildFeatureCard(
              f['icon'] as String,
              f['title'] as String,
              onTap: () async {
                final directTap = f['onTap'];
                if (directTap is VoidCallback) {
                  directTap();
                  return;
                }
                final routeBuilder = f['routeBuilder'];
                if (routeBuilder == null) return;

                final result = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(builder: (_) => routeBuilder()),
                );
                if (f['title'] == 'Report & analytics') {
                  await _bookingCountsCtrl.load(forceRefresh: true);
                }
                if (f['title'] == 'Pending Approvals' && result == true) {
                  _fetchPendingCount();
                }
              },
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _featuresGrid(),
          const SizedBox(height: 24),
          _buildBookingCard(),
          const SizedBox(height: 10),
          _pendingAction(),
          const SizedBox(height: 10),
          /// Offers / Promotional Banner (hidden for now)
          // const PromotionalBanner(),
          // const SizedBox(height: 10),
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
  Widget _buildBookingCard() {
    final colorMap = {
      'Delivered': AppColors.darkGray,
      'Shipped': AppColors.main,
      'Cancelled': AppColors.lightGrey,
      'Scheduled': AppColors.orange,
    };

    return Obx(() {
      final bookingCounts = AdminBookingCountsService.orderedCounts(
        Map<String, int>.from(_bookingCountsCtrl.bookingCounts),
      );
      final total = AdminBookingCountsService.totalOf(bookingCounts);
      final isBookingLoading = _bookingCountsCtrl.isLoading.value;

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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Bookings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(
                width: 120,
                child: InlineDropdownOverlay(
                  items: ["This year", "2025", "2024", "2023", "2022", "2021", "2020"],
                  selectedItem: "This year",
                  onChanged: (value) {
                    print("Selected year: $value");
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pie Chart
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
                    sections: AdminBookingCountsService.chartOrder.map((status) {
                      final value = (bookingCounts[status] ?? 0).toDouble();
                      return PieChartSectionData(
                        color: colorMap[status] ?? AppColors.lightGrey,
                        value: value == 0 ? 0.0001 : value,
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
                      isBookingLoading ? '—' : _bookingCountFormat.format(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Bookings",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legends with counts
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: AdminBookingCountsService.chartOrder.map((status) {
              final count = bookingCounts[status] ?? 0;
              return _legend(
                "$status ($count)",
                colorMap[status] ?? AppColors.lightGrey,
              );
            }).toList(),
          ),
        ],
      ),
    );
    });
  }
  // Widget _buildBookingCard() {
  //   return StatefulBuilder(
  //     builder: (context, setState) {
  //       return Container(
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: AppColors.white,
  //           borderRadius: BorderRadius.circular(14),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black12.withOpacity(0.08),
  //               blurRadius: 12,
  //               offset: const Offset(0, 6),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Header Row
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 const Text(
  //                   "Bookings",
  //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  //                 ),
  //                 SizedBox(
  //                   width: 120,
  //                   child: InlineDropdownOverlay(
  //                     items: [
  //                       "This year",
  //                       "2025",
  //                       "2024",
  //                       "2023",
  //                       "2022",
  //                       "2021",
  //                       "2020",
  //                     ],
  //                     selectedItem: "This year",
  //                     onChanged: (value) {
  //                       print("Selected year: $value");
  //                     },
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 20),
  //
  //             // Pie Chart
  //             SizedBox(
  //               height: 200,
  //               child: Stack(
  //                 alignment: Alignment.center,
  //                 children: [
  //                   PieChart(
  //                     PieChartData(
  //                       sectionsSpace: 2,
  //                       centerSpaceRadius: 60,
  //                       sections: [
  //                         PieChartSectionData(
  //                           color: AppColors.darkGray,
  //                           value: 203,
  //                           title: '',
  //                           radius: 50,
  //                         ),
  //                         PieChartSectionData(
  //                           color: AppColors.main,
  //                           value: 13,
  //                           title: '',
  //                           radius: 50,
  //                         ),
  //                         PieChartSectionData(
  //                           color: AppColors.lightGrey,
  //                           value: 16,
  //                           title: '',
  //                           radius: 50,
  //                         ),
  //                         PieChartSectionData(
  //                           color: AppColors.orange,
  //                           value: 15,
  //                           title: '',
  //                           radius: 50,
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   const Column(
  //                     mainAxisSize: MainAxisSize.min,
  //                     children: [
  //                       Text(
  //                         "247",
  //                         style: TextStyle(
  //                           fontSize: 22,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                       Text(
  //                         "Bookings",
  //                         style: TextStyle(color: Colors.grey, fontSize: 13),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(height: 20),
  //
  //             // Legends
  //             Wrap(
  //               spacing: 20,
  //               runSpacing: 8,
  //               children: [
  //                 _legend("Delivered", AppColors.darkGray),
  //                 _legend("Pickup Scheduled", AppColors.orange),
  //                 _legend("Shipped", AppColors.main),
  //                 _legend("Cancelled", AppColors.lightGrey),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  /// Simple searchable dropdown using AlertDialog

  Widget _legend(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _pendingAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pending Action",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                isPendingCountLoading
                    ? const SizedBox(
                      height: 28,
                      child: CircularProgressIndicator(),
                    )
                    : Text(
                      totalPendingCount.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        color: AppColors.secondary,
                      ),
                    ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              final acted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PendingApprovals()),
              );
              if (acted == true) _fetchPendingCount();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.main),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              "View More",
              style: TextStyle(
                color: AppColors.main,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class PromotionalBanner extends StatefulWidget {
  const PromotionalBanner({super.key});

  @override
  State<PromotionalBanner> createState() => _PromotionalBannerState();
}

class _PromotionalBannerState extends State<PromotionalBanner> {
  int _currentIndex = 0;
  bool isLoading = false;
  List<BannerItem> banners = [];
  int _imageCacheKey = 0;
  late final BannerRefreshController _refreshController;
  Worker? _refreshWorker;

  @override
  void initState() {
    super.initState();
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
      );

      if (bannerResponse != null && mounted) {
        final activeBanners = BannerListUtil.finalizeFetchedBanners(
          bannerResponse.data.where((b) => b.isActive == true).toList(),
        );

        setState(() {
          banners = activeBanners;
          _imageCacheKey++;
          if (_currentIndex >= activeBanners.length) {
            _currentIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint("🔥 ADMIN DASHBOARD - Banner API error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              "Offers",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),

          if (isLoading)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (banners.isEmpty)
            const SizedBox.shrink()
          else
            Column(
              children: [
                CarouselSlider(
                  key: ValueKey('admin_banner_carousel_$_imageCacheKey'),
                  items: banners.map((banner) {
                    return GestureDetector(
                      onTap: () async {
                        // Internal link navigation
                        if ((banner.linkType?.toLowerCase() == 'internal') &&
                            (banner.linkRef != null && banner.linkRef!.isNotEmpty)) {
                          _navigateToInternalPage(banner.linkRef!);
                          return;
                        }
                        // External link navigation
                        if (banner.bannerUrl.isNotEmpty) {
                          try {
                            final url = Uri.parse(banner.bannerUrl);
                            final canLaunch = await canLaunchUrl(url);
                            if (canLaunch) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              await launchUrl(url, mode: LaunchMode.platformDefault);
                            }
                          } catch (e) {
                            debugPrint('Error launching URL: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open link: ${banner.bannerUrl}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
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
                              // 1. Background Image
                              BannerDisplayImage(
                                bannerId: banner.bannerId,
                                imageUrl: banner.bannerImageUrl,
                                updatedAt: banner.updatedAt,
                                cacheKey: _imageCacheKey,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),

                              // 2. Gradient Overlay
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

                              // 3. Title and CTA
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                          if (banner.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              banner.description,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.8),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF26234),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE4E7EC)),
                                      ),
                                      child: const Text(
                                        'View More',
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
                    height: 200,
                    autoPlay: true,
                    enlargeCenterPage: true,
                    viewportFraction: 0.92,
                    onPageChanged: (index, reason) {
                      setState(() => _currentIndex = index);
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Pill-shaped page indicators — same style as user dashboard
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: banners.asMap().entries.map((entry) {
                    return Container(
                      width: _currentIndex == entry.key ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _currentIndex == entry.key
                            ? const Color(0xFF2E59A8)
                            : Colors.grey.withOpacity(0.4),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlineButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BannerScreen()),
                );
                await getBanner();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToInternalPage(String pageRef) {
    switch (pageRef) {
      case 'Create Banner':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddBannerScreen()),
        );
        break;
      case 'Create Booking':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RouteBookingScreen()),
        );
        break;
      case 'Create Subscription':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RouteSubscriptionAdminScreen()),
        );
        break;
      case 'Profile':
        // Navigate to EditUserScreen for current admin
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditUserScreen(
              user: UserData(
                userId: AuthDataHelper.getUserId(),
                username: AuthDataHelper.getUsername(),
                firstName: AuthDataHelper.getFirstName(),
                lastName: AuthDataHelper.getLastName(),
                email: AuthDataHelper.getEmail(),
                alternateEmail: AuthDataHelper.getAlternateEmail(),
                mobile: AuthDataHelper.getMobile(),
                landlineNumber: AuthDataHelper.getLandline(),
                extentionNumber: AuthDataHelper.getExtension(),
                address: AuthDataHelper.getAddress(),
                country: AuthDataHelper.getCountry(),
                region: AuthDataHelper.getRegion(),
                companyName: AuthDataHelper.getCompanyName(),
                userType: AuthDataHelper.getUserType(),
                profileImageUrl: AuthDataHelper.getProfileImage(),
                gstin: AuthDataHelper.getGstin(),
                id: AuthDataHelper.getId(),
                accountId: AuthDataHelper.getAccountId(),
                contactId: AuthDataHelper.getContactId(),
              ),
            ),
          ),
        );
        break;
      case 'Notifications':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PushNotifi()),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown page: $pageRef'),
            backgroundColor: AppColors.main,
          ),
        );
    }
  }
}
