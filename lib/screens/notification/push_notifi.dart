import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/create_notification_response.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/model/notifications_response.dart';
import 'package:mprs_android/model/template_list_response.dart';
import 'package:mprs_android/screens/notification/add_push_notification.dart';
import 'package:mprs_android/screens/notification/add_template_screen.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/pending_service.dart';
import 'package:mprs_android/service/notification/admin_notification_service.dart';
import 'package:mprs_android/service/notification/notification_template_service.dart';
import 'package:mprs_android/screens/notification/notification_theme.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/search_user_bar.dart';

class PushNotifi extends StatefulWidget {
  const PushNotifi({super.key});

  @override
  _PushNotifiState createState() => _PushNotifiState();
}

class _PushNotifiState extends State<PushNotifi>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<NotificationItem> notificationList = [];
  List<TemplateModel> templateList = [];
  List<TemplateModel> approvedTemplateList = [];
  final searchController = TextEditingController();
  List<NotificationItem> filteredNotificationList = [];
  List<TemplateModel> filteredTemplateList = [];

  int _templatePage = 1;
  int _templateTotalPages = 1;
  bool _isLoadingTemplates = false;
  bool _initialTemplatesLoading = false;

  final ScrollController _templateScrollController = ScrollController();
  int _notificationPage = 1;
  int _notificationTotalPages = 1;
  bool _isLoadingNotifications = false;
  bool _initialNotificationsLoading = false;
  bool _initialSentLoading = false;

  final ScrollController _notificationScrollController = ScrollController();

  // Sent notifications separate state
  List<NotificationItem> sentNotificationList = [];
  List<NotificationItem> filteredSentNotificationList = [];
  int _sentPage = 1;
  int _sentTotalPages = 1;
  bool _isLoadingSent = false;
  final ScrollController _sentScrollController = ScrollController();

  bool isAdmin = AuthDataHelper.isAdminUser();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load the default tab immediately
    getAllTemplates(isFirstLoad: true);
    // Preload notifications but also allow loading on tab switch
    getAllNotifications(isFirstLoad: true);

    // When user switches tabs, trigger initial-load fetch for that tab
    _tabController.addListener(_handleTabChange);

    _templateScrollController.addListener(() {
      if (_templateScrollController.position.pixels >=
              _templateScrollController.position.maxScrollExtent - 150 &&
          !_isLoadingTemplates &&
          _templatePage <= _templateTotalPages) {
        getAllTemplates();
      }
    });

    _notificationScrollController.addListener(() {
      if (_notificationScrollController.position.pixels >=
              _notificationScrollController.position.maxScrollExtent - 150 &&
          !_isLoadingNotifications &&
          _notificationPage <= _notificationTotalPages) {
        getAllNotifications();
      }
    });

    _sentScrollController.addListener(() {
      if (_sentScrollController.position.pixels >=
              _sentScrollController.position.maxScrollExtent - 150 &&
          !_isLoadingSent &&
          _sentPage <= _sentTotalPages) {
        getAllSentNotifications();
      }
    });
  }

  @override
  void dispose() {
    _templateScrollController.dispose();
    _notificationScrollController.dispose();
    _sentScrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    setState(() {
      if (idx == 0) {
        if (templateList.isEmpty && !_isLoadingTemplates) {
          getAllTemplates(isFirstLoad: true);
        }
      } else if (idx == 1) {
        if (notificationList.isEmpty && !_isLoadingNotifications) {
          getAllNotifications(isFirstLoad: true);
        }
      } else if (idx == 2) {
        if (sentNotificationList.isEmpty && !_isLoadingSent) {
          getAllSentNotifications(isFirstLoad: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Notifications",
        actionWidget: Text(
          _tabController.index == 0 ? "Add Template" : "Add Notification",
          style: TextStyle(
            color: AppColors.main,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onActionPressed: () async {
          if (_tabController.index == 0) {
            final bool? isCreated = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddTemplateScreen()),
            );

            if (isCreated == true) {
              getAllTemplates(isFirstLoad: true);
            }
          } else {
            await _openAddPushNotification();
          }
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildTabBar(),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTemplatesList("Templates"),
                    _buildNotificationsList("Notifications"),
                    _buildNotificationsSentList("Notifications Sent"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.main_10,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: TabBar(
        tabAlignment: TabAlignment.start,
        controller: _tabController,
        isScrollable: true,
        padding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: AppColors.main,
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: Colors.black,
        tabs: const [
          SizedBox(width: 90, child: Tab(text: 'Templates')),
          SizedBox(width: 90, child: Tab(text: 'Notifications')),
          SizedBox(width: 140, child: Tab(text: 'Notifications Sent')),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          SearchUserBar(
            hintText: "Search Notification",
            controller: searchController,
            onChanged: (_) => filterNotifications(),
          ),

          const SizedBox(height: 12),

          Expanded(
            child:
                _isLoadingNotifications &&
                        notificationList.isEmpty &&
                        !_initialSentLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notificationList.isEmpty
                    ? const Center(child: Text("No notification found"))
                    : ListView.builder(
                      controller: _notificationScrollController,
                      itemCount:
                          filteredNotificationList.length +
                          (_notificationPage <= _notificationTotalPages
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredNotificationList.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final item = filteredNotificationList[index];

                        return notificationItemRow(
                          notificationItem: item,
                          onEdit: () async {
                            await _openAddPushNotification(item: item);
                          },
                          onDelete: () async {
                            final confirmed = await _showConfirmDialog(
                              "Are you sure you want to delete this notification?",
                            );
                            if (confirmed) {
                              final success = await deleteNotification(item);
                              if (success) {
                                setState(() {
                                  notificationList.removeWhere(
                                    (e) =>
                                        e.notificationId == item.notificationId,
                                  );
                                  filteredNotificationList = List.from(
                                    notificationList,
                                  );
                                });
                              }
                            }
                          },
                          onApprove:
                              () => _approveOrRejectNotification(
                                item,
                                'Approved',
                              ),
                          onReject:
                              () => _approveOrRejectNotification(
                                item,
                                'Rejected',
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveOrRejectTemplate(
    TemplateModel item,
    String status,
  ) async {
    final templateId = item.templateId?.trim() ?? '';
    if (templateId.isEmpty) {
      showSnackBar(context, 'Template id missing');
      return;
    }

    final confirmed = await _showConfirmDialog(
      status == 'Approved' ? 'Approve this template?' : 'Reject this template?',
    );
    if (!confirmed) return;

    ProgressLoader.show(context);
    try {
      final resp = await PendingService.approveTemplate(
        templateId,
        status,
        AuthDataHelper.getToken(),
        '',
      );
      ProgressLoader.hide(context);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        showSnackBar(
          context,
          status == 'Approved' ? 'Template approved' : 'Template rejected',
        );
        await getAllTemplates(isFirstLoad: true);
        await getApprovedTemplates();
      } else {
        showSnackBar(context, resp.message ?? 'Failed to update template');
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error: $e');
    }
  }

  Future<void> _approveOrRejectNotification(
    NotificationItem item,
    String status,
  ) async {
    final action = status == 'Approved' ? 'approve' : 'reject';
    final targets = item.targetUsers?.join(', ') ?? 'users';
    final confirmed = await _showConfirmDialog(
      status == 'Approved'
          ? 'Approve and send this notification to $targets?'
          : 'Reject this notification?',
    );
    if (!confirmed) return;

    ProgressLoader.show(context);
    try {
      final resp = await PendingService.approveNotification(
        item.notificationId,
        status,
        AuthDataHelper.getToken(),
        '',
      );
      ProgressLoader.hide(context);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (status == 'Approved') {
          await AdminNotificationService.dispatchPush(
            messageHeader: item.messageHeader,
            messageBody: item.messageBody,
            notificationId: item.notificationId,
            targetUsers: item.targetUsers ?? const [],
            link: item.link,
          );
        }
        showSnackBar(
          context,
          status == 'Approved'
              ? 'Notification approved and sent to $targets'
              : 'Notification rejected',
        );
        await getAllNotifications(isFirstLoad: true);
        await getAllSentNotifications(isFirstLoad: true);
      } else {
        showSnackBar(context, resp.message ?? 'Failed to $action');
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error: $e');
    }
  }

  Widget _buildTemplatesList(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          SearchUserBar(
            hintText: "Search Template",
            controller: searchController,
            onChanged: (_) => filterNotifications(),
          ),

          const SizedBox(height: 12),

          Expanded(
            child:
                _isLoadingTemplates &&
                        templateList.isEmpty &&
                        !_initialTemplatesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : templateList.isEmpty
                    ? const Center(
                      child: Text("No notification templates found"),
                    )
                    : ListView.builder(
                      controller: _templateScrollController,
                      itemCount:
                          filteredTemplateList.length +
                          (_templatePage <= _templateTotalPages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredTemplateList.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final item = filteredTemplateList[index];

                        return templateItemRow(
                          templateModel: item,
                          onEdit: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        AddTemplateScreen(templateModel: item),
                              ),
                            ).then((_) => getAllTemplates(isFirstLoad: true));
                          },
                          onDelete: () async {
                            final confirmed = await _showConfirmDialog(
                              "Are you sure you want to delete this template?",
                            );
                            if (confirmed) {
                              final success = await deleteTemplate(item);
                              if (success) {
                                setState(() {
                                  templateList.removeWhere(
                                    (e) => e.templateId == item.templateId,
                                  );
                                  filteredTemplateList = List.from(
                                    templateList,
                                  );
                                });
                              }
                            }
                          },
                          onApprove:
                              () => _approveOrRejectTemplate(item, 'Approved'),
                          onReject:
                              () => _approveOrRejectTemplate(item, 'Rejected'),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSentList(String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          SearchUserBar(
            hintText: "Search Notification",
            controller: searchController,
            onChanged: (_) => filterSentNotifications(),
          ),

          const SizedBox(height: 12),

          Expanded(
            child:
                _isLoadingSent &&
                        sentNotificationList.isEmpty &&
                        !_initialSentLoading
                    ? const Center(child: CircularProgressIndicator())
                    : sentNotificationList.isEmpty
                    ? const Center(child: Text("No notification found"))
                    : ListView.builder(
                      controller: _sentScrollController,
                      itemCount:
                          filteredSentNotificationList.length +
                          (_sentPage <= _sentTotalPages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredSentNotificationList.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final item = filteredSentNotificationList[index];
                        return notificationSentCard(notificationItem: item);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget templateItemRow({
    required TemplateModel templateModel,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    var iconPath = 'assets/images/notification_ic.png';

    final bool isApproved = templateModel.isApproved ?? false;
    final String status = (templateModel.status ?? 'pending').toLowerCase();

    final bool isOwner = _sameUser(templateModel.createdBy ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              iconPath,
              width: 24,
              height: 24,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              templateModel.templateName ?? "",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusChip(status),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// 👁️ View details → when user cannot edit
                        if (!isAdmin && !isOwner) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed:
                                () => _showTemplateDetailsModal(templateModel),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        /// ✏️ Edit → owner or admin
                        if (isAdmin || isOwner) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.green,
                              size: 20,
                            ),
                            onPressed: onEdit,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        /// 🗑️ Delete → only admin
                        if (isAdmin) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        /// ✅ Approve/Reject → only admin & pending
                        if (isAdmin && !isApproved && status == 'pending') ...[
                          IconButton(
                            icon: const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 20,
                            ),
                            onPressed: onApprove,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: onReject,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Text(
                  templateModel.body ?? "",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      templateModel.createdByName ?? 'System',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
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

  Widget notificationItemRow({
    required NotificationItem notificationItem,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    var iconPath = 'assets/images/notification_ic.png';

    final bool isActive = notificationItem.isActive ?? true;
    final bool isApproved = notificationItem.isApproved ?? false;
    final String status = notificationItem.status ?? 'pending';

    final bool isOwner = _sameUser(notificationItem.createdBy ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: NotificationTheme.cardDecoration(
        background: isActive ? AppColors.accentLight : Colors.red.shade50,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              iconPath,
              width: 24,
              height: 24,
              color: NotificationTheme.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notificationItem.messageHeader,
                              style: NotificationTheme.titleStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusChip(status),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// 👁️ View details → when user cannot edit
                        if (!isAdmin && !isOwner) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed:
                                () => _showNotificationDetailsModal(
                                  notificationItem,
                                ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        /// ✏️ Edit → owner or admin
                        if (isAdmin || isOwner) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.green,
                              size: 20,
                            ),
                            onPressed: onEdit,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        /// 🗑️ Delete → only admin
                        if (isAdmin) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        /// ✅ Approve/Reject → only admin & pending
                        if (isAdmin && !isApproved && status == 'pending') ...[
                          IconButton(
                            icon: const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 20,
                            ),
                            onPressed: onApprove,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: onReject,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Text(
                  notificationItem.messageBody,
                  style: NotificationTheme.bodyStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 13,
                      color: NotificationTheme.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notificationItem.createdByName ?? 'System',
                      style: NotificationTheme.captionStyle.copyWith(
                        fontWeight: FontWeight.w500,
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

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color color;
    switch (s) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'pending':
      default:
        color = AppColors.main;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget notificationSentCard({required NotificationItem notificationItem}) {
    const iconPath = 'assets/images/notification_ic.png';

    final bool isActive = notificationItem.isActive;

    /// Format date & time from DateTime
    final String date = _formatDate(notificationItem.createdAt);
    final String time = _formatTime(notificationItem.createdAt);
    final String scheduledDateStr = _formatDate(notificationItem.scheduledDate);

    return GestureDetector(
      onTap:
          () => _showNotificationDetailsModal(
            notificationItem,
            isSentNotification: true,
          ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: NotificationTheme.cardDecoration(
          background: isActive ? AppColors.accentLight : Colors.red.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with icon and title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔔 Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    iconPath,
                    width: 24,
                    height: 24,
                    color: NotificationTheme.orange,
                  ),
                ),
                const SizedBox(width: 12),

                /// 📄 Title and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notificationItem.messageHeader,
                        style: NotificationTheme.titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (notificationItem.targetUsers != null &&
                          notificationItem.targetUsers!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'To: ${notificationItem.targetUsers!.join(', ')}',
                            style: NotificationTheme.captionStyle,
                          ),
                        ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  notificationItem.status == 'sent'
                                      ? Colors.green.withOpacity(0.2)
                                      : notificationItem.status == 'pending'
                                      ? AppColors.main.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notificationItem.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    notificationItem.status == 'sent'
                                        ? Colors.green
                                        : notificationItem.status == 'pending'
                                        ? AppColors.main
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// 📄 Message Preview
            Text(
              notificationItem.messageBody,
              style: NotificationTheme.bodyStyle.copyWith(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            /// Info Row: Scheduled Date, Target Count
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_send,
                      size: 13,
                      color: NotificationTheme.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      scheduledDateStr,
                      style: NotificationTheme.captionStyle,
                    ),
                  ],
                ),
                if (notificationItem.targetUsers != null &&
                    notificationItem.targetUsers!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people,
                        size: 13,
                        color: NotificationTheme.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${notificationItem.targetUsers!.join(', ')}',
                        style: NotificationTheme.captionStyle,
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),

            /// Creator and View Details hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 13,
                      color: NotificationTheme.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notificationItem.createdByName ?? 'System',
                      style: NotificationTheme.captionStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tap for details →',
                  style: NotificationTheme.captionStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetailsModal(
    NotificationItem notification, {
    bool isSentNotification = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hero card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.messageHeader,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 20),
                                splashRadius: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notification.messageBody,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _badgeChip(
                                notification.status.toUpperCase(),
                                AppColors.main_10,
                                AppColors.main,
                                icon: Icons.bolt,
                              ),
                              _badgeChip(
                                notification.isActive ? "Active" : "Inactive",
                                notification.isActive
                                    ? Colors.blue.withOpacity(0.14)
                                    : Colors.red.withOpacity(0.14),
                                notification.isActive
                                    ? Colors.blue
                                    : Colors.red,
                                icon: Icons.power_settings_new,
                              ),
                              if (notification.link.isNotEmpty)
                                _badgeChip(
                                  "Link attached",
                                  Colors.purple.withOpacity(0.12),
                                  Colors.purple,
                                  icon: Icons.link,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      "Schedule",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            title: "Date",
                            value: _formatDate(notification.scheduledDate),
                            icon: Icons.event,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoTile(
                            title: "Time",
                            value: _formatTime(notification.scheduledTime),
                            icon: Icons.access_time,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Text(
                      "Metadata",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoTile(
                      title: "Created by",
                      value: notification.createdByName ?? "System",
                      icon: Icons.person,
                    ),

                    if (notification.link.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        "Link",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _infoTile(
                        title: "",
                        value: notification.link,
                        icon: Icons.link,
                      ),
                    ],

                    if (notification.targetUsers != null &&
                        notification.targetUsers!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        "Target Users (${notification.targetUsers!.length})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              notification.targetUsers!.map((user) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.main_10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    user,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.main,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badgeChip(String label, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.main_10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.main),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final dt = dateTime.toLocal();
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.year}";
  }

  String _formatTime(DateTime dateTime) {
    final dt = dateTime.toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<List<TemplateModel>> _templatesForAddScreen() async {
    if (templateList.isNotEmpty) {
      return List<TemplateModel>.from(templateList);
    }

    try {
      final fetched =
          await NotificationTemplateService.fetchSelectableTemplates();
      if (fetched.isNotEmpty) return fetched;
    } catch (e) {
      debugPrint('Error fetching templates for add screen: $e');
    }

    if (approvedTemplateList.isNotEmpty) {
      return List<TemplateModel>.from(approvedTemplateList);
    }

    return const [];
  }

  Future<void> _openAddPushNotification({NotificationItem? item}) async {
    final templates = await _templatesForAddScreen();
    if (!mounted) return;

    final bool? isCreated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddPushNotification(
              templateList: templates,
              notificationItem: item,
            ),
      ),
    );

    if (isCreated == true) {
      getAllNotifications(isFirstLoad: true);
    }
  }

  Future<void> getApprovedTemplates() async {
    try {
      approvedTemplateList =
          await NotificationTemplateService.fetchSelectableTemplates();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error fetching approved templates: $e");
    }
  }

  Future<void> getAllTemplates({bool isFirstLoad = false}) async {
    if (_isLoadingTemplates) return;

    if (isFirstLoad) {
      _templatePage = 1;
      _templateTotalPages = 1;
      templateList.clear();
      filteredTemplateList.clear();
    }

    if (_templatePage > _templateTotalPages) return;

    _isLoadingTemplates = true;

    try {
      if (_templatePage == 1) {
        _initialTemplatesLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Loader.show();
        });
      }

      final result = await NotificationTemplateService.fetchTemplatePage(
        _templatePage,
      );

      if (_templatePage == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Loader.hide();
          _initialTemplatesLoading = false;
        });
      }

      if (result.items.isNotEmpty) {
        setState(() {
          _templateTotalPages = result.totalPages;
          _templatePage = result.currentPage + 1;
          templateList.addAll(result.items);
          filteredTemplateList = List.from(templateList);
        });
      } else if (isFirstLoad && templateList.isEmpty) {
        // Last resort: load full list in one shot (older API without pagination).
        final all = await NotificationTemplateService.fetchAllTemplates();
        if (all.isNotEmpty && mounted) {
          setState(() {
            templateList = all;
            filteredTemplateList = List.from(all);
            _templateTotalPages = 1;
            _templatePage = 2;
          });
        }
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Loader.hide();
      });
      debugPrint("Template pagination error: $e");
    } finally {
      _isLoadingTemplates = false;
    }
  }

  Future<bool> deleteTemplate(TemplateModel templateModel) async {
    ProgressLoader.show(context);
    try {
      final response = await HttpClientHelper.patchWithBearer(
        '${ApiConstants.updateNotificationTemplate}/${templateModel.templateId}',
        AuthDataHelper.getToken(),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"isActive": false}),
      );
      ProgressLoader.hide(context);
      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnackBar(
          context,
          response.message ?? "Template Deleted Successfully!",
        );
        return true;
      } else {
        showSnackBar(context, "Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, "Error: $e");
      return false;
    }
  }

  Future<void> getAllNotifications({
    bool isFirstLoad = false,
    bool isForSent = false,
  }) async {
    if (_isLoadingNotifications) return;

    if (isFirstLoad) {
      _notificationPage = 1;
      _notificationTotalPages = 1;
      notificationList.clear();
      filteredNotificationList.clear();
    }

    if (_notificationPage > _notificationTotalPages) return;

    _isLoadingNotifications = true;

    try {
      if (_notificationPage == 1) {
        _initialNotificationsLoading = true;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          Loader.show();
          try {
            final response = await HttpClientHelper.getWithBearer(
              "${ApiConstants.getAllNotifications}?page=$_notificationPage&isActive=true",
              AuthDataHelper.getToken(),
            );

            debugPrint("Notification pagination response: ${response.data}");
            if (response.statusCode == 200) {
              final jsonBody = jsonDecode(response.data);
              final notificationsResponse = NotificationsResponse.fromJson(
                jsonBody,
              );

              setState(() {
                _notificationTotalPages = notificationsResponse.totalPages ?? 1;
                _notificationPage =
                    (notificationsResponse.currentPage ?? 1) + 1;

                final activeNotifications =
                    (notificationsResponse.data ?? [])
                        .where((item) => item.isActive == true)
                        .toList();

                notificationList.addAll(activeNotifications);
                filteredNotificationList = List.from(notificationList);
              });
            }
          } catch (e) {
            debugPrint("Notification pagination error: $e");
          } finally {
            Loader.hide();
            _initialNotificationsLoading = false;
            _isLoadingNotifications = false;
          }
        });
      } else {
        final response = await HttpClientHelper.getWithBearer(
          "${ApiConstants.getAllNotifications}?page=$_notificationPage&isActive=true",
          AuthDataHelper.getToken(),
        );

        if (response.statusCode == 200) {
          final jsonBody = jsonDecode(response.data);
          final notificationsResponse = NotificationsResponse.fromJson(
            jsonBody,
          );

          setState(() {
            _notificationTotalPages = notificationsResponse.totalPages ?? 1;
            _notificationPage = (notificationsResponse.currentPage ?? 1) + 1;

            final activeNotifications =
                (notificationsResponse.data ?? [])
                    .where((item) => item.isActive == true)
                    .toList();

            notificationList.addAll(activeNotifications);
            filteredNotificationList = List.from(notificationList);
          });
        }
      }
    } catch (e) {
      debugPrint("Notification pagination error: $e");
      _isLoadingNotifications = false;
    }
  }

  Future<void> getAllSentNotifications({bool isFirstLoad = false}) async {
    if (_isLoadingSent) return;

    if (isFirstLoad) {
      _sentPage = 1;
      _sentTotalPages = 1;
      sentNotificationList.clear();
      filteredSentNotificationList.clear();
    }

    if (_sentPage > _sentTotalPages) return;

    _isLoadingSent = true;

    try {
      if (_sentPage == 1) {
        _initialSentLoading = true;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          Loader.show();
          try {
            final response = await HttpClientHelper.getWithBearer(
              "${ApiConstants.getAllNotifications}?page=$_sentPage&isActive=true",
              AuthDataHelper.getToken(),
            );

            debugPrint(
              "Sent notification pagination response: ${response.data}",
            );
            if (response.statusCode == 200) {
              final jsonBody = jsonDecode(response.data);
              final notificationsResponse = NotificationsResponse.fromJson(
                jsonBody,
              );

              setState(() {
                _sentTotalPages = notificationsResponse.totalPages ?? 1;
                _sentPage = (notificationsResponse.currentPage ?? 1) + 1;

                final activeNotifications =
                    (notificationsResponse.data ?? [])
                        .where((item) => item.isActive == true)
                        .toList();

                sentNotificationList.addAll(activeNotifications);
                filteredSentNotificationList = List.from(sentNotificationList);
              });
            }
          } catch (e) {
            debugPrint("Sent notification pagination error: $e");
          } finally {
            Loader.hide();
            _initialSentLoading = false;
            _isLoadingSent = false;
          }
        });
      } else {
        final response = await HttpClientHelper.getWithBearer(
          "${ApiConstants.getAllNotifications}?page=$_sentPage&isActive=true",
          AuthDataHelper.getToken(),
        );

        if (response.statusCode == 200) {
          final jsonBody = jsonDecode(response.data);
          final notificationsResponse = NotificationsResponse.fromJson(
            jsonBody,
          );

          setState(() {
            _sentTotalPages = notificationsResponse.totalPages ?? 1;
            _sentPage = (notificationsResponse.currentPage ?? 1) + 1;

            final activeNotifications =
                (notificationsResponse.data ?? [])
                    .where((item) => item.isActive == true)
                    .toList();

            sentNotificationList.addAll(activeNotifications);
            filteredSentNotificationList = List.from(sentNotificationList);
          });
        }
      }
    } catch (e) {
      debugPrint("Sent notification pagination error: $e");
      _isLoadingSent = false;
    }
  }

  Future<bool> deleteNotification(NotificationItem notificationItem) async {
    ProgressLoader.show(context);

    try {
      var apiResponse = await HttpClientHelper.patchWithBearer(
        '${ApiConstants.updateNotification}/${notificationItem.notificationId}',
        AuthDataHelper.getToken(),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"isActive": false}),
      );

      ProgressLoader.hide(context);

      if (apiResponse.statusCode == 200 || apiResponse.statusCode == 201) {
        final parsed = CreateNotificationResponse.fromJson(
          jsonDecode(apiResponse.data),
        );
        showSnackBar(context, "Notification Deleted Successfully!");
        return true;
      } else {
        showSnackBar(context, "Error: ${apiResponse.statusCode}");
        return false;
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error: $e');
      return false;
    }
  }

  Future<bool> _showConfirmDialog(String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    return res == true;
  }

  void filterNotifications() {
    final query = searchController.text.toLowerCase();

    setState(() {
      if (_tabController.index == 0) {
        // Templates tab
        filteredTemplateList =
            templateList.where((item) {
              return (item.templateName ?? '').toLowerCase().contains(query) ||
                  (item.templateHeader ?? '').toLowerCase().contains(query) ||
                  (item.templateType ?? '').toLowerCase().contains(query) ||
                  (item.body ?? '').toLowerCase().contains(query);
            }).toList();
      } else if (_tabController.index == 1) {
        // Notifications tab
        filteredNotificationList =
            notificationList.where((item) {
              return (item.messageHeader ?? "").toLowerCase().contains(query) ||
                  (item.messageBody ?? "").toLowerCase().contains(query);
            }).toList();
      }
    });
  }

  void filterSentNotifications() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredSentNotificationList =
          sentNotificationList.where((item) {
            return (item.messageHeader ?? "").toLowerCase().contains(query) ||
                (item.messageBody ?? "").toLowerCase().contains(query);
          }).toList();
    });
  }

  bool _sameUser(String createdByUserID) {
    final String? userId = AuthDataHelper.getId();
    if (userId == null) return false;
    return userId == createdByUserID;
  }

  void _showTemplateDetailsModal(TemplateModel template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hero card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  template.templateName ?? "Template",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 20),
                                splashRadius: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _badgeChip(
                            (template.status ?? 'pending').toUpperCase(),
                            AppColors.main_10,
                            AppColors.main,
                            icon: Icons.bolt,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      "Template Details",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoTile(
                      title: "Template Type",
                      value: template.templateType ?? "N/A",
                      icon: Icons.category,
                    ),
                    if (template.templateHeader != null &&
                        template.templateHeader!.isNotEmpty)
                      _infoTile(
                        title: "Template Header",
                        value: template.templateHeader!,
                        icon: Icons.title,
                      ),
                    _infoTile(
                      title: "Template Body",
                      value: template.body ?? "N/A",
                      icon: Icons.description,
                    ),
                    _infoTile(
                      title: "Created By",
                      value: template.createdByName ?? "System",
                      icon: Icons.person,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
