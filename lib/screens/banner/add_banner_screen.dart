import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/banner_item.dart';
import 'package:mprs_android/controller/banner_refresh_controller.dart';
import 'package:mprs_android/core/utils/banner_local_image_store.dart';
import 'package:mprs_android/core/utils/banner_response_parser.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class AddBannerScreen extends StatefulWidget {
  final BannerItem? bannerItem;

  const AddBannerScreen({super.key, this.bannerItem});

  @override
  State<AddBannerScreen> createState() => _AddBannerScreenState();
}

class _AddBannerScreenState extends State<AddBannerScreen> {
  bool expanded = true;
  File? bannerImage;
  bool isEditingBanner1 = false;

  final TextEditingController bannerTitleCtrl = TextEditingController(
    text: "Banner 1",
  );
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController link = TextEditingController();
  String? existingBannerImageUrl;

  // Link Type variables
  String linkType = 'External'; // 'External' or 'Internal'
  String? selectedInternalPage;

  // Internal page options
  final List<Map<String, String>> internalPages = [
    // {'name': 'Create Banner', 'ref': 'Create Banner'},
    // {'name': 'Create Booking', 'ref': 'Create Booking'},
    {'name': 'Create Subscription', 'ref': 'Create Subscription'},
    {'name': 'Profile', 'ref': 'Profile'},
    {'name': 'Notifications', 'ref': 'Notifications'},
  ];

