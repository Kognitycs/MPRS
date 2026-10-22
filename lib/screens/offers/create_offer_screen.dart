import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/common_data.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  String? targetingUser;
  String? titleError;
  String? descriptionError;
  String? targetingUserError;


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(
        title: "Create new offer and services",
        onActionPressed: () {},
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              GestureDetector(
                onTap: () {
                  print("Upload image tapped");
                },
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5), // light grey background
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Upload image",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              buildUserTextField(
                label: "Title",
                hint: "Title",
                controller: titleController,
                onChanged: (value) {},
                errorText: titleError,
              ),

              buildMessageTextField(
                label: "Description",
                hint: "Description",
                controller: descriptionController,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: descriptionError,
              ),

              buildRoundedDropdownWithArrow(
                label: "Targeting user",
                hint: "Targeting user",
                items: userRoles,
                value: targetingUser,
                onChanged: (value) {
                  setState(() {
                    targetingUser = value;
                  });
                },
                errorText: targetingUserError,

                context: context,
              ),

              Row(
                children: [
                  // START DATE
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setState(() {
                            startDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightGrey),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                startDate == null
                                    ? "mm/dd/yyyy"
                                    : "${startDate!.month}/${startDate!.day}/${startDate!.year}",
                                style: TextStyle(
                                  color: startDate == null ? Colors.grey : Colors.black, // ← changed
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // END DATE
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setState(() {
                            endDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightGrey),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                endDate == null
                                    ? "mm/dd/yyyy"
                                    : "${endDate!.month}/${endDate!.day}/${endDate!.year}",
                                style: TextStyle(
                                  color: endDate == null ? Colors.grey : Colors.black, // ← changed
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              MainButton(
                text: 'Save',
                onPressed: () {
                  saveUser();
                },
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveUser() async {
    if (!validateFields()) return;

    showSnackBar(context, "Sent");

    Navigator.pop(context);
  }

  bool validateFields() {
    setState(() {
      titleError = titleController.text.isEmpty ? "Please enter title" : null;

      descriptionError =
          descriptionController.text.isEmpty ? "Please enter message" : null;

      targetingUserError =
          (targetingUser == null) ? "Please select a user role" : null;
    });

    // All correct?
    return titleError == null &&
        descriptionError == null &&
        targetingUserError == null;
  }
}
