import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/model/all_users_response.dart';
import 'package:mprs_android/screens/user/add_user_screen.dart';
import 'package:mprs_android/screens/user/user_cache.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/search_user_bar.dart';
import 'package:mprs_android/screens/user/tabs/user_list_tab.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
    // Map tab names to backend userType values
    static const Map<String, String> userRoleApiMap = {
      "All": "",
      "Admin": "Admin",
      "Internal": "Internal",
      "External": "External",
      "VIP": "VIP",
      "VVIP": "VVIP",
      "Deleted Users": "",
    };
  final TextEditingController searchController = TextEditingController();

  static const List<String> userRoles = [
    "All",
    "Admin",
    "Internal",
    "External",
    "VIP",
    "VVIP",
    "Deleted Users",
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: userRoles.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CommonAppBar(
          title: "User Management",
          actionWidget: Text(
            "Add New",
            style: TextStyle(
              color: AppColors.main,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onActionPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddUserScreen()),
            );

            if (result == true) {
              for (final role in userRoles) {
                UserCache.setPage(role, 1);
                UserCache.setTotalPages(role, 1);
                UserCache.clearUsers(role);
              }
              await _loadDefaultUsers();
            }
          },
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchUserBar(
                hintText: "Search user",
                controller: searchController,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 12),

              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: (_) => searchController.clear(),
                padding: const EdgeInsets.symmetric(horizontal: 0),
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                tabs: List.generate(userRoles.length, (index) {
                  return Tab(
                    child: _PillTab(text: userRoles[index], index: index),
                  );
                }),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  children: [
                    for (final role in userRoles)
                      UserListTab(
                        userType: role,
                        search: searchController,
                        onRefresh: () => _refreshUsers(userType: role),
                        onLoadMore: () => _loadMoreUsers(userType: role),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDefaultUsers();
  }

  Future<void> _loadDefaultUsers({String? userType, bool loadMore = false}) async {
    final type = userType ?? "All";
    if (UserCache.getIsLoading(type)) return;
    if (loadMore && UserCache.getPage(type) >= UserCache.getTotalPages(type)) return;

    UserCache.setIsLoading(type, true);
    final nextPage = loadMore ? UserCache.getPage(type) + 1 : 1;

    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Loader.show();
      });
      // Use mapped userType for API
      String url = "${ApiConstants.allUsers}?page=$nextPage";
      final apiUserType = userRoleApiMap[type] ?? "";
      if (apiUserType.isNotEmpty && type != "Deleted Users") {
        url += "&userType=$apiUserType";
      }
      if (type == "Deleted Users") {
        url += "&isActive=false";
      }
      debugPrint("[UserManagement] Fetching users for tab: $type");
      debugPrint("[UserManagement] API URL: $url");
      final response = await HttpClientHelper.getWithBearer(
        url,
        AuthDataHelper.getToken(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Loader.hide();
      });

      if (response.statusCode == 200) {
        debugPrint("[UserManagement] API response for $type: ${response.data}");
        final data = AllUsersResponse.fromJson(jsonDecode(response.data));
        if (!loadMore) UserCache.clearUsers(type);
        final merged = [...UserCache.getUsers(type), ...data.data];
        merged.sort((a, b) {
          final nameA =
              '${a.firstName ?? ''} ${a.lastName ?? ''}'.trim().toLowerCase();
          final nameB =
              '${b.firstName ?? ''} ${b.lastName ?? ''}'.trim().toLowerCase();
          return nameA.compareTo(nameB);
        });
        UserCache.setUsers(type, merged);
        UserCache.setPage(type, data.page);
        UserCache.setTotalPages(type, data.totalPages);
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Loader.hide();
      });
      debugPrint("Default API error: $e");
    }

    UserCache.setIsLoading(type, false);
    setState(() {});
  }

  Future<void> _refreshUsers({String? userType}) async {
    final type = userType ?? "All";
    UserCache.setPage(type, 1);
    UserCache.setTotalPages(type, 1);
    UserCache.clearUsers(type);
    await _loadDefaultUsers(userType: type);
  }

  Future<void> _loadMoreUsers({String? userType}) async {
    await _loadDefaultUsers(userType: userType, loadMore: true);
  }
}

class _PillTab extends StatefulWidget {
  final String text;
  final int index;

  const _PillTab({required this.text, required this.index});

  @override
  State<_PillTab> createState() => _PillTabState();
}

class _PillTabState extends State<_PillTab> {
  late TabController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = DefaultTabController.of(context);
    _controller.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelected = _controller.index == widget.index;

    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected ? Colors.red.withOpacity(0.15) : const Color(0xFFEAF1FB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        widget.text,
        style: TextStyle(
          color: isSelected ? Colors.red : Colors.blue,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
