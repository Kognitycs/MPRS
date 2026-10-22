import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/model/pending_approval_item.dart';
import 'package:mprs_android/service/pending_service.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/api_response.dart';

class PendingApprovals extends StatefulWidget {
  final String? approvalId;
  final String? approvalType;

  const PendingApprovals({Key? key, this.approvalId, this.approvalType})
    : super(key: key);

  @override
  State<PendingApprovals> createState() => _PendingApprovalsState();
}

class _PendingApprovalsState extends State<PendingApprovals> {
  List<PendingApprovalItem> pendingList = [];
  bool _isLoading = false;
  String? _error;
  bool _hasOpenedDetail = false;
  int _actionsTaken = 0;

  // Filter state - 'All' means show all types
  String selectedFilter = 'All';

  // Date filter state
  DateTime? fromDate;
  DateTime? toDate;

  final ScrollController _scrollController = ScrollController();
  int _notificationPage = 1;
  int _templatePage = 1;
  int _bannerPage = 1;
  int _profilePage = 1;
  int _notificationTotalPages = 1;
  int _templateTotalPages = 1;
  int _bannerTotalPages = 1;
  int _profileTotalPages = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadPending();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore) {
        _loadMorePending();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _notificationPage = 1;
      _templatePage = 1;
      _bannerPage = 1;
      _profilePage = 1;
      pendingList.clear();
    });

    try {
      final token = AuthDataHelper.getToken();
      final authToken = token.isNotEmpty ? token : null;

      // Fetch notifications, templates and banners and merge them
      final notificationResult = await PendingService.fetchPendingApprovals(
        token: authToken,
        type: PendingType.notification,
        page: _notificationPage,
        fromDate: fromDate,
        toDate: toDate,
      );
      final templateResult = await PendingService.fetchPendingApprovals(
        token: authToken,
        type: PendingType.template,
        page: _templatePage,
        fromDate: fromDate,
        toDate: toDate,
      );
      final bannerResult = await PendingService.fetchPendingApprovals(
        token: authToken,
        type: PendingType.banner,
        page: _bannerPage,
        fromDate: fromDate,
        toDate: toDate,
      );
      final profileResult = await PendingService.fetchPendingApprovals(
        token: authToken,
        type: PendingType.profileEditRequest,
        page: _profilePage,
        fromDate: fromDate,
        toDate: toDate,
      );

      final notifications =
          notificationResult['items'] as List<PendingApprovalItem>;
      final templates = templateResult['items'] as List<PendingApprovalItem>;
      final banners = bannerResult['items'] as List<PendingApprovalItem>;
      final profiles = profileResult['items'] as List<PendingApprovalItem>;

      // Debug logging for profile edit requests
      debugPrint('📱 Profile Edit Requests: ${profiles.length}');
      for (var profile in profiles) {
        debugPrint(
          '  Profile: id=${profile.id}, mobile=${profile.mobile}, name=${profile.firstName} ${profile.lastName}',
        );
      }

      final combined = [
        ...notifications,
        ...templates,
        ...banners,
        ...profiles,
      ];
          debugPrint('🟠 Template items fetched: ${templates.length}');
          for (var t in templates) {
            debugPrint('  Template: id=${t.id}, name=${t.templateName}, type=${t.templateType}, status=${t.status}');
          }
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('📊 Combined list total: ${combined.length}');
      debugPrint(
        '   Notifications: ${notifications.length}, Templates: ${templates.length}, Banners: ${banners.length}, Profiles: ${profiles.length}',
      );

      setState(() {
        pendingList = combined;
        _notificationTotalPages = notificationResult['totalPages'] ?? 1;
        _templateTotalPages = templateResult['totalPages'] ?? 1;
        _bannerTotalPages = bannerResult['totalPages'] ?? 1;
        _profileTotalPages = profileResult['totalPages'] ?? 1;
        _notificationPage++;
        _templatePage++;
        _bannerPage++;
        _profilePage++;
      });

      // Auto-open detail if navigated from notification
      if (widget.approvalId != null && !_hasOpenedDetail) {
        _openDetailFromNotification();
          // Log filteredPendingList for Template filter
          final templateFiltered = combined.where((item) => item.type == PendingType.template).toList();
          debugPrint('🟢 Filtered Template items for UI: ${templateFiltered.length}');
          for (var t in templateFiltered) {
            debugPrint('  UI Template: id=${t.id}, name=${t.templateName}, type=${t.templateType}, status=${t.status}');
          }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePending() async {
    if (_isLoadingMore) return;

    // Check if all types have reached their last page
    final bool allDone =
        _notificationPage > _notificationTotalPages &&
        _templatePage > _templateTotalPages &&
        _bannerPage > _bannerTotalPages &&
        _profilePage > _profileTotalPages;

    if (allDone) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final token = AuthDataHelper.getToken();
      final authToken = token.isNotEmpty ? token : null;

      final List<PendingApprovalItem> newItems = [];

      // Fetch next page for notifications if available
      if (_notificationPage <= _notificationTotalPages) {
        final result = await PendingService.fetchPendingApprovals(
          token: authToken,
          type: PendingType.notification,
          page: _notificationPage,
          fromDate: fromDate,
          toDate: toDate,
        );
        final items = result['items'] as List<PendingApprovalItem>;
        newItems.addAll(items);
        _notificationTotalPages = result['totalPages'] ?? 1;
        _notificationPage++;
      }

      // Fetch next page for templates if available
      if (_templatePage <= _templateTotalPages) {
        final result = await PendingService.fetchPendingApprovals(
          token: authToken,
          type: PendingType.template,
          page: _templatePage,
          fromDate: fromDate,
          toDate: toDate,
        );
        final items = result['items'] as List<PendingApprovalItem>;
        newItems.addAll(items);
        _templateTotalPages = result['totalPages'] ?? 1;
        _templatePage++;
      }

      // Fetch next page for banners if available
      if (_bannerPage <= _bannerTotalPages) {
        final result = await PendingService.fetchPendingApprovals(
          token: authToken,
          type: PendingType.banner,
          page: _bannerPage,
          fromDate: fromDate,
          toDate: toDate,
        );
        final items = result['items'] as List<PendingApprovalItem>;
        newItems.addAll(items);
        _bannerTotalPages = result['totalPages'] ?? 1;
        _bannerPage++;
      }

      // Fetch next page for profile edit requests if available
      if (_profilePage <= _profileTotalPages) {
        final result = await PendingService.fetchPendingApprovals(
          token: authToken,
          type: PendingType.profileEditRequest,
          page: _profilePage,
          fromDate: fromDate,
          toDate: toDate,
        );
        final items = result['items'] as List<PendingApprovalItem>;
        newItems.addAll(items);
        _profileTotalPages = result['totalPages'] ?? 1;
        _profilePage++;
      }

      if (newItems.isNotEmpty) {
        newItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() {
          pendingList.addAll(newItems);
        });
      }
    } catch (e) {
      // Silently fail for load more
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_actionsTaken > 0);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Pending Approvals",
        onActionPressed: () {},
        onBack: () => Navigator.of(context).pop(_actionsTaken > 0),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Error: ${_error ?? ""}'))
              : Column(
                children: [
                  // Filters Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        // Date Range
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerField(
                                label: 'From',
                                date: fromDate,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: fromDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      fromDate = picked;
                                    });
                                    _loadPending();
                                  }
                                },
                                onClear:
                                    fromDate != null
                                        ? () {
                                          setState(() {
                                            fromDate = null;
                                          });
                                          _loadPending();
                                        }
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDatePickerField(
                                label: 'To',
                                date: toDate,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: toDate ?? DateTime.now(),
                                    firstDate: fromDate ?? DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      toDate = picked;
                                    });
                                    _loadPending();
                                  }
                                },
                                onClear:
                                    toDate != null
                                        ? () {
                                          setState(() {
                                            toDate = null;
                                          });
                                          _loadPending();
                                        }
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Type Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedFilter,
                              isExpanded: true,
                              hint: const Text('Select Type'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All Types'),
                                ),
                                DropdownMenuItem(
                                  value: 'Notification',
                                  child: Text('Notification'),
                                ),
                                DropdownMenuItem(
                                  value: 'Template',
                                  child: Text('Template'),
                                ),
                                DropdownMenuItem(
                                  value: 'Banner',
                                  child: Text('Banner'),
                                ),
                                DropdownMenuItem(
                                  value: 'Profile Edit',
                                  child: Text('Profile Edit'),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedFilter = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List view
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(15),
                      itemCount:
                          filteredPendingList.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredPendingList.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final item = filteredPendingList[index];
                        return InkWell(
                          onTap: () => _showPendingDetails(item),
                          child: _pendingApprovalCard(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ), // Scaffold
    ); // PopScope
  }

  /// ---------- Card UI ----------
  Widget _pendingApprovalCard(PendingApprovalItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),

      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadingIcon(item.type),
          const SizedBox(width: 12),

          /// Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title + Actions
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    /// Approve
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _onApprove(item),
                    ),

                    /// Reject
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _onReject(item),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                /// Description
                Text(
                  item.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                /// Type + Date
                Row(
                  children: [
                    _typeChip(item.type),
                    const Spacer(),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

  /// ---------- Helpers ----------
  Widget _leadingIcon(PendingType type) {
    switch (type) {
      case PendingType.notification:
        return const Icon(Icons.notifications, color: Colors.blue);
      case PendingType.template:
        return const Icon(Icons.description, color: AppColors.main);
      case PendingType.user:
        return const Icon(Icons.person, color: Colors.purple);
      case PendingType.banner:
        return const Icon(Icons.image, color: Colors.green);
      case PendingType.profileEditRequest:
        return const Icon(Icons.person_outline, color: Colors.teal);
    }
  }

  Widget _typeChip(PendingType type) {
    String text;
    Color color;

    switch (type) {
      case PendingType.notification:
        text = 'Notification';
        color = Colors.blue;
        break;
      case PendingType.template:
        text = 'Template';
        color = AppColors.main;
        break;
      case PendingType.user:
        text = 'User';
        color = Colors.purple;
        break;
      case PendingType.banner:
        text = 'Banner';
        color = Colors.green;
        break;
      case PendingType.profileEditRequest:
        text = 'Profile Edit';
        color = Colors.teal;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  // Get filtered list based on selected filter
  List<PendingApprovalItem> get filteredPendingList {
    if (selectedFilter == 'All') return pendingList;

    PendingType? filterType;
    switch (selectedFilter) {
      case 'Notification':
        filterType = PendingType.notification;
        break;
      case 'Template':
        filterType = PendingType.template;
        break;
      case 'Banner':
        filterType = PendingType.banner;
        break;
      case 'Profile Edit':
        filterType = PendingType.profileEditRequest;
        break;
    }

    if (filterType == null) return pendingList;
    return pendingList.where((item) => item.type == filterType).toList();
  }

  /// Open detail page when navigated from notification
  void _openDetailFromNotification() async {
    _hasOpenedDetail = true;

    // Wait a frame to ensure build is complete
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    debugPrint(
      '🔍 Looking for approval: ID=${widget.approvalId}, Type=${widget.approvalType}',
    );
    debugPrint('📋 Total pending items: ${pendingList.length}');

    // Find the approval by ID and type
    PendingApprovalItem? targetItem;

    // First, check if the ID matches the first item (most recent)
    if (pendingList.isNotEmpty && widget.approvalType == 'notification') {
      final firstNotification = pendingList.firstWhere(
        (item) => item.type == PendingType.notification,
        orElse: () => pendingList.first,
      );
      debugPrint('🎯 First notification in list: ${firstNotification.title}');
      debugPrint('   ID: ${firstNotification.id}');
      debugPrint('   NotificationId: ${firstNotification.notificationId}');

      // Since the notification just came in, it's likely the first one
      // Check if it's within the last few minutes
      final timeDiff = DateTime.now().difference(firstNotification.createdAt);
      if (timeDiff.inMinutes < 5) {
        debugPrint(
          '✅ Using first notification (created ${timeDiff.inSeconds}s ago)',
        );
        targetItem = firstNotification;
      }
    }

    // If not found by recency, search through all items
    if (targetItem == null) {
      for (var item in pendingList) {
        // Debug: Print item details for matching type
        if (widget.approvalType != null &&
            (widget.approvalType == 'notification' &&
                    item.type == PendingType.notification ||
                widget.approvalType == 'banner' &&
                    item.type == PendingType.banner ||
                widget.approvalType == 'template' &&
                    item.type == PendingType.template)) {
          debugPrint(
            '  Item: id=${item.id}, mongoId=${item.mongoId}, type=${item.type}',
          );
        }

        // Check main ID first
        if (item.id == widget.approvalId) {
          targetItem = item;
          debugPrint('✅ Found match by main ID');
          break;
        }

        // Check MongoDB _id (sent by backend in notifications)
        if (item.mongoId == widget.approvalId) {
          targetItem = item;
          debugPrint('✅ Found match by MongoDB _id');
          break;
        }

        // Check specific IDs based on type - also check notificationTempId
        if (widget.approvalType == 'notification') {
          if (item.notificationId == widget.approvalId ||
              item.notificationTempId == widget.approvalId ||
              item.id.contains(widget.approvalId!)) {
            targetItem = item;
            debugPrint('✅ Found match by notification ID/TempID');
            break;
          }
        }
        if (widget.approvalType == 'template') {
          if (item.templateId == widget.approvalId ||
              item.id.contains(widget.approvalId!)) {
            targetItem = item;
            debugPrint('✅ Found match by template ID');
            break;
          }
        }
        if (widget.approvalType == 'banner') {
          if (item.bannerId == widget.approvalId ||
              item.id.contains(widget.approvalId!)) {
            targetItem = item;
            debugPrint('✅ Found match by banner ID');
            break;
          }
        }
        if (widget.approvalType == 'profileEditRequest') {
          if (item.mobile == widget.approvalId ||
              item.id.contains(widget.approvalId!)) {
            targetItem = item;
            debugPrint('✅ Found match by mobile');
            break;
          }
        }
      }
    }

    if (targetItem != null) {
      debugPrint('🎯 Opening detail for: ${targetItem.title}');
      await _showPendingDetails(targetItem);
    } else {
      debugPrint('❌ No match found');
      showSnackBar(context, 'Approval not found or already processed');
    }
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.year}";
  }

  String _formatTime(DateTime dt) {
    final d = dt.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// ---------- Actions ----------
  void _onApprove(PendingApprovalItem item) async {
    final comment = await _showCommentDialog(isReject: false);
    if (comment != null) {
      await _performAction(item, 'Approved', comment);
    }
  }

  void _onReject(PendingApprovalItem item) async {
    final comment = await _showCommentDialog(isReject: true);
    if (comment != null) {
      await _performAction(item, 'Rejected', comment);
    }
  }

  Future<String?> _showCommentDialog({required bool isReject}) async {
    final TextEditingController commentController = TextEditingController();
    String? errorText;

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                isReject ? 'Reject with Comment' : 'Add Comment',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReject
                        ? 'Please provide a reason for rejection:'
                        : 'Add a comment (optional):',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    maxLength: 500,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter your comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isReject ? Colors.red : AppColors.main,
                          width: 2,
                        ),
                      ),
                      errorText: errorText,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReject ? Colors.red : AppColors.main,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final comment = commentController.text.trim();
                    if (isReject && comment.isEmpty) {
                      setState(() {
                        errorText = 'Comment is required for rejection';
                      });
                    } else {
                      Navigator.of(context).pop(comment);
                    }
                  },
                  child: Text(isReject ? 'Reject' : 'Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _performAction(
    PendingApprovalItem item,
    String status,
    String comment,
  ) async {
    final token = AuthDataHelper.getToken();
    final authToken = token.isNotEmpty ? token : null;
    if (authToken == null) {
      showSnackBar(context, 'Not authenticated');
      return false;
    }

    try {
      ApiResponse resp;
      if (item.type == PendingType.template) {
        resp = await PendingService.approveTemplate(
          item.id,
          status,
          authToken,
          comment,
        );
      } else if (item.type == PendingType.notification) {
        resp = await PendingService.approveNotification(
          item.id,
          status,
          authToken,
          comment,
        );
      } else if (item.type == PendingType.banner) {
        resp = await PendingService.approveBanner(
          item.id,
          status,
          authToken,
          comment,
        );
      } else if (item.type == PendingType.profileEditRequest) {
        resp = await PendingService.approveProfileEditRequest(
          item.mobile ?? '',
          status,
          authToken,
          comment,
        );
      } else {
        showSnackBar(context, 'Unsupported item type');
        return false;
      }

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        setState(() {
          pendingList.removeWhere((p) => p.id == item.id);
          _actionsTaken++;
        });
        showSnackBar(context, 'Success');
        return true;
      } else {
        showSnackBar(context, 'Error: ${resp.statusCode}');
        return false;
      }
    } catch (e) {
      showSnackBar(context, 'Error: $e');
      return false;
    }
  }

  Future<void> _showPendingDetails(PendingApprovalItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            builder: (_, controller) {
              return SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Show detailed metadata for templates and fallback for others
                      if (item.type == PendingType.template) ...[
                        Text('Template Type: ${item.templateType ?? ''}'),
                        const SizedBox(height: 6),
                        Text('Template Header: ${item.templateHeader ?? ''}'),
                        const SizedBox(height: 6),
                        Text('Body: ${item.body ?? item.description}'),
                        const SizedBox(height: 6),
                        if ((item.createdByName ?? '').isNotEmpty)
                          Text('Created By: ${item.createdByName}'),
                        if ((item.createdByName ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.updatedBy ?? '').isNotEmpty)
                          Text('Updated By: ${item.updatedBy}'),
                        if ((item.updatedBy ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                      ] else if (item.type == PendingType.banner) ...[
                        Text('Banner Name: ${item.bannerName ?? item.title}'),
                        const SizedBox(height: 6),
                        Text('Banner Title: ${item.bannerTitle ?? ''}'),
                        const SizedBox(height: 6),
                        Text('Description: ${item.description}'),
                        const SizedBox(height: 6),
                        if ((item.createdByName ?? '').isNotEmpty)
                          Text('Created By: ${item.createdByName}'),
                        if ((item.createdByName ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.bannerUrl ?? '').isNotEmpty)
                          Text('Banner URL: ${item.bannerUrl}'),
                        if ((item.bannerUrl ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.bannerImageUrl ?? '').isNotEmpty) ...[
                          const Text('Banner Image:'),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.bannerImageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    height: 120,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ] else if (item.type ==
                          PendingType.profileEditRequest) ...[
                        // Profile edit request details
                        if ((item.profileImageUrl ?? '').isNotEmpty) ...[
                          const Text('Profile Image:'),
                          const SizedBox(height: 6),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Image.network(
                                item.profileImageUrl!,
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Container(
                                      height: 80,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: const Icon(Icons.person, size: 40),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Name: ${item.firstName ?? ''} ${item.lastName ?? ''}',
                        ),
                        const SizedBox(height: 6),
                        if ((item.mobile ?? '').isNotEmpty)
                          Text('Mobile: ${item.mobile}'),
                        if ((item.mobile ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.email ?? '').isNotEmpty)
                          Text('Email: ${item.email}'),
                        if ((item.email ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.alternateMobile ?? '').isNotEmpty)
                          Text('Alternate Mobile: ${item.alternateMobile}'),
                        if ((item.alternateMobile ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.alternateEmail ?? '').isNotEmpty)
                          Text('Alternate Email: ${item.alternateEmail}'),
                        if ((item.alternateEmail ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.companyName ?? '').isNotEmpty)
                          Text('Company: ${item.companyName}'),
                        if ((item.companyName ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.department ?? '').isNotEmpty)
                          Text('Department: ${item.department}'),
                        if ((item.department ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.designation ?? '').isNotEmpty)
                          Text('Designation: ${item.designation}'),
                        if ((item.designation ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.address ?? '').isNotEmpty)
                          Text('Address: ${item.address}'),
                        if ((item.address ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.country ?? '').isNotEmpty)
                          Text('Country: ${item.country}'),
                        if ((item.country ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.region ?? '').isNotEmpty)
                          Text('Region: ${item.region}'),
                        if ((item.region ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.landlineNumber ?? '').isNotEmpty)
                          Text('Landline: ${item.landlineNumber}'),
                        if ((item.landlineNumber ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.extentionNumber ?? '').isNotEmpty)
                          Text('Extension: ${item.extentionNumber}'),
                        if ((item.extentionNumber ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if (item.activeRmsUser != null)
                          Text(
                            'Active RMS User: ${item.activeRmsUser! ? 'Yes' : 'No'}',
                          ),
                        if (item.activeRmsUser != null)
                          const SizedBox(height: 6),
                        // if ((item.lastUpdatedBy ?? '').isNotEmpty)
                        //   Text('Last Updated By: ${item.lastUpdatedBy}'),
                        // if ((item.lastUpdatedBy ?? '').isNotEmpty)
                          // const SizedBox(height: 6),
                      ] else ...[
                        // Detailed notification view
                        Text(
                          'Message Header: ${item.messageHeader ?? item.title}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Message Body: ${item.messageBody ?? item.description}',
                        ),
                        const SizedBox(height: 6),
                        if ((item.createdByName ?? '').isNotEmpty)
                          Text('Created By: ${item.createdByName}'),
                        if ((item.createdByName ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((item.link ?? '').isNotEmpty)
                          Text('Link: ${item.link}'),
                        if ((item.link ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if (item.scheduledDate != null)
                          Text(
                            'Scheduled Date: ${_formatDate(item.scheduledDate!)}',
                          ),
                        if (item.scheduledDate != null)
                          const SizedBox(height: 6),
                        if (item.scheduledTime != null)
                          Text(
                            'Scheduled Time: ${_formatTime(item.scheduledTime!)}',
                          ),
                        if (item.scheduledTime != null)
                          const SizedBox(height: 6),
                        if (item.targetUsers != null &&
                            item.targetUsers!.isNotEmpty)
                          Text('Target Users: ${item.targetUsers!.join(', ')}'),
                        if (item.targetUsers != null &&
                            item.targetUsers!.isNotEmpty)
                          const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.verified,
                                color: Colors.white,
                              ),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                _onApprove(item);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                _onReject(item);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE4E7EC)),
          borderRadius: BorderRadius.circular(8),
          color: date != null ? AppColors.main.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          date != null ? FontWeight.w500 : FontWeight.normal,
                      color:
                          date != null ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}
