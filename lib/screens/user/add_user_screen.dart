import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/network.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/core/utils/validation_utils.dart';
import 'package:mprs_android/model/add_user_response.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/signup_response.dart';
import 'package:mprs_android/screens/user/user_cache.dart';
import 'package:mprs_android/service/admin_user_account_tag_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/sales_account_directory.dart';
import 'package:mprs_android/service/salesperson_directory.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import '../../core/utils/common_data.dart';

class AddUserScreen extends StatefulWidget {
  /// Internal sales users: create **External** customers only (no user list).
  final bool restrictToExternal;

  const AddUserScreen({super.key, this.restrictToExternal = false});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
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

  String? selectedCountry;
  String? selectedRegion;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? userNameError;
  String? emailError;
  String? companyNameError;
  String? firstNameError;
  String? lastNameError;
  String? mobileError;
  String? countryError;
  String? regionError;
  String? passwordError;
  String? confirmPasswordError;
  String? gstinError;
  String? branchNameError;
  String? streetError;
  String? cityError;
  String? postalCodeError;
  String? branchCountryError;
  String? branchStateError;
  String? accountTypeError;
  String? _selectedAccountType;

  static const List<String> _accountTypeOptions = [
    'Shipper',
    'Agent/Forwarder',
    'Consignee',
    'Overseas Agent',
  ];

  final countries = CountryUtils.getAllCountries();
  final region = CountryUtils.getRegion();

  String? userRoleType;
  String? userRoleTypeError;
  File? _pickedImage;

  List<SalesAccountChoice> _sfAccounts = [];
  bool _sfAccountsLoading = false;
  String? _taggedSalesforceAccountId;
  String? _sfAccountsError;

  final indianStates = CountryUtils.getIndianStates();
  String? _salespersonState;
  List<SalespersonOption> _salespersons = [];
  bool _salespersonsLoading = false;
  String? _selectedSalespersonId;
  bool _creatorSalespersonLocked = false;
  bool _creatorPrefillLoading = false;

  bool get _externalOnly => widget.restrictToExternal;

  bool get _needsExternalBusinessFields =>
      _externalOnly ||
      userRoleType == 'External' ||
      userRoleType == 'VIP' ||
      userRoleType == 'VVIP';

  /// External customers (self-signup shape) — not `admin/add-user`.
  bool get _usesSignupForCreate {
    if (_externalOnly) return true;
    return (userRoleType ?? '').trim().toLowerCase() == 'external';
  }

  /// Internal sales user adding a customer: default state + salesperson to self.
  bool get _creatorOwnsSalesperson =>
      _externalOnly &&
      AuthDataHelper.getUserType().trim().toLowerCase() == 'internal';

