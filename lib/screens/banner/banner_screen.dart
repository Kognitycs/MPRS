import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/utils/banner_list_util.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/controller/banner_refresh_controller.dart';
import 'package:mprs_android/model/banner_item.dart';
import 'package:mprs_android/model/banner_list_response.dart';
import 'package:mprs_android/screens/banner/add_banner_screen.dart';
import 'package:mprs_android/service/banner_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/banner_display_image.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/search_user_bar.dart';

class BannerScreen extends StatefulWidget {
  const BannerScreen({super.key});

  @override
  State<BannerScreen> createState() => _BannerScreenState();
}

class _BannerScreenState extends State<BannerScreen> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<BannerItem> banners = [];

  int currentPage = 1;
  int totalPages = 1;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool isSearching = false;
  String searchKey = "";
  int _imageCacheKey = 0;

  bool isAdmin = AuthDataHelper.isAdminUser();

  @override
  void initState() {
    super.initState();
    getBanner(isFirstLoad: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          currentPage < totalPages) {
        getBanner();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Banner Management",
        actionWidget: Text(
          "Add New",
          style: TextStyle(
            color: AppColors.main,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onActionPressed: () async {
          final result = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(builder: (_) => const AddBannerScreen()),
          );

          if (result != null) {
            await _handleBannerChange(result);
          }
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// SEARCH
            SearchUserBar(
              hintText: "Search banner",
              controller: searchController,
              onChanged: (value) {
                if (value.isEmpty && isSearching) {
                  /// RESET TO NORMAL LIST
                  isSearching = false;
                  searchKey = "";
                  currentPage = 1;
                  totalPages = 1;
                  banners.clear();
                  getBanner(isFirstLoad: true);
                }
              },
              onSubmitted: (value) {
                if (value.trim().isEmpty) return;

                /// START SEARCH
                isSearching = true;
                searchKey = value.trim();
                currentPage = 1;
                totalPages = 1;
                banners.clear();
                getBanner(isFirstLoad: true);
              },
            ),

            const SizedBox(height: 12),

            /// LIST
            Expanded(
              child:
                  banners.isEmpty && isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: AppColors.main),
                      )
                      : banners.isEmpty
                      ? const Center(child: Text("No Record found"))
                      : ListView.separated(
                        controller: _scrollController,
                        itemCount: banners.length + (isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == banners.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return _bannerCard(banners[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- API WITH PAGINATION ----------------
  Future<void> _handleBannerChange(dynamic result) async {
    isSearching = false;
    searchController.clear();
    searchKey = "";
    await _reloadBanners();

    if (result is BannerItem && mounted) {
      _applyBannerUpdate(result);
    }
  }

  void _applyBannerUpdate(BannerItem updatedBanner) {
    setState(() {
      final index = banners.indexWhere(
        (banner) => banner.bannerId == updatedBanner.bannerId,
      );

      if (index >= 0) {
        banners[index] = updatedBanner;
      } else if (updatedBanner.isActive) {
        banners.insert(0, updatedBanner);
      }
      _imageCacheKey++;
    });
  }

  Future<void> _reloadBanners() async {
    if (!mounted) return;

    setState(() {
      currentPage = 1;
      totalPages = 1;
      banners.clear();
      isLoading = false;
      isLoadingMore = false;
      _imageCacheKey++;
    });

    await getBanner(isFirstLoad: true);
  }

  Future<void> getBanner({bool isFirstLoad = false}) async {
    if (isLoading || isLoadingMore) return;

    try {
      if (isFirstLoad) {
        if (mounted) {
          setState(() => isLoading = true);
        }
        Loader.show();
      } else if (mounted) {
        setState(() => isLoadingMore = true);
      }

      final bannerResponse = await BannerService.fetchBannerListResponse(
        page: currentPage,
        isActive: true,
        name: isSearching ? searchKey : null,
      );

      if (bannerResponse != null && mounted) {
        setState(() {
          totalPages = bannerResponse.totalPages;
          currentPage++;

          final activeBanners = BannerListUtil.finalizeFetchedBanners(
            bannerResponse.data.where((b) => b.isActive == true).toList(),
          );

          banners.addAll(activeBanners);
        });
      }
    } catch (e) {
      debugPrint("Banner API error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
      }
      Loader.hide();
    }
  }

  Future<void> searchBanner({
    bool isFirstLoad = false,
    required String key,
  }) async {
    if (isLoading || isLoadingMore) return;

    try {
      if (isFirstLoad) {
        isLoading = true;
        Loader.show();
      } else {
        isLoadingMore = true;
      }

      final response = await HttpClientHelper.getWithBearer(
        "${ApiConstants.allBanners}?page=$currentPage&name=$key",
        AuthDataHelper.getToken(),
      );

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.data);
        final bannerResponse = BannerListResponse.fromJson(jsonBody);

        setState(() {
          totalPages = bannerResponse.totalPages;
          currentPage++;

          banners.addAll(bannerResponse.data);
        });
      }
    } catch (e) {
      debugPrint("Banner pagination error: $e");
    } finally {
      isLoading = false;
      isLoadingMore = false;
      Loader.hide();
    }
  }

  /// ---------------- BANNER CARD ----------------
  Widget _bannerCard(BannerItem banner) {
    return Container(
      key: ValueKey(
        '${banner.bannerId}_${_imageCacheKey}_${banner.updatedAt.millisecondsSinceEpoch}',
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE (16:8)
          AspectRatio(
            aspectRatio: 16 / 8,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child:
                  BannerDisplayImage(
                    bannerId: banner.bannerId,
                    imageUrl: banner.bannerImageUrl,
                    updatedAt: banner.updatedAt,
                    cacheKey: _imageCacheKey,
                    fit: BoxFit.cover,
                  ),
            ),
          ),

          /// TEXT
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        banner.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _statusChip(banner.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  banner.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),

                /// BUTTONS ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    /// EDIT BUTTON
                    TextButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<dynamic>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddBannerScreen(bannerItem: banner),
                          ),
                        );

                        if (result != null) {
                          await _handleBannerChange(result);
                        }
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Edit"),
                    ),

                    const SizedBox(width: 8),

                    /// DELETE BUTTON - Only for Admin
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: () {
                          _showDeleteDialog(banner);
                        },
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- DELETE CONFIRMATION ----------------
  void _showDeleteDialog(BannerItem banner) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Banner"),
            content: const Text("Are you sure you want to delete this banner?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteBanner(banner.bannerId);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteBanner(String bannerId) async {
    if (!(await checkInternetConnection())) {
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    Loader.show();

    try {
      final response = await HttpClientHelper.patchWithMultipart(
        '${ApiConstants.updateBannerById}/${bannerId}',
        AuthDataHelper.getToken(),
        fields: {'isActive': 'false'},
      );

      Loader.hide();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        BannerRefreshController.ensureRegistered().notifyChanged();
        setState(() {
          banners.removeWhere((banner) => banner.bannerId == bannerId);
          _imageCacheKey++;
        });
        showSnackBar(context, response.message ?? "Banner deleted");
      } else {
        showSnackBar(context, response.message ?? "Update failed");
      }
    } catch (e) {
      Loader.hide();
      showSnackBar(context, "Something went wrong: $e");
    }
  }

  /// ---------------- STATUS CHIP ----------------
  Widget _statusChip(String status) {
    Color bgColor;
    Color textColor;
    String displayText = status;

    switch (status.toLowerCase()) {
      case 'approved':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'pending':
        bgColor = AppColors.accentLight;
        textColor = AppColors.main;
        break;
      case 'rejected':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      default:
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
