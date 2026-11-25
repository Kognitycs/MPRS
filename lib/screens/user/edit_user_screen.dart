import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/core/utils/validation_utils.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/model/add_user_response.dart';
import 'package:mprs_android/model/all_users_response.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/edit_user_response.dart';
import 'package:mprs_android/screens/user/user_cache.dart';
import 'package:mprs_android/service/admin_user_account_tag_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/sales_account_directory.dart';
import 'package:mprs_android/service/salesperson_directory.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import '../../core/utils/common_data.dart';

class EditUserScreen extends StatefulWidget {
  final UserData? user;
  const EditUserScreen({super.key, this.user});
  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController alternateMobileController =
      TextEditingController();
  final TextEditingController alternateEmailController =
      TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController landlineNumberController =
      TextEditingController();
  final TextEditingController extensionController = TextEditingController();
  final TextEditingController gstinController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController mobileNumberController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController branchNameController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool get isRoleEditable {
    final roles = getAllowedUserRoles(userRoleType);
    final otherRoles = roles.where((r) => r != (userRoleType ?? "")).toList();
    return otherRoles.isNotEmpty;
  }

  String? selectedCountry;
  String? selectedRegion;
  String? emailError;
  String? companyNameError;
  String? firstNameError;
  String? lastNameError;
  String? gstinError;
  String? imageError;

  final countries = CountryUtils.getAllCountries();
  final region = CountryUtils.getRegion();
  final indianStates = CountryUtils.getIndianStates();

  static const List<String> _accountTypeOptions = [
    'Shipper',
    'Agent/Forwarder',
    'Consignee',
    'Overseas Agent',
  ];

  String? _selectedAccountType;
  String? _salespersonState;
  String? _selectedSalespersonId;
  String? _storedSalespersonName;
  List<SalespersonOption> _salespersons = [];
  bool _salespersonsLoading = false;

  String? userRoleType = "External";
  String? userRoleTypeError;
  File? _pickedImage;

  List<SalesAccountChoice> _sfAccounts = [];
  bool _sfAccountsLoading = false;
  String? _taggedSalesforceAccountId;
  String? _initialTaggedAccountId;
  String? _taggedAccountDisplayName;
  String? _sfAccountsError;
  bool _taggedAccountHydrating = false;

  bool get _isExternalFamily {
    final role = (userRoleType ?? '').trim();
    return role == 'External' || role == 'VIP' || role == 'VVIP';
  }