  bool get isEdit => widget.bannerItem != null;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        return;
      }

      final File imageFile = File(image.path);

      // Validate file type
      final String extension = image.path.split('.').last.toLowerCase();
      const List<String> allowedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!allowedFormats.contains(extension)) {
        showSnackBar(
          context,
          'Invalid image format. Allowed: JPG, PNG, GIF, WebP',
        );
        return;
      }

      // Validate file size (max 2MB)
      final int imageSize = await imageFile.length();
      const int maxImageSize = 2 * 1024 * 1024; // 2 MB
      if (imageSize > maxImageSize) {
        showSnackBar(
          context,
          'Image size exceeds 2 MB limit. Current size: ${(imageSize / (1024 * 1024)).toStringAsFixed(2)} MB',
        );
        return;
      }

      setState(() {
        bannerImage = imageFile;
      });

      showSnackBar(context, 'Image selected successfully');
    } catch (e) {
      showSnackBar(context, 'Error selecting image: ${e.toString()}');
    }
  }

  @override
  void initState() {
    super.initState();

    if (isEdit) {
      _fillEditData(widget.bannerItem!);
    }
  }

  void _fillEditData(BannerItem banner) {
    bannerTitleCtrl.text = banner.title ?? "Banner 1";
    nameCtrl.text = banner.name ?? '';
    descCtrl.text = banner.description ?? '';
    existingBannerImageUrl = banner.bannerImageUrl;

    // Set link type and related fields
    if ((banner.linkType ?? '').toLowerCase() == 'internal') {
      linkType = 'Internal';
      // Only set selectedInternalPage if it exists in internalPages
      final allowedRefs = internalPages.map((p) => p['ref']).toSet();
      if (allowedRefs.contains(banner.linkRef)) {
        selectedInternalPage = banner.linkRef;
      } else {
        selectedInternalPage = null;
      }
      link.clear();
    } else {
      linkType = 'External';
      link.text = banner.bannerUrl ?? '';
      selectedInternalPage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: isEdit ? "Edit Banner" : "Add Banner",
        onActionPressed: () {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            /// SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: _buildBannerCard(),
              ),
            ),

            /// FIXED BOTTOM BUTTON
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: MainButton(
                text: isEdit ? 'Update Banner' : 'Add Banner',
                onPressed: () {
                  isEdit
                      ? updateBanner(widget.bannerItem?.bannerId ?? "")
                      : addBanner();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- Banner Card ----------------
  Widget _buildBannerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          /// HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),

                // Editable Banner Title
                isEditingBanner1
                    ? Expanded(
                      child: TextField(
                        controller: bannerTitleCtrl,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 3),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    )
                    : Text(
                      bannerTitleCtrl.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                const Spacer(),

                // Edit/Save Button
                IconButton(
                  icon: Icon(isEditingBanner1 ? Icons.check : Icons.edit),
                  onPressed: () {
                    setState(() {
                      isEditingBanner1 = !isEditingBanner1;
                    });
                  },
                ),
              ],
            ),
          ),

          /// BODY
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// IMAGE PICKER
                  Row(
                    children: [
                      _requiredLabel("Banner Image"),
                      const Spacer(),
                      const Text(
                        "Max 2 MB, JPG/PNG/GIF/WebP",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            bannerImage != null
                                ? Image.file(
                                  bannerImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                                : (isEdit &&
                                        existingBannerImageUrl != null &&
                                        existingBannerImageUrl!.isNotEmpty
                                    ? Image.network(
                                      existingBannerImageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, __, ___) {
                                        return _uploadPlaceholder();
                                      },
                                    )
                                    : _uploadPlaceholder()),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// NAME
                  _requiredLabel("Banner Name"),
                  const SizedBox(height: 6),
                  _inputField(controller: nameCtrl, hint: "Enter banner name"),

                  const SizedBox(height: 14),

                  /// DESCRIPTION
                  _requiredLabel("Description"),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: descCtrl,
                    hint: "Enter description",
                    maxLines: 3,
                  ),

                  const SizedBox(height: 10),

                  /// LINK TYPE
                  _requiredLabel("Link Type"),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: linkType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'External',
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text('External URL'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Internal',
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text('Internal Page'),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            linkType = value;
                            if (linkType == 'Internal') {
                              selectedInternalPage = internalPages[0]['ref'];
                              link.clear();
                            } else {
                              selectedInternalPage = null;
                              link.clear();
                            }
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// LINK INPUT - External
                  if (linkType == 'External') ...[
                    _requiredLabel("External Link URL"),
                    const SizedBox(height: 6),
                    TextField(
                      controller: link,
                      decoration: InputDecoration(
                        hintText: "Enter URL (e.g., https://example.com)",
                        filled: true,
                        fillColor: const Color(0xFFF6F6F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (linkType == 'Internal') ...[
                    _requiredLabel("Select Page"),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: selectedInternalPage ?? (internalPages.isNotEmpty ? internalPages[0]['ref'] : null),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: internalPages
                            .map(
                              (page) => DropdownMenuItem<String>(
                                value: page['ref'],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(page['name'] ?? ''),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              selectedInternalPage = value;
                              link.text = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  /// FOOTER - Removed "Change image" button since image is clickable
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _uploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
        SizedBox(height: 6),
        Text("Upload image", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  BannerItem _buildUpdatedBannerFromForm() {
    final original = widget.bannerItem!;

    return original.copyWith(
      name: nameCtrl.text.trim(),
      title: bannerTitleCtrl.text.trim(),
      description: descCtrl.text.trim(),
      linkType: linkType,
      linkRef: linkType == 'Internal' ? selectedInternalPage : null,
      bannerUrl:
          linkType == 'External'
              ? link.text.trim()
              : original.bannerUrl,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateBanner(String bannerId) async {
    // Validate form before submission
    if (!_validateForm()) {
      return;
    }

    if (!(await checkInternetConnection())) {
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    Loader.show();

    try {
      final fields = {
        'bannerId': widget.bannerItem!.bannerId,
        'name': nameCtrl.text.trim(),
        'title': bannerTitleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'linkType': linkType,
        if (linkType == 'External') 'bannerUrl': link.text.trim(),
        if (linkType == 'Internal') 'linkRef': selectedInternalPage ?? '',
        'isActive': 'true',
      };

      final response = await HttpClientHelper.patchWithMultipart(
        '${ApiConstants.updateBannerById}/${bannerId}',
        AuthDataHelper.getToken(),
        fields: fields,
        file: bannerImage,
        fileField: "bannerImage",
      );

      Loader.hide();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Banner update response: ${response.data}');

        var updatedBanner = BannerResponseParser.parseBannerFromResponse(
          response.data,
        );
        updatedBanner ??= _buildUpdatedBannerFromForm();

        if (bannerImage != null) {
          BannerLocalImageStore.set(bannerId, bannerImage!.path);
        }

        BannerRefreshController.ensureRegistered().notifyChanged(
          updatedBanner: updatedBanner,
        );
        showSnackBar(
          context,
          response.message ?? "Banner updated successfully",
        );
        Navigator.pop(context, updatedBanner);
      } else {
        final errorMessage = response.message ?? "Update failed";
        showSnackBar(context, "Error: $errorMessage");
      }
    } on SocketException {
      Loader.hide();
      showSnackBar(context, "Network Error: Check your internet connection");
    } on FormatException {
      Loader.hide();
      showSnackBar(context, "Error: Invalid response format from server");
    } catch (e) {
      Loader.hide();
      showSnackBar(context, "Error updating banner: ${e.toString()}");
    }
  }

  Future<void> addBanner() async {
    // Validate form before submission
    if (!_validateForm()) {
      return;
    }

    if (!(await checkInternetConnection())) {
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    if (!isEdit && bannerImage == null) {
      showSnackBar(context, "Please select a banner image");
      return;
    }

    final banner = BannerItem(
      name: nameCtrl.text.trim(),
      title: bannerTitleCtrl.text.trim(),
      description: descCtrl.text.trim(),
      isActive: true,
      bannerUrl: link.text.trim(),
      id: '',
      bannerImageUrl: '',
      status: '',
      isApproved: true,
      lastUpdatedBy: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      bannerId: '',
    );

    Loader.show();

    try {
      final fields = {
        'name': banner.name,
        'title': banner.title,
        'description': banner.description,
        'isActive': banner.isActive.toString(),
        'linkType': linkType,
        if (linkType == 'External') 'bannerUrl': banner.bannerUrl,
        if (linkType == 'Internal') 'linkRef': link.text.trim(),
      };

      final response = await HttpClientHelper.postWithBearerMultipart(
        ApiConstants.createBanner,
        AuthDataHelper.getToken(),
        fields: fields,
        file: bannerImage,
        isBanner: true,
      );

      Loader.hide();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Banner create response: ${response.data}');

        var createdBanner = BannerResponseParser.parseBannerFromResponse(
          response.data,
        );
        createdBanner ??= banner.copyWith(
          bannerId: banner.bannerId,
          updatedAt: DateTime.now(),
        );

        if (bannerImage != null && createdBanner.bannerId.isNotEmpty) {
          BannerLocalImageStore.set(
            createdBanner.bannerId,
            bannerImage!.path,
          );
        }

        BannerRefreshController.ensureRegistered().notifyChanged(
          updatedBanner: createdBanner,
        );
        showSnackBar(context, response.message ?? "");
        Navigator.pop(context, createdBanner);
      } else {
        showSnackBar(context, "Error: ${response.message}");
      }
    } catch (e) {
      Loader.hide();
      showSnackBar(context, "Something went wrong: $e");
    }
  }

  bool _validateForm() {
    if (bannerTitleCtrl.text.trim().isEmpty) {
      showSnackBar(context, "Banner title is required");
      return false;
    }

    if (nameCtrl.text.trim().isEmpty) {
      showSnackBar(context, "Banner name is required");
      return false;
    }

    if (descCtrl.text.trim().isEmpty) {
      showSnackBar(context, "Description is required");
      return false;
    }

    if (linkType == 'External') {
      if (link.text.trim().isEmpty) {
        showSnackBar(context, "Link is required");
        return false;
      }
      if (!_isValidUrl(link.text.trim())) {
        showSnackBar(context, "Please enter a valid link");
        return false;
      }
    } else if (linkType == 'Internal') {
      if (selectedInternalPage == null || selectedInternalPage!.isEmpty) {
        showSnackBar(context, "Please select an internal page");
        return false;
      }
    }

    // Image validation for new banner
    if (!isEdit && bannerImage == null) {
      showSnackBar(context, "Please select a banner image");
      return false;
    }

    // For edit mode, check if there's either a new image or existing image
    if (isEdit &&
        bannerImage == null &&
        (existingBannerImageUrl == null || existingBannerImageUrl!.isEmpty)) {
      showSnackBar(context, "Please select a banner image");
      return false;
    }

    // Image size validation (max 2MB) - only if new image selected
    if (bannerImage != null) {
      final sizeInMb = bannerImage!.lengthSync() / (1024 * 1024);
      if (sizeInMb > 2) {
        showSnackBar(context, "Image size must be less than 2 MB");
        return false;
      }
    }

    return true;
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Label with required asterisk
  Widget _requiredLabel(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        const Text(
          '*',
          style: TextStyle(
            color: Colors.red,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// ---------------- Input Field ----------------
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
