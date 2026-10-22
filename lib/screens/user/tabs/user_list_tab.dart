import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/common_data.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/model/add_user_response.dart';
import 'package:mprs_android/model/all_users_response.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/screens/user/edit_user_screen.dart';
import 'package:mprs_android/screens/user/user_cache.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';

class UserListTab extends StatefulWidget {
  final String userType;
  final TextEditingController search;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;

  const UserListTab({
    super.key,
    required this.userType,
    required this.search,
    this.onRefresh,
    this.onLoadMore,
  });

  @override
  State<UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends State<UserListTab> {
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool isSearchMode = false;

  int searchPage = 1;
  int searchTotalPages = 1;

  ValueNotifier<List<UserData>> get userListNotifier => UserCache.getNotifier(widget.userType);

  List<UserData> get displayList => userListNotifier.value;


  @override
  void initState() {
    debugPrint('[UserListTab] initState for userType: \'${widget.userType}\'');
    super.initState();
    applyLocalFilter();
    widget.search.addListener(_onTyping);

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.search.removeListener(_onTyping);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabSelected() {
    final controller = DefaultTabController.of(context);

    controller.addListener(() {
      if (!controller.indexIsChanging && widget.userType == "Deleted Users") {
        fetchDeletedUsers();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always refresh data when returning to this tab
    if (widget.onRefresh != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRefresh!();
      });
    }
  }

  // ───────────────────────── LOCAL FILTER (ACTIVE USERS) ─────────────────────────

  /// Case-insensitive sort by full name (firstName + lastName).
  static void _sortByName(List<UserData> list) {
    list.sort((a, b) {
      final nameA =
          '${a.firstName ?? ''} ${a.lastName ?? ''}'.trim().toLowerCase();
      final nameB =
          '${b.firstName ?? ''} ${b.lastName ?? ''}'.trim().toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  void applyLocalFilter() {
    if (widget.userType == "Deleted Users") return;

    final keyword = widget.search.text.trim().toLowerCase();

    List<UserData> list = List.of(UserCache.getUsers(widget.userType));

    if (widget.userType != "All") {
      list = list.where((u) => u.userType == widget.userType).toList();
    }

    if (keyword.isNotEmpty) {
      list = list.where((u) {
        final name = "${u.firstName ?? ''} ${u.lastName ?? ''}".toLowerCase();
        return name.contains(keyword);
      }).toList();
    }

    _sortByName(list);

    setState(() {
      UserCache.setUsers(widget.userType, list);
    });
  }

  void _onTyping() {
    if (isSearchMode) return; // ignore typing during remote search
    applyLocalFilter();
  }

  // ───────────────────────── SEARCH API ─────────────────────────

  Future<void> searchUsers({bool loadMore = false}) async {
    final keyword = widget.search.text.trim();
    if (keyword.isEmpty) return;
    if (loadMore && searchPage >= searchTotalPages) return;

    setState(() => isLoading = true);

    final nextPage = loadMore ? searchPage + 1 : 1;

    try {
      final response = await HttpClientHelper.getWithBearer(
        "${ApiConstants.allUsers}?page=$nextPage&keyword=$keyword&userType=${widget.userType}",
        AuthDataHelper.getToken(),
      );

      if (response.statusCode == 200) {
        final data = AllUsersResponse.fromJson(jsonDecode(response.data));
        List<UserData> list = data.data.where((u) => u.isActive != false).toList();
        if (!loadMore) UserCache.clearUsers(widget.userType);
        final merged = [...UserCache.getUsers(widget.userType), ...list];
        _sortByName(merged);
        UserCache.setUsers(widget.userType, merged);
        searchPage = data.page;
        searchTotalPages = data.totalPages;
        isSearchMode = true;
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }

    setState(() => isLoading = false);
  }

  // ───────────────────────── DELETED USERS FETCH ─────────────────────────

  Future<void> fetchDeletedUsers({bool loadMore = false}) async {
    if (isLoading) return;
    int deletedPage = UserCache.getPage(widget.userType);
    int deletedTotalPages = UserCache.getTotalPages(widget.userType);
    if (loadMore && deletedPage >= deletedTotalPages) return;

    setState(() => isLoading = true);

    final nextPage = loadMore ? deletedPage + 1 : 1;

    try {
      final response = await HttpClientHelper.getWithBearer(
        "${ApiConstants.allUsers}?isActive=false&page=$nextPage&userType=${widget.userType}",
        AuthDataHelper.getToken(),
      );

      if (response.statusCode == 200) {
        final data = AllUsersResponse.fromJson(jsonDecode(response.data));
        if (!loadMore) UserCache.clearUsers(widget.userType);
        final merged = [...UserCache.getUsers(widget.userType), ...data.data];
        _sortByName(merged);
        UserCache.setUsers(widget.userType, merged);
        UserCache.setPage(widget.userType, data.page);
        UserCache.setTotalPages(widget.userType, data.totalPages);
      }
    } catch (e) {
      debugPrint("Deleted users error: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ───────────────────────── DELETED SEARCH API ─────────────────────────

  Future<void> searchDeletedUsers({bool loadMore = false}) async {
    final keyword = widget.search.text.trim();
    if (keyword.isEmpty) return;
    if (loadMore && searchPage >= searchTotalPages) return;

    setState(() => isLoading = true);

    final nextPage = loadMore ? searchPage + 1 : 1;

    try {
      final response = await HttpClientHelper.getWithBearer(
        "${ApiConstants.allUsers}?isActive=false&page=$nextPage&keyword=$keyword",
        AuthDataHelper.getToken(),
      );

      if (response.statusCode == 200) {
        final data = AllUsersResponse.fromJson(jsonDecode(response.data));

        List<UserData> list = data.data;

        // Apply tab filter
        if (widget.userType != "All") {
          list = list.where((u) => u.userType == widget.userType).toList();
        }

        _sortByName(list);

        if (!loadMore) displayList.clear();
        displayList.addAll(list);

        searchPage = data.page;
        searchTotalPages = data.totalPages;
        isSearchMode = true;
      }
    } catch (e) {
      debugPrint("Search API error: $e");
    }

    setState(() => isLoading = false);
  }

  // ───────────────────────── SCROLL PAGINATION ─────────────────────────

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 120)
      return;

    if (isLoading) return;

    if (widget.userType == "Deleted Users") {
      if (isSearchMode) {
        searchDeletedUsers(loadMore: true);
      } else {
        fetchDeletedUsers(loadMore: true);
      }
    } else if (isSearchMode) {
      searchUsers(loadMore: true);
    } else {
      // Load more active users from parent
      if (widget.onLoadMore != null) {
        widget.onLoadMore!();
      }
    }
  }

  // ───────────────────────── TAB CHANGE ─────────────────────────

  @override
  void didUpdateWidget(covariant UserListTab oldWidget) {
    debugPrint('[UserListTab] didUpdateWidget: old userType: \'${oldWidget.userType}\', new userType: \'${widget.userType}\'');
    super.didUpdateWidget(oldWidget);
    if (isSearchMode) {
      _resetSearch();
    } else {
      applyLocalFilter();
    }
  }

  void _resetSearch() {
    isSearchMode = false;
    searchPage = 1;
    applyLocalFilter();
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UserData>>(
      valueListenable: userListNotifier,
      builder: (context, displayList, _) {
        debugPrint('[UserListTab] userType: ${widget.userType}, displayList.length: ${displayList.length}');


        if (isLoading && displayList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (displayList.isEmpty) {
          // Allow pull-to-refresh even when empty
          return RefreshIndicator(
            onRefresh: () async {
              if (widget.onRefresh != null) {
                await widget.onRefresh!();
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(color: AppColors.lightGrey),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (widget.onRefresh != null) {
              await widget.onRefresh!();
            }
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayList.length,
            itemBuilder: (_, index) {
              final user = displayList[index];
              return GestureDetector(
                onTap: widget.userType == "Deleted Users"
                    ? () {
                        _showUserDetailsModal(user);
                      }
                    : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.main.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: buildUserAvatar(user),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${user.firstName ?? ''} ${user.lastName ?? ''}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.userType ?? "",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.lightGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.userType != "Deleted Users")
                        Row(
                          children: [
                            IconButton(
                              icon: Image.asset(
                                'assets/images/edit.png',
                                width: 16,
                                height: 16,
                              ),
                              onPressed: () async {
                                // Open EditUserScreen with the selected user
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditUserScreen(user: user),
                                  ),
                                );
                                // Optionally refresh after editing
                                if (result == true && widget.onRefresh != null) {
                                  await widget.onRefresh!();
                                }
                              },
                            ),
                            IconButton(
                              icon: Image.asset(
                                'assets/images/delete.png',
                                width: 16,
                                height: 16,
                              ),
                              onPressed: () async {
                                CommonDialog.showByType(
                                  context,
                                  type: DialogType.confirm,
                                  title: "Delete User",
                                  message: "Are you sure you want to delete ${user.firstName} ${user.lastName}?",
                                  onConfirm: () {
                                    deleteUser(user);
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> deleteUser(UserData myUser) async {
    showSnackBar(context, "Deleting user...");
    Loader.show();
    final response = await HttpClientHelper.patchWithMultipart(
      '${ApiConstants.updateUser}/${myUser.userId}',
      AuthDataHelper.getToken(),
      fields: {'isActive': "false"},
    );
    Loader.hide();
    final decoded = jsonDecode(response.data);
    final userData = AddUserResponse.fromJson(decoded);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Remove from the correct userType cache
      final users = UserCache.getUsers(widget.userType).where((u) => u.userId != myUser.userId).toList();
      UserCache.setUsers(widget.userType, users);
      if (widget.userType == "Deleted Users") {
        await fetchDeletedUsers();
      } else {
        if (widget.onRefresh != null) {
          await widget.onRefresh!();
        }
      }
      showSnackBar(context, "User deleted successfully");
    } else {
      showSnackBar(context, "Error: ${userData.message}");
    }
  }

  Future<void> reactivateUser(UserData myUser) async {
    showSnackBar(context, "Reactivating user...");
    Loader.show();
    final response = await HttpClientHelper.patchWithMultipart(
      '${ApiConstants.updateUser}/${myUser.userId}',
      AuthDataHelper.getToken(),
      fields: {'isActive': "true"},
    );
    Loader.hide();
    final decoded = jsonDecode(response.data);
    final userData = AddUserResponse.fromJson(decoded);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final users = UserCache.getUsers(widget.userType).where((u) => u.userId != myUser.userId).toList();
      UserCache.setUsers(widget.userType, users);
      showSnackBar(context, "User reactivated successfully");
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    } else {
      showSnackBar(context, "Error: ${userData.message}");
    }
  }

  void _showUserDetailsModal(UserData user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "User Details",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Profile image and name
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.main.withOpacity(0.1),
                            child: buildUserAvatar(user),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${user.firstName ?? ''} ${user.lastName ?? ''}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.userType ?? "",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.lightGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // User information section
                    Text(
                      "Contact Information",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow("Email", user.email ?? "N/A"),
                    _buildDetailRow("Mobile", user.mobile ?? "N/A"),
                    _buildDetailRow(
                      "Alternate Email",
                      user.alternateEmail ?? "N/A",
                    ),
                    _buildDetailRow(
                      "Alternate Mobile",
                      user.alternateMobile ?? "N/A",
                    ),

                    const SizedBox(height: 20),

                    Text(
                      "Professional Information",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow("Company", user.companyName ?? "N/A"),
                    _buildDetailRow("Designation", user.designation ?? "N/A"),
                    _buildDetailRow("Department", user.department ?? "N/A"),

                    const SizedBox(height: 20),

                    Text(
                      "Location Information",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow("Address", user.address ?? "N/A"),
                    _buildDetailRow("Country", user.country ?? "N/A"),
                    _buildDetailRow("Region", user.region ?? "N/A"),

                    const SizedBox(height: 20),

                    Text(
                      "Other Information",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow(
                      "Landline Number",
                      user.landlineNumber ?? "N/A",
                    ),
                    _buildDetailRow("Extension", user.extentionNumber ?? "N/A"),
                    _buildDetailRow("GSTIN", user.gstin ?? "N/A"),

                    const SizedBox(height: 24),

                    // Reactivate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          CommonDialog.showByType(
                            context,
                            type: DialogType.confirm,
                            title: "Reactivate User",
                            message:
                                "Are you sure you want to reactivate ${user.firstName} ${user.lastName}?",
                            onConfirm: () {
                              reactivateUser(user);
                            },
                          );
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text("Reactivate User"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.lightGrey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUserAvatar(UserData user) {
    if (user.profileImageUrl != null &&
        user.profileImageUrl!.isNotEmpty &&
        user.profileImageUrl!.startsWith("http")) {
      return CircleAvatar(
        backgroundImage: NetworkImage(user.profileImageUrl!),
        radius: 16,
      );
    } else {
      return CircleAvatar(
        radius: 16,
        child: Icon(Icons.person, color: AppColors.main),
      );
    }
  }
}