  @override
  void initState() {
    super.initState();
    _initUserData();
    if (_isExternalFamily) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _hydrateUserFromAdminList();
        final state = _salespersonState?.trim() ?? '';
        if (state.isNotEmpty) {
          await _loadSalespersons(state);
        }
      });
    }
    if (userRoleType == 'Internal') {
      _taggedSalesforceAccountId = _accountIdFromUser(widget.user);
      _initialTaggedAccountId = _taggedSalesforceAccountId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _hydrateTaggedAccountForSelectDropdown();
        await _loadInternalOwnerAccounts(preserveTagIfMissingFromApi: true);
      });
    }
  }

  String? _accountIdFromUser(UserData? user) {
    final id = user?.accountId?.trim() ?? '';
    if (id.isEmpty) return null;
    return id;
  }

  bool _sameSalesforceAccountId(String? a, String? b) {
    final x = a?.trim().toLowerCase() ?? '';
    final y = b?.trim().toLowerCase() ?? '';
    if (x.isEmpty || y.isEmpty) return x == y;
    if (x == y) return true;
    final shortX = x.length >= 15 ? x.substring(0, 15) : x;
    final shortY = y.length >= 15 ? y.substring(0, 15) : y;
    return shortX == shortY;
  }

  Future<String?> _fetchAccountIdFromAdminList() async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) return null;

    final targetUserId =
        widget.user?.userId?.trim() ?? widget.user?.id?.trim() ?? '';
    final email = widget.user?.email?.trim() ?? '';
    final mobile = widget.user?.mobile?.trim() ?? '';

    final queries = <String>[
      if (email.isNotEmpty)
        '${ApiConstants.allUsers}?page=1&limit=50&keyword=${Uri.encodeQueryComponent(email)}',
      if (mobile.isNotEmpty)
        '${ApiConstants.allUsers}?page=1&limit=50&keyword=${Uri.encodeQueryComponent(mobile)}',
      if (targetUserId.isNotEmpty)
        '${ApiConstants.allUsers}?page=1&limit=50&keyword=${Uri.encodeQueryComponent(targetUserId)}',
    ];

    for (final url in queries) {
      try {
        final response = await HttpClientHelper.getWithBearer(url, token);
        if (response.statusCode < 200 || response.statusCode >= 300) continue;

        final data = AllUsersResponse.fromJson(jsonDecode(response.data));
        for (final row in data.data) {
          final matches =
              targetUserId.isNotEmpty
                  ? (row.userId?.trim() == targetUserId ||
                      row.id?.trim() == targetUserId)
                  : (email.isNotEmpty &&
                          row.email?.trim().toLowerCase() ==
                              email.toLowerCase()) ||
                      (mobile.isNotEmpty && row.mobile?.trim() == mobile);
          if (matches) {
            final found = _accountIdFromUser(row);
            if (found != null) return found;
          }
        }
      } catch (e) {
        debugPrint('EditUser: fetch accountId: $e');
      }
    }
    return null;
  }

  Future<void> _hydrateTaggedAccountForSelectDropdown() async {
    if (userRoleType != 'Internal') return;

    setState(() => _taggedAccountHydrating = true);

    var id = _accountIdFromUser(widget.user) ?? _taggedSalesforceAccountId;
    id ??= UserCache.localAccountId(
      userId: widget.user?.userId,
      mongoId: widget.user?.id,
    );
    id ??= await _fetchAccountIdFromAdminList();

    if (!mounted) return;

    if (id == null) {
      setState(() {
        _taggedSalesforceAccountId = null;
        _taggedAccountDisplayName = null;
        _taggedAccountHydrating = false;
      });
      return;
    }

    final accountId = id;
    final name = await SalesAccountDirectory.resolveAccountDisplayName(
      accountId,
    );
    if (!mounted) return;

    setState(() {
      _taggedSalesforceAccountId = accountId;
      _initialTaggedAccountId ??= accountId;
      _taggedAccountDisplayName = name;
      _taggedAccountHydrating = false;
      if (!_sfAccounts.any((c) => _sameSalesforceAccountId(c.id, accountId))) {
        _sfAccounts = [
          SalesAccountChoice(
            id: accountId,
            name: name.isEmpty ? 'Tagged account' : name,
            fromApi: true,
          ),
          ..._sfAccounts,
        ];
      }
    });

    await _loadInternalOwnerAccounts(preserveTagIfMissingFromApi: true);
  }

  void _initUserData() {
    _applyUserToForm(widget.user!);
  }

  void _applyUserToForm(UserData userData) {
    userNameController.text = userData.username ?? '';
    firstNameController.text = userData.firstName ?? '';
    lastNameController.text = userData.lastName ?? '';
    designationController.text = userData.designation ?? '';
    departmentController.text = userData.department ?? '';
    emailController.text = userData.email ?? '';
    alternateEmailController.text = userData.alternateEmail ?? '';
    mobileNumberController.text = userData.mobile ?? '';
    alternateMobileController.text = userData.alternateMobile ?? '';
    gstinController.text = userData.gstin ?? '';
    landlineNumberController.text = userData.landlineNumber ?? '';
    extensionController.text = userData.extentionNumber ?? '';
    companyNameController.text = userData.companyName ?? '';
    userRoleType = userData.userType ?? '';

    branchNameController.text = userData.branchName ?? '';
    streetController.text =
        (userData.street ?? '').trim().isNotEmpty
            ? userData.street!.trim()
            : (userData.address ?? '');
    cityController.text = userData.city ?? '';
    postalCodeController.text = userData.postalCode ?? '';
    _selectedAccountType = userData.accountType;
    _selectedSalespersonId = userData.salespersonId;
    _storedSalespersonName = userData.salespersonName;
    _salespersonState = CountryUtils.displayIndianStateName(
      userData.state ?? userData.region,
    );
    selectedCountry = CountryUtils.displayCountryName(userData.country);

    if (_isExternalFamily) {
      addressController.text =
          (userData.address ?? '').trim().isNotEmpty
              ? userData.address!
              : streetController.text;
      selectedRegion = null;
    } else {
      addressController.text = userData.address ?? '';
      selectedRegion = userData.region;
      if (selectedCountry == null) {
        selectedCountry = userData.country;
      }
    }
  }

  Future<void> _hydrateUserFromAdminList() async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) return;

    final targetUserId =
        widget.user?.userId?.trim() ?? widget.user?.id?.trim() ?? '';
    final email = widget.user?.email?.trim() ?? '';
    final mobile = widget.user?.mobile?.trim() ?? '';

    final queries = <String>[
      if (email.isNotEmpty)
        '${ApiConstants.allUsers}?page=1&limit=50&keyword=${Uri.encodeQueryComponent(email)}',
      if (mobile.isNotEmpty)
        '${ApiConstants.allUsers}?page=1&limit=50&keyword=${Uri.encodeQueryComponent(mobile)}',
      if (targetUserId.isNotEmpty)
        '${ApiConstants.allUsers}?page=1&limit=50&keyword=${Uri.encodeQueryComponent(targetUserId)}',
    ];

    for (final url in queries) {
      try {
        final response = await HttpClientHelper.getWithBearer(url, token);
        if (response.statusCode < 200 || response.statusCode >= 300) continue;

        final data = AllUsersResponse.fromJson(jsonDecode(response.data));
        for (final row in data.data) {
          final matches =
              targetUserId.isNotEmpty
                  ? (row.userId?.trim() == targetUserId ||
                      row.id?.trim() == targetUserId)
                  : (email.isNotEmpty &&
                          row.email?.trim().toLowerCase() ==
                              email.toLowerCase()) ||
                      (mobile.isNotEmpty && row.mobile?.trim() == mobile);
          if (matches) {
            if (!mounted) return;
            setState(() => _applyUserToForm(row));
            final state = _salespersonState?.trim() ?? '';
            if (state.isNotEmpty) {
              await _loadSalespersons(state);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('EditUser hydrate: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked == null) {
        setState(() {
          imageError = null;
        });
        return;
      }

      final File imageFile = File(picked.path);

      // Validate file type
      final String extension = picked.path.split('.').last.toLowerCase();
      const List<String> allowedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!allowedFormats.contains(extension)) {
        setState(() {
          imageError = 'Invalid image format. Allowed: JPG, PNG, GIF, WebP';
        });
        return;
      }

      // Validate file size
      final int imageSize = await imageFile.length();
      const int maxImageSize = 1 * 1024 * 1024; // 1 MB
      if (imageSize > maxImageSize) {
        setState(() {
          imageError =
              'Image size exceeds 1 MB limit. Current size: ${(imageSize / (1024 * 1024)).toStringAsFixed(2)} MB';
        });
        return;
      }

      setState(() {
        _pickedImage = imageFile;
        imageError = null;
      });
    } catch (e) {
      setState(() {
        imageError = 'Error selecting image: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(title: "Edit User"),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child:
                                  _pickedImage != null
                                      ? Image.file(
                                        _pickedImage!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                      : _buildProfileImage(),
                            ),
                          ),
                        ),

                        // Edit button
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.main,
                              ),
                              child: Image.asset(
                                'assets/icons/ic_edit_image.png',
                                width: 30,
                                height: 30,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Show image error if present
              if (imageError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            imageError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              buildUserTextField(
                label: "First Name",
                isRequired: true,
                hint: "Enter your First Name",
                controller: firstNameController,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: firstNameError,
              ),
              buildUserTextField(
                label: "Last Name",
                hint: "Enter your Last Name",
                controller: lastNameController,
                isRequired: true,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: lastNameError,
              ),
              buildUserTextField(
                label: "Mobile Number",
                hint: "Enter your Mobile Number",
                isRequired: true,
                editable: false,
                controller: mobileNumberController,
                inputType: TextInputType.phone,
              ),
              buildUserTextField(
                label: "Email",
                hint: "Enter your Email",
                controller: emailController,
                isRequired: true,
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: emailError,
              ),
              buildUserTextField(
                label: "Company Name",
                hint: "Enter your Company Name",
                controller: companyNameController,
                isRequired: true,
                editable: false,
                onChanged: (value) {},
                errorText: companyNameError,
              ),

              if (_isExternalFamily) ...[
                buildRoundedDropdownWithArrow(
                  label: 'Account type',
                  hint: 'Select account type',
                  items: _accountTypeItems(),
                  value:
                      _selectedAccountType != null &&
                              _accountTypeItems().contains(_selectedAccountType)
                          ? _selectedAccountType
                          : null,
                  onChanged: (value) {
                    setState(() => _selectedAccountType = value);
                  },
                  context: context,
                ),
                buildUserTextField(
                  label: 'Branch name',
                  hint: 'Branch name',
                  controller: branchNameController,
                  onChanged: (_) {},
                ),
                buildUserTextField(
                  label: 'Street',
                  hint: 'Street address',
                  controller: streetController,
                  inputType: TextInputType.streetAddress,
                  onChanged: (_) {},
                ),
                buildUserTextField(
                  label: 'City',
                  hint: 'City',
                  controller: cityController,
                  onChanged: (_) {},
                ),
                buildUserTextField(
                  label: 'Postal code',
                  hint: 'Postal code',
                  controller: postalCodeController,
                  inputType: TextInputType.number,
                  onChanged: (_) {},
                ),
                buildRoundedDropdown(
                  label: 'Country',
                  hint: 'Select country',
                  items: _countryDropdownItems(),
                  value:
                      selectedCountry != null &&
                              _countryDropdownItems().contains(selectedCountry)
                          ? selectedCountry
                          : null,
                  onChanged: (value) {
                    setState(() => selectedCountry = value);
                  },
                  context: context,
                ),
              ],

              buildUserTextField(
                label: "Designation",
                hint: "Enter your designation (Optional)",
                controller: designationController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),
              buildUserTextField(
                label: "department",
                hint: "Enter your Department (Optional)",
                controller: departmentController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              buildUserTextField(
                label: "Alternate Email",
                hint: "Enter your alternate email (Optional)",
                controller: alternateEmailController,
                inputType: TextInputType.emailAddress,
                onChanged: (value) {},
              ),

              buildUserTextField(
                label: "Alternate Mobile Number",
                hint: "Enter your alternate mobile number (Optional)",
                controller: alternateMobileController,
                inputType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {},
              ),
              buildUserTextField(
                label:
                    "Gstin", // Arnima - allow both capital and small letters in gstin and later captial the whole string
                hint:
                    (userRoleType == "External" ||
                            userRoleType == "VIP" ||
                            userRoleType == "VVIP")
                        ? "Enter your GSTIN"
                        : "Enter your GSTIN (Optional)",
                controller: gstinController,
                isRequired:
                    (userRoleType == "External" ||
                        userRoleType == "VIP" ||
                        userRoleType == "VVIP"),
                errorText: gstinError,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              buildUserTextField(
                label: "Landline Number",
                hint: "Enter your landline Number (Optional)",
                controller: landlineNumberController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              buildUserTextField(
                label: "Extension Number",
                hint: "Enter your Extension Number (Optional)",
                controller: extensionController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              if (!_isExternalFamily) ...[
                buildUserTextField(
                  label: "Address",
                  hint: "Enter your Address (Optional)",
                  controller: addressController,
                  onChanged: (value) {
                    print("User typed: $value");
                  },
                ),
                buildRoundedDropdown(
                  label: "Country",
                  hint: "Select Country (Optional)",
                  items: countries,
                  value: selectedCountry,
                  onChanged: (value) {
                    setState(() {
                      selectedCountry = value;
                    });
                  },
                  context: context,
                ),
                buildRoundedDropdown(
                  label: "Region",
                  hint: "Select Region (Optional)",
                  items: region,
                  value: selectedRegion,
                  onChanged: (value) {
                    setState(() {
                      selectedRegion = value;
                    });
                  },
                  context: context,
                ),
              ],

              if (userRoleType == 'External') ...[
                const SizedBox(height: 16),
                _buildExternalSalespersonSection(),
              ],

              buildRoundedDropdownWithArrow(
                label: "Select role",
                hint: "Select role",
                isRequired: true,
                items: getAllowedUserRoles(userRoleType),
                value: userRoleType,
                errorText: userRoleTypeError,
                onChanged:
                    isRoleEditable
                        ? (value) async {
                          if (value == null || value == userRoleType) return;

                          setState(() {
                            userRoleType = value;
                            if (value == 'Internal') {
                              _initialTaggedAccountId ??=
                                  _accountIdFromUser(widget.user);
                              _taggedSalesforceAccountId =
                                  _initialTaggedAccountId;
                            } else {
                              _taggedSalesforceAccountId = null;
                              _initialTaggedAccountId = null;
                              _taggedAccountDisplayName = null;
                              _sfAccounts = [];
                            }
                          });

                          if (value == 'Internal') {
                            await _hydrateTaggedAccountForSelectDropdown();
                            await _loadInternalOwnerAccounts(
                              preserveTagIfMissingFromApi: true,
                            );
                          }
                        }
                        : null,
                context: context,
              ),

              if (userRoleType == 'Internal') ...[
                const SizedBox(height: 16),
                _buildInternalAccountSection(),
              ],

              const SizedBox(height: 30),

              MainButton(
                text: 'Save Changes',
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

  List<String> _accountTypeItems() {
    final items = List<String>.from(_accountTypeOptions);
    final current = _selectedAccountType?.trim();
    if (current != null && current.isNotEmpty && !items.contains(current)) {
      items.insert(0, current);
    }
    return items;
  }

  List<String> _countryDropdownItems() {
    final items = List<String>.from(countries);
    final current = selectedCountry?.trim();
    if (current != null && current.isNotEmpty && !items.contains(current)) {
      items.insert(0, current);
    }
    return items;
  }

  List<String> _indianStateItems() {
    final items = List<String>.from(indianStates);
    final current = _salespersonState?.trim();
    if (current != null && current.isNotEmpty && !items.contains(current)) {
      items.insert(0, current);
    }
    return items;
  }

  Widget _buildExternalSalespersonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildRoundedDropdown(
          label: 'State',
          hint: 'Select state',
          items: _indianStateItems(),
          value:
              _salespersonState != null &&
                      _indianStateItems().contains(_salespersonState)
                  ? _salespersonState
                  : null,
          onChanged: (value) {
            setState(() {
              _salespersonState = value;
              _selectedSalespersonId = null;
              _salespersons = [];
            });
            if (value != null && value.trim().isNotEmpty) {
              _loadSalespersons(value);
            }
          },
          context: context,
        ),
        if (_salespersonsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_salespersonState != null && _salespersonState!.isNotEmpty)
          buildRoundedDropdown(
            label: 'Sales person',
            hint:
                _salespersons.isEmpty
                    ? 'No sales persons for this state'
                    : 'Select sales person',
            items: _salespersons.map((e) => e.name).toList(),
            value: _salespersonLabelForId(_selectedSalespersonId),
            enabled: _salespersons.isNotEmpty,
            onChanged: (value) {
              setState(() {
                _selectedSalespersonId = _salespersonIdForName(value);
              });
            },
            context: context,
          ),
      ],
    );
  }

  String? _salespersonLabelForId(String? id) {
    if (id == null) return null;
    for (final p in _salespersons) {
      if (p.id == id) return p.name;
    }
    final stored = _storedSalespersonName?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  String? _salespersonIdForName(String? name) {
    if (name == null) return null;
    for (final p in _salespersons) {
      if (p.name == name) return p.id;
    }
    if (name == _storedSalespersonName &&
        _selectedSalespersonId != null &&
        _selectedSalespersonId!.isNotEmpty) {
      return _selectedSalespersonId;
    }
    return null;
  }

  Future<void> _loadSalespersons(String state) async {
    setState(() => _salespersonsLoading = true);
    final list = await SalespersonDirectory.loadByState(state);
    if (!mounted) return;

    final merged = <SalespersonOption>[...list];
  final storedId = _selectedSalespersonId?.trim();
    if (storedId != null &&
        storedId.isNotEmpty &&
        !merged.any((e) => e.id == storedId)) {
      merged.insert(
        0,
        SalespersonOption(
          id: storedId,
          name: _storedSalespersonName?.trim().isNotEmpty == true
              ? _storedSalespersonName!.trim()
              : 'Assigned sales person',
          state: state,
        ),
      );
    }

    setState(() {
      _salespersonsLoading = false;
      _salespersons = merged;
      if (_selectedSalespersonId != null &&
          !merged.any((e) => e.id == _selectedSalespersonId)) {
        _selectedSalespersonId = null;
      }
    });
  }

  Widget _buildInternalAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_sfAccountsLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (_sfAccountsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _sfAccountsError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        buildRoundedDropdown(
          label: 'Select account',
          hint:
              _taggedAccountHydrating
                  ? 'Loading tagged account…'
                  : _sfAccountsLoading
                  ? 'Loading accounts…'
                  : 'Select account (Optional)',
          items: _accountDropdownItems(),
          value: _taggedAccountLabel(),
          enabled: !_sfAccountsLoading && !_taggedAccountHydrating,
          loadItemsOnOpen: _loadAccountDropdownItems,
          onChanged: (value) {
            if (value == null || value == '— None —') {
              setState(() {
                _taggedSalesforceAccountId = null;
                _taggedAccountDisplayName = null;
              });
              return;
            }
            final resolvedId = _resolveTaggedAccountIdForLabel(value);
            if (resolvedId == null) {
              showSnackBar(
                context,
                'Could not resolve that account. Open the list and pick again.',
              );
              return;
            }
            setState(() {
              _taggedSalesforceAccountId = resolvedId;
              _taggedAccountDisplayName = value;
            });
          },
          context: context,
        ),
        const Text(
          'Tap to load accounts for this user’s email (POST). Optional tag.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.lightGrey,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  List<String> _accountDropdownItems() {
    if (_sfAccounts.isEmpty) {
      return const ['— None —'];
    }
    return ['— None —', ..._sfAccounts.map((e) => e.name)];
  }

  Future<List<String>> _loadAccountDropdownItems() async {
    await _loadInternalOwnerAccounts();
    return _accountDropdownItems();
  }

  String? _taggedAccountLabel() {
    if (_taggedAccountHydrating) return null;
    if (_taggedSalesforceAccountId == null) return null;
    for (final row in _sfAccounts) {
      if (_sameSalesforceAccountId(row.id, _taggedSalesforceAccountId)) {
        return row.name;
      }
    }
    final cached = _taggedAccountDisplayName?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    return null;
  }

  String? _resolveTaggedAccountIdForLabel(String label) {
    final row = SalesAccountDirectory.findChoiceByDisplayName(
      _sfAccounts,
      label,
    );
    if (row == null) return null;
    return SalesAccountDirectory.canonicalAccountIdForAdminTag(
      row.id,
      choices: _sfAccounts,
    );
  }

  String? _canonicalTagIdForApi(String? raw) {
    return SalesAccountDirectory.canonicalAccountIdForAdminTag(
      raw,
      choices: _sfAccounts,
    );
  }

  static String _editTrim(String? v) => v?.trim() ?? '';

  String _mobileForAdminApis() {
    return mobileNumberController.text.trim().isNotEmpty
        ? mobileNumberController.text.trim()
        : (widget.user?.mobile ?? '').trim();
  }

  bool _internalAccountTagChanged() {
    final newId = _canonicalTagIdForApi(_taggedSalesforceAccountId);
    final oldId = _canonicalTagIdForApi(_initialTaggedAccountId);
    if (newId == null && oldId == null) return false;
    if (newId != null &&
        oldId != null &&
        SalesAccountDirectory.sameSalesforceAccountId(newId, oldId)) {
      return false;
    }
    return true;
  }

  bool _hasProfileFieldChanges() {
    final u = widget.user;
    if (u == null) return true;
    if (_pickedImage != null) return true;
    if (_editTrim(userRoleType) != _editTrim(u.userType)) return true;

    final country = selectedCountry ?? u.country;
    final region = selectedRegion ?? u.region;

    return _editTrim(firstNameController.text) != _editTrim(u.firstName) ||
        _editTrim(lastNameController.text) != _editTrim(u.lastName) ||
        _editTrim(userNameController.text) != _editTrim(u.username) ||
        _editTrim(emailController.text) != _editTrim(u.email) ||
        _editTrim(alternateEmailController.text) != _editTrim(u.alternateEmail) ||
        _editTrim(mobileNumberController.text) != _editTrim(u.mobile) ||
        _editTrim(alternateMobileController.text) != _editTrim(u.alternateMobile) ||
        _editTrim(designationController.text) != _editTrim(u.designation) ||
        _editTrim(departmentController.text) != _editTrim(u.department) ||
        _editTrim(companyNameController.text) != _editTrim(u.companyName) ||
        _editTrim(landlineNumberController.text) != _editTrim(u.landlineNumber) ||
        _editTrim(extensionController.text) != _editTrim(u.extentionNumber) ||
        _editTrim(addressController.text) != _editTrim(u.address) ||
        _editTrim(country) != _editTrim(u.country) ||
        _editTrim(region) != _editTrim(u.region) ||
        _editTrim(gstinController.text) != _editTrim(u.gstin);
  }

  bool _isAccountTagOnlySave() {
    return userRoleType == 'Internal' &&
        _pickedImage == null &&
        !_hasProfileFieldChanges() &&
        _internalAccountTagChanged();
  }

  Future<bool> _commitRoleChangeIfNeeded() async {
    final original = widget.user?.userType?.trim() ?? '';
    final desired = (userRoleType ?? '').trim();
    if (original == desired) return true;

    final mobile = _mobileForAdminApis();
    if (mobile.isEmpty) {
      if (mounted) {
        showSnackBar(
          context,
          'Mobile number is required before changing role.',
        );
      }
      return false;
    }

    final response = await HttpClientHelper.patchWithBearer(
      ApiConstants.changeUserType,
      AuthDataHelper.getToken(),
      body: jsonEncode({
        'userNumber': mobile,
        'newUserType': desired,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }

    if (mounted) {
      String fallback = 'Could not change role';
      try {
        fallback = AddUserResponse.fromJson(
          jsonDecode(response.data),
        ).message ?? fallback;
      } catch (_) {}
      showSnackBar(
        context,
        parseApiErrorMessage(response.data, fallback: fallback),
      );
    }
    return false;
  }

  Future<void> _loadInternalOwnerAccounts({
    bool preserveTagIfMissingFromApi = false,
  }) async {
    if (!(await checkInternetConnection())) {
      if (mounted) showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    final previousTag = _taggedSalesforceAccountId;
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _sfAccountsError = 'No email on this user');
      return;
    }

    setState(() {
      _sfAccountsLoading = true;
      _sfAccountsError = null;
    });

    final result = await SalesAccountDirectory.loadForAdminAccountPicker(
      internalUserEmail: email,
    );

    if (!mounted) return;

    var choices = List<SalesAccountChoice>.from(result.choices);
    final tag = previousTag ?? _taggedSalesforceAccountId;
    if (tag != null &&
        !choices.any((c) => _sameSalesforceAccountId(c.id, tag))) {
      final name = await SalesAccountDirectory.resolveAccountDisplayName(tag);
      choices.add(SalesAccountChoice(id: tag, name: name, fromApi: true));
    }

    if (!mounted) return;
    setState(() {
      _sfAccountsLoading = false;
      _sfAccounts = choices;
      _sfAccountsError =
          choices.isEmpty
              ? (result.errorMessage ?? 'No accounts found for this email')
              : null;
      if (tag != null) {
        final matched =
            choices.where((c) => _sameSalesforceAccountId(c.id, tag)).toList();
        if (matched.isNotEmpty) {
          final row = matched.first;
          _taggedSalesforceAccountId =
              SalesAccountDirectory.canonicalAccountIdForAdminTag(
                row.id,
                choices: choices,
              ) ??
              row.id;
          _taggedAccountDisplayName = row.name;
        } else if (preserveTagIfMissingFromApi) {
          final fallbackName = _taggedAccountDisplayName?.trim() ?? '';
          if (fallbackName.isNotEmpty &&
              !choices.any((c) => _sameSalesforceAccountId(c.id, tag))) {
            choices.add(
              SalesAccountChoice(id: tag, name: fallbackName, fromApi: true),
            );
          }
          _sfAccounts = choices;
          _taggedSalesforceAccountId = tag;
        }
      }
    });
  }

  List<String> getAllowedUserRoles(String? userType) {
    final editorIsAdmin =
        AuthDataHelper.getUserType().trim().toLowerCase() == 'admin';
    if (editorIsAdmin) {
      final roles = List<String>.from(addUserRoles);
      final current = userType?.trim();
      if (current != null && current.isNotEmpty && !roles.contains(current)) {
        roles.insert(0, current);
      }
      return roles;
    }

    // Compute allowed role changes for the current user type
    List<String> allowedChanges;
    switch (userType) {
      case "Admin":
        allowedChanges = ["Internal"];
        break;
      case "Internal":
        allowedChanges = ["Admin"];
        break;
      case "External":
        allowedChanges = ["VIP", "VVIP"];
        break;
      case "VIP":
        allowedChanges = ["External", "VVIP"];
        break;
      case "VVIP":
        allowedChanges = ["External", "VIP"];
        break;
      default:
        allowedChanges = [];
    }

    // Ensure dropdown items include current role first, then other allowed roles
    final List<String> roles = [];
    if (userType != null && userType.isNotEmpty) roles.add(userType);
    for (final r in allowedChanges) {
      if (!roles.contains(r)) roles.add(r);
    }
    return roles;
  }

  Widget _buildProfileImage() {
    final url = widget.user?.profileImageUrl?.trim() ?? '';
    if (url.isNotEmpty && url.startsWith('http')) {
      return FadeInImage.assetNetwork(
        placeholder: 'assets/icons/default_ic_user.png',
        image: url,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) => _defaultProfileIcon(),
      );
    }
    return _defaultProfileIcon();
  }

  Widget _defaultProfileIcon() {
    return Image.asset(
      'assets/icons/default_ic_user.png',
      width: 120,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  String? _normalizedTaggedAccountId(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  String _editedUserMongoId() {
    return widget.user?.userId?.trim() ?? widget.user?.id?.trim() ?? '';
  }

  Map<String, String> _adminProfileUpdateFields(
    UserData user, {
    required String mobile,
    required String username,
  }) {
    final deviceType =
        widget.user?.deviceType?.trim().isNotEmpty == true
            ? widget.user!.deviceType!.trim()
            : (Platform.isIOS ? 'ios' : 'android');
    final isActive = widget.user?.isActive ?? true;
    final termsAccepted = widget.user?.termsAccepted ?? true;
    final activeRms = widget.user?.activeRmsUser ?? true;

    return {
      'username': username,
      'mobile': mobile,
      'firstName': (user.firstName ?? '').trim(),
      'lastName': (user.lastName ?? '').trim(),
      'designation': (user.designation ?? '').trim(),
      'department': (user.department ?? '').trim(),
      'email': (user.email ?? '').trim(),
      'alternateEmail': (user.alternateEmail ?? '').trim(),
      'alternateMobile': (user.alternateMobile ?? '').trim(),
      'landlineNumber': (user.landlineNumber ?? '').trim(),
      'extentionNumber': (user.extentionNumber ?? '').trim(),
      'address': (user.address ?? '').trim(),
      'country': CountryUtils.salesforceCountryCode(user.country),
      'companyName': (user.companyName ?? '').trim(),
      'region':
          _isExternalFamily
              ? CountryUtils.salesforceIndianStateCode(_salespersonState)
              : (user.region ?? '').trim(),
      'gstin': (user.gstin ?? '').trim(),
      if (_isExternalFamily) ...{
        if (branchNameController.text.trim().isNotEmpty)
          'branchName': branchNameController.text.trim(),
        if (streetController.text.trim().isNotEmpty)
          'street': streetController.text.trim(),
        if (cityController.text.trim().isNotEmpty)
          'city': cityController.text.trim(),
        if (postalCodeController.text.trim().isNotEmpty)
          'postalCode': postalCodeController.text.trim(),
        if ((_salespersonState ?? '').trim().isNotEmpty)
          'state': CountryUtils.salesforceIndianStateCode(_salespersonState),
        if (_selectedAccountType != null &&
            _selectedAccountType!.trim().isNotEmpty)
          'accountType': _selectedAccountType!.trim(),
        if (_selectedSalespersonId != null &&
            _selectedSalespersonId!.trim().isNotEmpty)
          'salespersonId': _selectedSalespersonId!.trim(),
      },
      'termsAccepted': termsAccepted ? 'true' : 'false',
      'Active_RMS_User': activeRms ? 'true' : 'false',
      'isActive': isActive ? 'true' : 'false',
      'deviceType': deviceType,
    };
  }

  /// Profile PATCH Joi does not accept `accountId` with other fields; tag alone.
  Future<bool> _syncInternalAccountTag() async {
    final userId = _editedUserMongoId();
    if (userId.isEmpty) return false;

    final newId = _canonicalTagIdForApi(_taggedSalesforceAccountId);
    final oldId = _canonicalTagIdForApi(_initialTaggedAccountId);
    if (newId != null &&
        oldId != null &&
        SalesAccountDirectory.sameSalesforceAccountId(newId, oldId)) {
      return true;
    }
    if (newId == null && oldId == null) return true;

    final mobile = _mobileForAdminApis();
    final username =
        userNameController.text.trim().isNotEmpty
            ? userNameController.text.trim()
            : (mobile.isNotEmpty
                ? mobile
                : (widget.user?.username ?? '').trim());
    final result = await AdminUserAccountTagService.syncForUser(
      userId: widget.user?.userId?.trim() ?? userId,
      mongoId: widget.user?.id,
      accountId: newId,
      accountChoices: _sfAccounts,
      identity: AdminAccountTagIdentity(
        mobile: mobile,
        username: username,
        email: emailController.text.trim(),
      ),
    );
    if (result.ok) {
      UserCache.rememberAccountTag(
        userId: widget.user?.userId,
        mongoId: widget.user?.id,
        accountId: newId ?? '',
      );
      return true;
    }
    if (mounted) {
      showSnackBar(
        context,
        'Error: ${result.errorMessage ?? 'Could not update tagged account'}',
      );
    }
    return false;
  }

  Future<void> saveUser() async {
    if (!validateFields()) return;

    if (userRoleType == 'Internal') {
      final label = _taggedAccountLabel();
      final id = _normalizedTaggedAccountId(_taggedSalesforceAccountId);
      if (label != null && label != '— None —' && id == null) {
        showSnackBar(
          context,
          'Selected account is invalid. Open the list and choose again.',
        );
        return;
      }
    }

    // Check for image errors before saving
    if (imageError != null) {
      showSnackBar(context, imageError!);
      return;
    }

    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    final editedUserId = _editedUserMongoId();
    if (editedUserId.isEmpty) {
      showSnackBar(context, 'Cannot save: user id is missing.');
      return;
    }

    try {
      Loader.show();
      if (!(await _commitRoleChangeIfNeeded())) {
        Loader.hide();
        return;
      }

      final mobile = _mobileForAdminApis();
      final username =
          userNameController.text.trim().isNotEmpty
              ? userNameController.text.trim()
              : (mobile.isNotEmpty
                  ? mobile
                  : (widget.user?.username ?? '').trim());
      if (mobile.isEmpty || username.isEmpty) {
        Loader.hide();
        showSnackBar(context, 'Mobile number is required to update this user.');
        return;
      }

      final updateUrl = '${ApiConstants.updateUser}/$editedUserId';

      if (_isAccountTagOnlySave()) {
        Loader.hide();
        showSnackBar(context, 'Updating tagged account...');
        Loader.show();
        final tagOk = await _syncInternalAccountTag();
        Loader.hide();
        if (!mounted) return;
        if (tagOk) {
          _initialTaggedAccountId = _taggedSalesforceAccountId;
          showSnackBar(context, 'Tagged account updated.');
          Navigator.pop(context, true);
        }
        return;
      }

      final user = UserData(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        email: emailController.text.trim(),
        alternateEmail: alternateEmailController.text.trim(),
        alternateMobile: alternateMobileController.text.trim(),
        designation: designationController.text.trim(),
        department: departmentController.text.trim(),
        companyName: companyNameController.text.trim(),
        landlineNumber: landlineNumberController.text.trim(),
        extentionNumber: extensionController.text.trim(),
        address:
            _isExternalFamily
                ? streetController.text.trim()
                : addressController.text.trim(),
        country: selectedCountry ?? widget.user?.country,
        region:
            _isExternalFamily
                ? _salespersonState
                : (selectedRegion ?? widget.user?.region),
        gstin: gstinController.text.trim(),
        profileImageFile: _pickedImage,
        userType: userRoleType,
      );

      final fields = _adminProfileUpdateFields(
        user,
        mobile: mobile,
        username: username,
      );

      showSnackBar(context, "Updating user...");

      final response = await HttpClientHelper.patchWithMultipart(
        updateUrl,
        AuthDataHelper.getToken(),
        fields: fields,
        file: user.profileImageFile,
      );
      debugPrint('EditUser profile PATCH: ${response.data}');
      Loader.hide();
      final decoded = jsonDecode(response.data);

      final userData = EditUserResponse.fromJson(decoded);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (userRoleType == 'Internal') {
          final tagOk = await _syncInternalAccountTag();
          if (!tagOk) {
            showSnackBar(
              context,
              'Profile saved, but tagged account could not be updated.',
            );
            return;
          }
          _initialTaggedAccountId = _taggedSalesforceAccountId;
        }

        showSnackBar(context, "${userData.message}");

        // If admin changed the currently logged-in user's type, invalidate
        // cached quotes so the next load always re-fetches with the fresh type.
        final editedUserId = _editedUserMongoId();
        final loggedInUserId = AuthDataHelper.getId();
        if (editedUserId.isNotEmpty &&
            editedUserId == loggedInUserId &&
            Get.isRegistered<SavedQuotationsController>()) {
          Get.find<SavedQuotationsController>().fetchSavedQuotes();
        }

        Navigator.pop(context, true);
      } else {
        final message = parseApiErrorMessage(
          response.data,
          fallback: userData.message ?? 'Could not update user',
        );
        showSnackBar(context, "Error: $message");
      }
    } on SocketException {
      Loader.hide();
      showSnackBar(context, "Network Error: Check your internet connection");
    } on FormatException {
      Loader.hide();
      showSnackBar(context, "Error: Invalid response format from server");
    } catch (e) {
      Loader.hide();
      showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  bool validateFields() {
    setState(() {
      emailError =
          emailController.text.trim().isEmpty
              ? "Please enter email"
              : (!ValidationUtils.isValidEmail(emailController.text.trim())
                  ? "Enter a valid email"
                  : null);

      firstNameError =
          firstNameController.text.trim().isEmpty
              ? "Please enter first name"
              : null;

      lastNameError =
          lastNameController.text.trim().isEmpty
              ? "Please enter last name"
              : null;
    });
    if (userRoleType == "External" ||
        userRoleType == "VIP" ||
        userRoleType == "VVIP") {
      gstinError =
          gstinController.text.trim().isEmpty
              ? "Please enter gst no"
              : (!RegExp(
                    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                  ).hasMatch(gstinController.text.trim())
                  ? "Invalid GST format"
                  : null);
    } else {
      gstinError = null;
    }

    // Role selection validation
    userRoleTypeError =
        (userRoleType == null || (userRoleType ?? '').isEmpty)
            ? "Please select role"
            : null;

    return emailError == null &&
        firstNameError == null &&
        lastNameError == null &&
        gstinError == null &&
        userRoleTypeError == null;
  }
}