  @override
  void initState() {
    super.initState();
    if (_externalOnly) {
      userRoleType = 'External';
    }
    if (_creatorOwnsSalesperson) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillFromLoggedInInternalCreator();
      });
    } else if (_externalOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSalespersons();
      });
    }
  }

  Future<void> _prefillFromLoggedInInternalCreator() async {
    if (!_creatorOwnsSalesperson) return;

    final creatorId =
        AuthDataHelper.getUserId().trim().isNotEmpty
            ? AuthDataHelper.getUserId().trim()
            : AuthDataHelper.getId().trim();
    final creatorName = AuthDataHelper.getFullName().trim();

    if (!mounted) return;
    setState(() => _creatorPrefillLoading = true);

  String? stateName;
    final token = AuthDataHelper.getToken().trim();
    dynamic profileDecoded;
    if (token.isNotEmpty) {
      try {
        final response = await HttpClientHelper.getWithBearer(
          ApiConstants.profile,
          token,
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          profileDecoded = jsonDecode(response.data);
          stateName = UserData.parseIndianStateFromPayload(profileDecoded);
          debugPrint(
            'AddUser prefill profile state=$stateName raw=${response.data}',
          );
        }
      } catch (e) {
        debugPrint('AddUser prefill profile: $e');
      }
    }

    stateName ??= CountryUtils.displayIndianStateName(
      AuthDataHelper.getRegion(),
    );
    if (stateName != null &&
        !CountryUtils.getIndianStates().contains(stateName)) {
      stateName = null;
    }

    stateName ??= await SalespersonDirectory.findIndianStateForSalesperson(
      salespersonId: creatorId,
      salespersonName: creatorName,
    );

    if (!mounted) return;

    if (stateName == null || stateName.trim().isEmpty) {
      debugPrint(
        'AddUser prefill: no Indian state on profile for internal user '
        '(backend should return state/stateCode on auth/profile). '
        'prefs region=${AuthDataHelper.getRegion()}',
      );
    } else {
      setState(() {
        _salespersonState = stateName;
        branchStateError = null;
      });
    }

    await _loadSalespersons();
    if (!mounted) return;

    setState(() {
      _creatorPrefillLoading = false;
      _creatorSalespersonLocked = true;
      if (creatorId.isNotEmpty) {
        _selectedSalespersonId = creatorId;
      }
      if (creatorName.isNotEmpty &&
          creatorId.isNotEmpty &&
          !_salespersons.any((p) => p.id == creatorId)) {
        _salespersons = [
          SalespersonOption(
            id: creatorId,
            name: creatorName,
            state: stateName,
          ),
          ..._salespersons,
        ];
      } else if (creatorId.isNotEmpty) {
        final match = _salespersons.where((p) => p.id == creatorId);
        if (match.isNotEmpty) {
          _selectedSalespersonId = match.first.id;
        }
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;
    final File imageFile = File(picked.path);
    final int imageSize = await imageFile.length();
    const int maxImageSize = 2 * 1024 * 1024;
    if (imageSize > maxImageSize) {
      showSnackBar(context, "Image size should not be greater than 2 MB");
      return;
    }
    setState(() {
      _pickedImage = imageFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(
        title: _externalOnly ? 'Add external user' : 'Add User',
      ),
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

              const SizedBox(height: 20),

              // ═══════════════════════════════════════════════════════════════
              // MANDATORY INFORMATION SECTION
              // ═══════════════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      "Mandatory Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!_externalOnly)
                buildRoundedDropdownWithArrow(
                  label: "Select role",
                  hint: "Select role",
                  isRequired: true,
                  items: addUserRoles,
                  value: userRoleType,
                  onChanged: (value) {
                    setState(() {
                      userRoleType = value;
                      userRoleTypeError = null;
                      if (value != 'Internal') {
                        _sfAccounts = [];
                        _taggedSalesforceAccountId = null;
                        _sfAccountsError = null;
                      }
                      if (value != 'External') {
                        _salespersonState = null;
                        _salespersons = [];
                        _selectedSalespersonId = null;
                      }
                    });
                    if (value == 'External') {
                      _loadSalespersons();
                    }
                  },
                  errorText: userRoleTypeError,
                  context: context,
                ),

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
                controller: mobileNumberController,
                inputType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {},
                errorText: mobileError,
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
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: companyNameError,
              ),

              if (_needsExternalBusinessFields) ...[
                buildRoundedDropdownWithArrow(
                  label: 'Account type',
                  hint: 'Select account type',
                  isRequired: true,
                  items: _accountTypeOptions,
                  value: _selectedAccountType,
                  onChanged: (value) {
                    setState(() {
                      _selectedAccountType = value;
                      accountTypeError = null;
                    });
                  },
                  errorText: accountTypeError,
                  context: context,
                ),
                buildUserTextField(
                  label: 'Branch name',
                  hint: 'Enter branch name',
                  controller: branchNameController,
                  isRequired: true,
                  onChanged: (value) {
                    if (value.trim().isNotEmpty) {
                      setState(() => branchNameError = null);
                    }
                  },
                  errorText: branchNameError,
                ),
                if (_usesSignupForCreate) ...[
                  buildUserTextField(
                    label: 'Street',
                    hint: 'Enter street address',
                    controller: streetController,
                    isRequired: true,
                    inputType: TextInputType.streetAddress,
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() => streetError = null);
                      }
                    },
                    errorText: streetError,
                  ),
                  buildUserTextField(
                    label: 'City',
                    hint: 'Enter city',
                    controller: cityController,
                    isRequired: true,
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() => cityError = null);
                      }
                    },
                    errorText: cityError,
                  ),
                  buildUserTextField(
                    label: 'Postal code',
                    hint: 'Enter postal code',
                    controller: postalCodeController,
                    isRequired: true,
                    inputType: TextInputType.number,
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() => postalCodeError = null);
                      }
                    },
                    errorText: postalCodeError,
                  ),
                  buildRoundedDropdownWithArrow(
                    label: 'Country',
                    hint: 'Select country',
                    isRequired: true,
                    items: countries,
                    value: selectedCountry,
                    onChanged: (value) {
                      setState(() {
                        selectedCountry = value;
                        branchCountryError = null;
                      });
                    },
                    errorText: branchCountryError,
                    context: context,
                  ),
                ],
              ],

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
                onChanged: (value) {
                  print("User typed: $value");
                },
                errorText: gstinError,
              ),

              if (_externalOnly || userRoleType == 'External') ...[
                const SizedBox(height: 16),
                _buildExternalSalespersonSection(),
              ],

              if (!_externalOnly && userRoleType == 'Internal') ...[
                const SizedBox(height: 20),
                _buildInternalSalesforceAccountsSection(),
              ],

              buildPasswordField(
                label: "New Password",
                obscureText: !_passwordVisible,
                hint: "Enter your password",
                controller: passwordController,
                isRequired: true,
                onTogglePassword: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    passwordError = ValidationUtils.getBackendPasswordError(
                      value,
                    );
                  });
                },
                errorText: passwordError,
              ),
              const SizedBox(height: 16),
              buildPasswordField(
                obscureText: !_confirmPasswordVisible,
                label: "Confirm New Password",
                hint: "Enter your confirm password",
                controller: confirmPasswordController,
                isRequired: true,
                onTogglePassword: () {
                  setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    confirmPasswordError =
                        ValidationUtils.getBackendPasswordError(value);

                    if (confirmPasswordError == null) {
                      if (value != passwordController.text.trim()) {
                        confirmPasswordError = "Passwords do not match";
                      }
                    }
                  });
                },
                errorText: confirmPasswordError,
              ),

              const SizedBox(height: 28),

              // ═══════════════════════════════════════════════════════════════
              // OPTIONAL INFORMATION SECTION
              // ═══════════════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      "Optional Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Professional Information
              Text(
                "Professional Details",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightGrey,
                ),
              ),
              const SizedBox(height: 12),

              buildUserTextField(
                label: "Designation",
                hint: "Enter your designation (Optional)",
                controller: designationController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),
              buildUserTextField(
                label: "Department",
                hint: "Enter your Department (Optional)",
                controller: departmentController,
                onChanged: (value) {
                  print("User typed: $value");
                },
              ),

              // role moved to mandatory section
              const SizedBox(height: 20),

              // Contact Information
              Text(
                "Contact Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightGrey,
                ),
              ),
              const SizedBox(height: 12),

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

              const SizedBox(height: 20),

              Text(
                "Location Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightGrey,
                ),
              ),
              const SizedBox(height: 12),

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

              const SizedBox(height: 30),

              MainButton(
                text: 'Save User',
                onPressed: () {
                  FocusScope.of(context).unfocus();
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

  Widget _buildExternalSalespersonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildRoundedDropdown(
          label: 'State',
          hint:
              _creatorPrefillLoading
                  ? 'Loading your state…'
                  : 'Select state',
          items: _indianStateItemsForDropdown(),
          value:
              _salespersonState != null &&
                      _indianStateItemsForDropdown().contains(_salespersonState)
                  ? _salespersonState
                  : null,
          enabled: !_creatorSalespersonLocked,
          onChanged:
              _creatorSalespersonLocked
                  ? (_) {}
                  : (value) {
                    setState(() {
                      _salespersonState = value;
                      branchStateError = null;
                    });
                  },
          errorText: _usesSignupForCreate ? branchStateError : null,
          context: context,
        ),
        if (_creatorPrefillLoading || _salespersonsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          buildRoundedDropdown(
            label: 'Sales person',
            hint:
                _salespersons.isEmpty
                    ? 'No sales persons'
                    : (_creatorSalespersonLocked
                        ? 'Your name (assigned)'
                        : 'Select sales person (Optional)'),
            items: _salespersons.map((e) => e.name).toList(),
            value: _salespersonLabelForId(_selectedSalespersonId),
            enabled: !_creatorSalespersonLocked && _salespersons.isNotEmpty,
            onChanged:
                _creatorSalespersonLocked
                    ? (_) {}
                    : (value) {
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
    if (_creatorOwnsSalesperson) {
      final name = AuthDataHelper.getFullName().trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  List<String> _indianStateItemsForDropdown() {
    final items = List<String>.from(indianStates);
    final current = _salespersonState?.trim();
    if (current != null && current.isNotEmpty && !items.contains(current)) {
      items.insert(0, current);
    }
    return items;
  }

  String? _salespersonIdForName(String? name) {
    if (name == null) return null;
    for (final p in _salespersons) {
      if (p.name == name) return p.id;
    }
    return null;
  }

  Future<void> _loadSalespersons() async {
    setState(() => _salespersonsLoading = true);
    final list = await SalespersonDirectory.loadAll();
    if (!mounted) return;
    setState(() {
      _salespersonsLoading = false;
      _salespersons = list;
      if (_selectedSalespersonId != null &&
          !list.any((e) => e.id == _selectedSalespersonId)) {
        _selectedSalespersonId = null;
      }
    });
  }

  Widget _buildInternalSalesforceAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              _sfAccountsLoading
                  ? 'Loading accounts…'
                  : 'Select account (Optional)',
          items: _accountDropdownItems(),
          value: _taggedAccountLabel(),
          enabled: !_sfAccountsLoading,
          loadItemsOnOpen: _loadAccountDropdownItems,
          onChanged: (value) {
            if (value == null || value == '— None —') {
              setState(() => _taggedSalesforceAccountId = null);
              return;
            }
            setState(() {
              _taggedSalesforceAccountId = _accountIdForLabel(value);
            });
          },
          context: context,
        ),
        if (_sfAccountsLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        const Text(
          'Tap to load accounts for this email (POST). Optional tag after create.',
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
    if (_taggedSalesforceAccountId == null) return null;
    for (final row in _sfAccounts) {
      if (row.id == _taggedSalesforceAccountId) return row.name;
    }
    return null;
  }

  String? _accountIdForLabel(String label) {
    for (final row in _sfAccounts) {
      if (row.name == label) return row.id;
    }
    return null;
  }

  Future<void> _loadInternalOwnerAccounts() async {
    if (!(await checkInternetConnection())) {
      if (mounted) showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }

    final email = emailController.text.trim();
    if (email.isEmpty) {
      if (mounted)
        showSnackBar(context, 'Enter the Internal user’s email first');
      return;
    }
    if (!ValidationUtils.isValidEmail(email)) {
      if (mounted) showSnackBar(context, 'Enter a valid email address');
      return;
    }

    final previousTag = _taggedSalesforceAccountId;

    setState(() {
      _sfAccountsLoading = true;
      _sfAccountsError = null;
    });

    final result = await SalesAccountDirectory.loadForAdminAccountPicker(
      internalUserEmail: email,
    );

    if (!mounted) return;

    var choices = List<SalesAccountChoice>.from(result.choices);
    if (previousTag != null && !choices.any((c) => c.id == previousTag)) {
      final name = await SalesAccountDirectory.resolveAccountDisplayName(
        previousTag,
      );
      choices.add(
        SalesAccountChoice(id: previousTag, name: name, fromApi: true),
      );
    }

    if (!mounted) return;
    setState(() {
      _sfAccountsLoading = false;
      _sfAccounts = choices;
      _sfAccountsError =
          choices.isEmpty
              ? (result.errorMessage ?? 'No accounts found for this email')
              : null;
      if (previousTag != null && choices.any((c) => c.id == previousTag)) {
        _taggedSalesforceAccountId = previousTag;
      } else if (previousTag != null) {
        _taggedSalesforceAccountId = null;
      }
    });
  }

  Widget _buildProfileImage() {
    // Default asset image
    return Image.asset(
      'assets/icons/default_ic_user.png',
      width: 120,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  Future<void> saveUser() async {
    if (!validateFields()) {
      // Show specific error message for validation failure
      Future.microtask(() {
        if (gstinError != null) {
          showSnackBar(
            context,
            "Please enter GSTIN for External/VIP/VVIP users",
          );
        } else {
          showSnackBar(context, "Please fill all required fields");
        }
      });
      return;
    }
    if (!(await checkInternetConnection())) {
      ProgressLoader.hide(context);
      showSnackBar(context, AppStrings.pleaseCheckInternet);
      return;
    }
    if (_externalOnly || _usesSignupForCreate) {
      userRoleType = 'External';
    }
    String deviceType = "";
    if (Platform.isAndroid) {
      deviceType = "android";
    } else if (Platform.isIOS) {
      deviceType = "ios";
    }

    final user = UserData(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      email: emailController.text.trim(),
      alternateEmail: alternateEmailController.text.trim(),
      mobile: mobileNumberController.text.trim(),
      alternateMobile: alternateMobileController.text.trim(),
      designation: designationController.text.trim(),
      department: departmentController.text.trim(),
      companyName: companyNameController.text.trim(),
      landlineNumber: landlineNumberController.text.trim(),
      extentionNumber: extensionController.text.trim(),
      address: addressController.text.trim(),
      country: selectedCountry,
      region: selectedRegion,
      gstin: gstinController.text.trim(),
      profileImageFile: _pickedImage,
      termsAccepted: true,
      activeRmsUser: false,
      userType: userRoleType,
      deviceType: deviceType,
    );
    final viaSignup = _usesSignupForCreate;
    final fields = _multipartCreateFields(user, viaSignup: viaSignup);

    Loader.show();
    showSnackBar(
      context,
      viaSignup ? 'Creating external user...' : 'Adding user...',
    );

    debugPrint(
      viaSignup
          ? 'AddUser POST ${ApiConstants.signup} (auth/signup, no admin JWT)'
          : 'AddUser POST ${ApiConstants.addUser} userType=$userRoleType',
    );

    final response = viaSignup
        ? await HttpClientHelper.postWithMultipart(
            ApiConstants.signup,
            fields: fields,
            file: user.profileImageFile,
          )
        : await HttpClientHelper.postWithBearerMultipart(
            ApiConstants.addUser,
            AuthDataHelper.getToken(),
            fields: fields,
            file: user.profileImageFile,
          );

    Loader.hide();

    final decoded = jsonDecode(response.data);

    if (viaSignup) {
      final signupResponse = SignupResponse.fromJson(
        decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        showSnackBar(
          context,
          signupResponse.message ?? 'External user created',
        );
        Navigator.pop(context, true);
      } else {
        debugPrint(
          'AddUser signup failed HTTP ${response.statusCode} body=${response.data}',
        );
        final message = parseApiErrorMessage(
          response.data,
          fallback: signupResponse.message ?? 'Could not create user',
        );
        if (mounted) showSnackBar(context, 'Error: $message');
      }
      return;
    }

    final userData = AddUserResponse.fromJson(decoded);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        userData.user != null) {
      final tagAccountId =
          userRoleType == 'Internal'
              ? _taggedSalesforceAccountId?.trim()
              : null;
      if (tagAccountId != null && tagAccountId.isNotEmpty) {
        UserCache.rememberAccountTag(
          userId: userData.user!.userId,
          mongoId: userData.user!.id,
          accountId: tagAccountId,
        );
        await _applyTaggedAccountAfterCreate(userData.user!, tagAccountId);
      }
      if (!mounted) return;
      showSnackBar(context, userData.message ?? "");
      Navigator.pop(context, true);
    } else {
      debugPrint(
        'AddUser failed HTTP ${response.statusCode} body=${response.data}',
      );
      final message = parseApiErrorMessage(
        response.data,
        fallback: userData.message ?? 'Could not add user',
      );
      if (mounted) showSnackBar(context, 'Error: $message');
    }
  }

  /// Shared multipart field map — [viaSignup] matches [SignupScreen] for External.
  Map<String, String> _multipartCreateFields(
    UserData user, {
    required bool viaSignup,
  }) {
    return {
      'username': user.mobile.toString().trim(),
      'firstName': (user.firstName ?? '').trim(),
      'lastName': (user.lastName ?? '').trim(),
      'email': (user.email ?? '').trim(),
      'alternateEmail': (user.alternateEmail ?? '').trim(),
      'mobile': (user.mobile ?? '').trim(),
      'alternateMobile': (user.alternateMobile ?? '').trim(),
      'designation': (user.designation ?? '').trim(),
      'department': (user.department ?? '').trim(),
      'companyName': (user.companyName ?? '').trim(),
      if (viaSignup && _needsExternalBusinessFields) ...{
        'branchName': branchNameController.text.trim(),
        'street': streetController.text.trim(),
        'city': cityController.text.trim(),
        'postalCode': postalCodeController.text.trim(),
        'state': CountryUtils.salesforceIndianStateCode(_salespersonState),
        'country': CountryUtils.salesforceCountryCode(selectedCountry),
        if (_selectedAccountType != null &&
            _selectedAccountType!.trim().isNotEmpty)
          'accountType': _selectedAccountType!.trim(),
      },
      'landlineNumber': (user.landlineNumber ?? '').trim(),
      'extentionNumber': (user.extentionNumber ?? '').trim(),
      'address': (user.address ?? '').trim(),
      'country': viaSignup
          ? CountryUtils.salesforceCountryCode(selectedCountry)
          : (user.country ?? '').trim(),
      'region': viaSignup
          ? CountryUtils.salesforceIndianStateCode(_salespersonState)
          : (user.region ?? '').trim(),
      'gstin': (user.gstin ?? '').trim(),
      'termsAccepted': 'true',
      'Active_RMS_User': viaSignup ? 'false' : 'true',
      'isActive': 'true',
      'userType': (user.userType ?? '').trim(),
      'deviceType': (user.deviceType ?? '').trim(),
      'password': passwordController.text.trim(),
      if (_selectedSalespersonId != null &&
          _selectedSalespersonId!.trim().isNotEmpty)
        'salespersonId': _selectedSalespersonId!.trim(),
    };
  }

  /// Backend add-user Joi schema does not accept `accountId`; tag via update-user.
  Future<void> _applyTaggedAccountAfterCreate(
    UserData created,
    String accountId,
  ) async {
    final userId = created.userId?.trim() ?? created.id?.trim() ?? '';
    if (userId.isEmpty) {
      debugPrint('AddUser: skip accountId tag — no userId on create response');
      return;
    }
    final result = await AdminUserAccountTagService.syncForUser(
      userId: userId,
      accountId: accountId.trim(),
    );
    if (result.ok) {
      UserCache.rememberAccountTag(
        userId: created.userId,
        mongoId: created.id,
        accountId: accountId.trim(),
      );
      return;
    }
    debugPrint('AddUser: accountId tag failed: ${result.errorMessage}');
    if (mounted) {
      showSnackBar(
        context,
        'User created, but tagging account failed. Edit user to retry.',
      );
    }
  }

  bool validateFields() {
    setState(() {
      firstNameError =
          firstNameController.text.trim().isEmpty
              ? "Please enter first name"
              : null;

      lastNameError =
          lastNameController.text.trim().isEmpty
              ? "Please enter last name"
              : null;

      companyNameError =
          companyNameController.text.trim().isEmpty
              ? "Please enter company name"
              : null;

      mobileError =
          mobileNumberController.text.isEmpty
              ? "Please enter mobile number"
              : (mobileNumberController.text.length != 10
                  ? "Mobile number must be 10 digits"
                  : null);

      final emailText = emailController.text.trim();
      emailError =
          emailText.isEmpty
              ? 'Please enter email'
              : (!ValidationUtils.isValidEmail(emailText)
                  ? 'Enter a valid email address'
                  : null);

      passwordError = ValidationUtils.getBackendPasswordError(
        passwordController.text,
      );

      confirmPasswordError = ValidationUtils.getBackendPasswordError(
        confirmPasswordController.text,
      );
      if (confirmPasswordError == null) {
        if (confirmPasswordController.text != passwordController.text) {
          confirmPasswordError = "Passwords do not match";
        }
      }

      // GSTIN validation: required only for External / VIP / VVIP
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

      if (_needsExternalBusinessFields) {
        branchNameError =
            branchNameController.text.trim().isEmpty
                ? 'Please enter branch name'
                : null;
        accountTypeError =
            (_selectedAccountType == null ||
                    _selectedAccountType!.trim().isEmpty)
                ? 'Please select an account type'
                : null;
      } else {
        branchNameError = null;
        accountTypeError = null;
      }

      if (_usesSignupForCreate) {
        streetError =
            streetController.text.trim().isEmpty
                ? 'Please enter street'
                : null;
        cityError =
            cityController.text.trim().isEmpty ? 'Please enter city' : null;
        postalCodeError =
            postalCodeController.text.trim().isEmpty
                ? 'Please enter postal code'
                : null;
        branchCountryError =
            (selectedCountry == null || selectedCountry!.trim().isEmpty)
                ? 'Please select country'
                : null;
        branchStateError =
            (_salespersonState == null || _salespersonState!.trim().isEmpty)
                ? 'Please select state'
                : null;
      } else {
        streetError = null;
        cityError = null;
        postalCodeError = null;
        branchCountryError = null;
        branchStateError = null;
      }

      // Role selection validation (mandatory)
    if (_externalOnly) {
      userRoleType = 'External';
      userRoleTypeError = null;
    } else {
      userRoleTypeError =
          (userRoleType == null || (userRoleType ?? '').isEmpty)
              ? "Please select role"
              : null;
    }
    });

    // All correct?
    return emailError == null &&
        firstNameError == null &&
        lastNameError == null &&
        companyNameError == null &&
        mobileError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        gstinError == null &&
        branchNameError == null &&
        accountTypeError == null &&
        streetError == null &&
        cityError == null &&
        postalCodeError == null &&
        branchCountryError == null &&
        branchStateError == null &&
        userRoleTypeError == null;
  }
}
