import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/model/template_list_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/notification/admin_notification_service.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import '../../core/utils/common_data.dart';

class AddPushNotification extends StatefulWidget {
  final List<TemplateModel> templateList;
  final NotificationItem? notificationItem;

  const AddPushNotification({
    super.key,
    this.templateList = const [],
    this.notificationItem,
  });

  @override
  State<AddPushNotification> createState() => _AddPushNotificationState();
}

class _AddPushNotificationState extends State<AddPushNotification> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? templateType;
  DateTime? selectedScheduleDateTime;
  String? selectedScheduleText;
  List<String> selectedTargetUsers = [];
  String? scheduling;
  String? titleError;
  String? messageError;
  String? templateError;
  String? targetingUserError;
  String? schedulingError;

  final List<String> templateTypes = const [
    'Transactional',
    'Promotional',
    'Behavioural',
  ];

  @override
  void initState() {
    super.initState();

    final notificationItemNew = widget.notificationItem;
    if (notificationItemNew != null) {
      titleController.text = notificationItemNew.messageHeader;
      messageController.text = notificationItemNew.messageBody;
      selectedTargetUsers = notificationItemNew.targetUsers ?? [];
      templateType = _typeForTemplateId(notificationItemNew.notificationTempId);

      try {
        final sd = notificationItemNew.scheduledDate;
        final st = notificationItemNew.scheduledTime;
        final combined = DateTime(
          sd.year,
          sd.month,
          sd.day,
          st.hour,
          st.minute,
        );
        selectedScheduleDateTime = combined;
        selectedScheduleText = DateFormat('dd MMM yyyy, hh:mm a').format(combined);
        scheduling = DateTime.now().difference(combined).inMinutes.abs() < 1
            ? 'Send Immediately'
            : 'Custom';
      } catch (_) {}
    }
  }

  TemplateModel? _templateForType(String? type) {
    final query = (type ?? '').trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final template in widget.templateList) {
      final candidate = (template.templateType ?? '').trim().toLowerCase();
      if (candidate == query) return template;
    }
    return null;
  }

  String? _typeForTemplateId(String templateId) {
    final query = templateId.trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final template in widget.templateList) {
      final id = (template.templateId ?? template.id ?? '').trim().toLowerCase();
      if (id == query) {
        return template.templateType;
      }
    }

    if (templateTypes.any((t) => t.toLowerCase() == query)) {
      return templateTypes.firstWhere((t) => t.toLowerCase() == query);
    }
    return null;
  }

  String? _resolveTemplateId() {
    final match = _templateForType(templateType);
    final id = (match?.templateId ?? match?.id ?? '').trim();
    return id.isEmpty ? null : id;
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(
        title:
            widget.notificationItem != null
                ? 'Edit Push Notification'
                : 'Add Push Notification',
        onActionPressed: () {},
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              buildRoundedDropdownWithArrow(
                context: context,
                isRequired: true,
                label: 'Template Type',
                hint: 'Select type',
                items: templateTypes,
                value: templateType,
                errorText: templateError,
                onChanged: (value) {
                  setState(() {
                    templateType = value;
                    templateError = null;
                  });
                },
              ),
              buildUserTextField(
                isRequired: true,
                label: 'Title',
                hint: 'Title',
                controller: titleController,
                onChanged: (value) {},
                errorText: titleError,
              ),
              buildMessageTextField(
                isRequired: true,
                label: 'Message',
                hint: 'Message',
                controller: messageController,
                onChanged: (value) {},
                errorText: messageError,
              ),
              buildRoundedDropdownWithCheckbox(
                label: 'Targeting user',
                hint: 'Targeting user',
                items: pushNotificationTargetRoles,
                isRequired: true,
                selectedValues: selectedTargetUsers,
                onChanged: (List<String> values) {
                  setState(() {
                    selectedTargetUsers = values;
                  });
                },
                errorText: targetingUserError,
                context: context,
              ),
              buildRoundedDropdownForSchedule(
                isRequired: true,
                label: 'Scheduling',
                hint: 'Select scheduling',
                context: context,
                selectedValue: selectedScheduleText,
                onSelectedDateTime: (DateTime dateTime) {
                  setState(() {
                    selectedScheduleDateTime = dateTime;
                    final isImmediate =
                        DateTime.now().difference(dateTime).inMinutes.abs() < 2;
                    if (isImmediate) {
                      scheduling = 'Send Immediately';
                      selectedScheduleText = 'Send Immediately';
                    } else {
                      scheduling = 'Custom';
                      selectedScheduleText =
                          DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
                    }
                    schedulingError = null;
                  });
                },
                errorText: schedulingError,
              ),
              const SizedBox(height: 25),
              MainButton(
                text: widget.notificationItem != null ? 'Update' : 'Send',
                onPressed: () {
                  if (widget.notificationItem != null) {
                    updateNotification();
                  } else {
                    sendNotification();
                  }
                },
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> sendNotification() async {
    if (!validateFields()) return;

    final templateId = _resolveTemplateId();
    if (templateId == null) {
      showSnackBar(
        context,
        'No $templateType template found. Create one from the Templates tab first.',
      );
      return;
    }

    ProgressLoader.show(context);
    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    final now = DateTime.now();
    final scheduledDate =
        scheduling?.trim() == 'Send Immediately'
            ? DateFormat('yyyy-MM-dd').format(now)
            : DateFormat('yyyy-MM-dd').format(selectedScheduleDateTime ?? now);
    final scheduledTime =
        scheduling?.trim() == 'Send Immediately'
            ? DateFormat('HH:mm').format(now)
            : DateFormat('HH:mm').format(selectedScheduleDateTime ?? now);

    try {
      final result = await AdminNotificationService.createAndPush(
        CreatePushNotificationRequest(
          notificationTempId: templateId,
          messageHeader: titleController.text.trim(),
          messageBody: messageController.text.trim(),
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          targetUsers: selectedTargetUsers,
        ),
      );

      ProgressLoader.hide(context);
      if (!mounted) return;

      showSnackBar(context, result.userMessage);
      if (result.created) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error: $e');
    }
  }

  Future<void> updateNotification() async {
    if (!validateFields()) return;

    ProgressLoader.show(context);

    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    final now = DateTime.now();
    final scheduledDate =
        scheduling?.trim() == 'Send Immediately'
            ? DateFormat('yyyy-MM-dd').format(now)
            : DateFormat('yyyy-MM-dd').format(selectedScheduleDateTime ?? now);
    final scheduledTime =
        scheduling?.trim() == 'Send Immediately'
            ? DateFormat('HH:mm').format(now)
            : DateFormat('HH:mm').format(selectedScheduleDateTime ?? now);

    try {
      var apiResponse = await HttpClientHelper.patchWithBearer(
        '${ApiConstants.updateNotification}/${widget.notificationItem?.notificationId}',
        AuthDataHelper.getToken(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notificationTempId':
              _resolveTemplateId() ??
              widget.notificationItem?.notificationTempId,
          'messageHeader': titleController.text.trim(),
          'messageBody': messageController.text.trim(),
          'link': '',
          'scheduledDate': scheduledDate,
          'scheduledTime': scheduledTime,
          'targetUsers': selectedTargetUsers,
        }),
      );
      ProgressLoader.hide(context);
      if (apiResponse.statusCode == 200 || apiResponse.statusCode == 201) {
        showSnackBar(context, apiResponse.message ?? 'Updated Successfully!');
        if (mounted) Navigator.pop(context, true);
      } else {
        showSnackBar(context, 'Error: ${apiResponse.statusCode}');
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, 'Error: $e');
    }
  }

  bool validateFields() {
    setState(() {
      templateError =
          templateType == null || templateType!.trim().isEmpty
              ? 'Select template type'
              : null;
      titleError = titleController.text.isEmpty ? 'Please enter title' : null;
      messageError =
          messageController.text.isEmpty ? 'Please enter message' : null;
      targetingUserError =
          selectedTargetUsers.isEmpty
              ? 'Please select at least one user role'
              : null;
      schedulingError =
          scheduling == null ? 'Please select a scheduling option' : null;
    });

    return titleError == null &&
        messageError == null &&
        templateError == null &&
        targetingUserError == null &&
        schedulingError == null;
  }
}
