import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/template_list_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class AddTemplateScreen extends StatefulWidget {
  final TemplateModel? templateModel;

  const AddTemplateScreen({super.key, this.templateModel});

  @override
  State<AddTemplateScreen> createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends State<AddTemplateScreen> {
  final nameController = TextEditingController();
  final headerController = TextEditingController();
  final bodyController = TextEditingController();

  String? templateType;

  String? nameError;
  String? headerError;
  String? bodyError;
  String? typeError;
  final List<String> templateTypes = [
    "Transactional",
    "Promotional",
    "Behavioural",
  ];

  @override
  void initState() {
    final templateModel = widget.templateModel;
    if (templateModel != null) {
      nameController.text = templateModel.templateName!;
      headerController.text = templateModel.templateHeader!;
      bodyController.text = templateModel.body!;
      templateType = templateModel.templateType;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(title: widget.templateModel != null ? "Edit Template" : "Create Template"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 20),

            buildRoundedDropdownWithArrow(
              label: "Template Type",
              hint: "Select type",
              items: templateTypes,
              value: templateType,
              errorText: typeError,

              onChanged: (value) {
                setState(() {
                  templateType = value;
                  typeError = null;
                });
              },
              context: context,
            ),

            buildUserTextField(
              isRequired: true,
              label: "Template Name",
              hint: "Enter name",
              controller: nameController,
              errorText: nameError,
            ),

            buildUserTextField(
              isRequired: true,
              label: "Template Header",
              hint: "Enter header",
              controller: headerController,
              errorText: headerError,
            ),

            buildMessageTextField(
              isRequired: true,
              label: "Template Body",
              hint: "Enter body text",
              controller: bodyController,
              errorText: bodyError,
            ),

            const SizedBox(height: 30),

            MainButton(
              text: "Save Template",
              onPressed: () {
                if (widget.templateModel != null) {
                  updateTemplate();
                } else {
                  createTemplate();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> createTemplate() async {
    if (!validateFields()) return;

    if (!(await checkInternetConnection())) {
      showSnackBar(context, "Please check internet connection");
      return;
    }

    ProgressLoader.show(context);
    try {
      final response = await HttpClientHelper.postWithBearerNew(
        ApiConstants.createNotificationTemplate,
        AuthDataHelper.getToken(),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "templateType": templateType,
          "templateName": nameController.text.trim(),
          "templateHeader": headerController.text.trim(),
          "body": bodyController.text.trim(),
        }),
      );

      ProgressLoader.hide(context);
      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnackBar(context, "Template Created Successfully!");
        Navigator.pop(context,true);
      } else {
        showSnackBar(context, "Error: ${response.message}");
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, "Error: $e");
    }
  }

  Future<void> updateTemplate() async {
    if (!validateFields()) return;

    if (!(await checkInternetConnection())) {
      showSnackBar(context, "Please check internet connection");
      return;
    }

    ProgressLoader.show(context);
    try {
      final response = await HttpClientHelper.patchWithBearer(
        '${ApiConstants.updateNotificationTemplate}/${widget.templateModel?.templateId}',
        AuthDataHelper.getToken(),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "templateType": widget.templateModel?.templateType,
          "templateName": nameController.text.trim(),
          "templateHeader": headerController.text.trim(),
          "body": bodyController.text.trim(),
        }),
      );
      ProgressLoader.hide(context);
      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnackBar(
          context,
          response.message ?? "Template Updated Successfully!",
        );
        Navigator.pop(context,true);
      } else {
        showSnackBar(context, "Error: ${response.message}");
      }
    } catch (e) {
      ProgressLoader.hide(context);
      showSnackBar(context, "Error: $e");
    }
  }

  bool validateFields() {
    setState(() {
      if (widget.templateModel == null && templateType == null) {
        typeError = "Select template type";
      } else {
        typeError = null;
      }

      nameError = nameController.text.isEmpty ? "Enter name" : null;
      headerError = headerController.text.isEmpty ? "Enter header" : null;
      bodyError = bodyController.text.isEmpty ? "Enter body" : null;
    });

    return typeError == null &&
        nameError == null &&
        headerError == null &&
        bodyError == null;
  }
}
