import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/model/template_list_response.dart';
import 'package:mprs_android/screens/notification/add_push_notification.dart';
import 'package:mprs_android/screens/notification/add_template_screen.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/search_user_bar.dart';

class PushNotificationScreen extends StatefulWidget {
  const PushNotificationScreen({super.key});

  @override
  State<PushNotificationScreen> createState() => _PushNotificationScreenState();
}

class _PushNotificationScreenState extends State<PushNotificationScreen> {
  bool isLoading = false;
  List<TemplateModel> notificationList = [];
  List<TemplateModel> filteredList = [];
  final searchController = TextEditingController();

  bool isAdmin = AuthDataHelper.isAdminUser(); // true / false

  @override
  void initState() {
    super.initState();
    getAllNotificationTemplates();
  }

  // 🔍 Apply Search Filter
  void filterNotifications() {
    String search = searchController.text.toLowerCase();

    setState(() {
      filteredList = notificationList.where((item) {
        return (item.templateName ?? "").toLowerCase().contains(search) ||
            (item.templateHeader ?? "").toLowerCase().contains(search);
      }).toList();
    });
  }

  // 🔥 API WITH LOADER
  Future<void> getAllNotificationTemplates() async {
    setState(() => isLoading = true);

    try {
      var response = await HttpClientHelper.getWithBearer(
        "${ApiConstants.allNotificationTemplates}?page=1",
        AuthDataHelper.getToken(),
      );

      if (response.statusCode == 200) {
        var jsonBody = jsonDecode(response.data);
        var parsed = TemplateListResponse.fromJson(jsonBody);

        setState(() {
          notificationList = parsed.data ?? [];
          filteredList = List.from(notificationList);
        });
      } else {
        print("Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // PATCH API → update notification template
  Future<void> updateNotificationTemplate({
    required String templateId,
    required String updatedName,
    required String updatedBody,
    String templateType = "Promotional",
    bool isActive = false,
  }) async {
    final String token = AuthDataHelper.getToken();
    final String url =
        ApiConstants.updateNotificationTemplateById(templateId);

    final Map<String, dynamic> body = {
      "templateName": updatedName,
      "templateType": templateType,
      "body": updatedBody,
      "isActive": isActive,
    };

    try {
      ApiResponse response = await HttpClientHelper.patchWithBearer(
        url,
        token,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        print("Success: ${data['message']}");
        showSnackBar(context, response.message??"");
      } else {
        print("Failed: ${response.message}");
        print("Response body: ${response.data}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Notifications",
        actionWidget: Text(
          "Add New",
          style: TextStyle(
            color: AppColors.main,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onActionPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active, color: Colors.blue),
                      title: const Text("Create Notification"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddPushNotification(templateList: notificationList),
                          ),
                        ).then((_) => getAllNotificationTemplates());
                      },
                    ),

                    const Divider(),

                    ListTile(
                      leading: const Icon(Icons.file_copy, color: Colors.green),
                      title: const Text("Create Template"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddTemplateScreen(), // ← your new screen
                          ),
                        ).then((_) => getAllNotificationTemplates());
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // 🔍 Search Bar
            SearchUserBar(
              controller: searchController,
              onChanged: (_) => filterNotifications(),
            ),

            const SizedBox(height: 12),

            // 🔄 Loader + List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                  ? const Center(
                child: Text("No notification templates found"),
              )
                  : ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final item = filteredList[index];

                            return notificationTile(
                              title: item.templateName ?? "",
                              body: item.body ?? "",
                              iconPath: 'assets/images/notification_ic.png',
                              isAdmin: isAdmin,
                              onEdit: () async {

                              },
                              onDelete: () async {
                                await updateNotificationTemplate(
                                templateId: item.templateId!,
                                updatedName: item.templateName! ,
                                updatedBody: item.body! ,
                                );
                                getAllNotificationTemplates();
                              },
                              onApprove: () {
                                print("Approved : ${item.templateId}");
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// 🔵 NOTIFICATION TILE WIDGET
//

Widget notificationTile({
  required String title,
  required String body,
  required String iconPath,
  required bool isAdmin, // true/false
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onApprove,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT ICON
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            iconPath,
            width: 28,
            height: 28,
          ),
        ),

        const SizedBox(width: 12),

        // CONTENT
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),

        // ACTION BUTTONS
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.green, size: 22),
              onPressed: onEdit,
            ),

            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
              onPressed: onDelete,
            ),

            // APPROVE BUTTON ONLY FOR ADMIN
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.verified, color: Colors.blue, size: 24),
                onPressed: onApprove,
              ),
          ],
        )
      ],
    ),
  );
}
