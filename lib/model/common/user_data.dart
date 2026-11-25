import 'dart:convert';
import 'dart:io';

import 'package:mprs_android/core/utils/country_utils.dart';

class UserData {
  final String? userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? designation;
  final String? department;
  final String? email;
  final String? alternateEmail;
  final String? mobile;
  final String? alternateMobile;
  final String? landlineNumber;
  final String? extentionNumber;
  final String? address;
  final String? country;
  final String? region;
  final bool? termsAccepted;
  final bool? isActive;
  final String? companyName;
  final bool? activeRmsUser;
  final String? userType;
  final String? deviceType;
  final String? profileImageUrl; // Network URL
  final File? profileImageFile; // Local file for upload
  final String? fcmToken; // New field
  final String? lastUpdatedBy; // New field
  final String? id;
  final String? gstin;
  final String? createdAt;
  final String? updatedAt;
  final int? v;
  final String? accountId; // Salesforce account ID
  final String? contactId; // salesforce contact ID
  final String? branchName;
  final String? street;
  final String? city;
  final String? postalCode;
  final String? state;
  final String? accountType;
  final String? salespersonId;
  final String? salespersonName;
  UserData({
    this.userId,
    this.username,
    this.firstName,
    this.lastName,
    this.designation,
    this.department,
    this.email,
    this.alternateEmail,
    this.mobile,
    this.alternateMobile,
    this.landlineNumber,
    this.extentionNumber,
    this.address,
    this.country,
    this.region,
    this.termsAccepted,
    this.isActive,
    this.companyName,
    this.activeRmsUser,
    this.userType,
    this.deviceType,
    this.profileImageUrl,
    this.profileImageFile,
    this.fcmToken,
    this.lastUpdatedBy,
    this.id,
    this.gstin,
    this.createdAt,
    this.updatedAt,
    this.v,
    this.accountId,
    this.contactId,
    this.branchName,
    this.street,
    this.city,
    this.postalCode,
    this.state,
    this.accountType,
    this.salespersonId,
    this.salespersonName,
  });

  static const _accountIdKeys = [
    'accountId',
    'AccountId',
    'account_id',
    'salesforceAccountId',
    'sfAccountId',
    'sf_account_id',
    'taggedAccountId',
    'tagged_account_id',
    'assignedAccountId',
    'assigned_account_id',
  ];

  static const _taggedAccountObjectKeys = [
    'taggedAccount',
    'TaggedAccount',
    'tagged_account',
    'assignedAccount',
    'AssignedAccount',
    'account',
    'Account',
  ];

  static const _taggedAccountNameKeys = [
    'taggedAccountName',
    'TaggedAccountName',
    'tagged_account_name',
    'accountName',
    'AccountName',
    'Name',
    'name',
  ];

  /// Names that may appear on the user record itself. `companyName` is the
  /// internal user's employer, not the Salesforce account an admin tagged.
  static const _looseTaggedAccountNameKeys = [
    'taggedAccountName',
    'TaggedAccountName',
    'tagged_account_name',
    'accountName',
    'AccountName',
  ];

  static const _taggedAccountListKeys = [
    'taggedAccounts',
    'tagged_accounts',
    'assignedAccounts',
    'assigned_accounts',
  ];

  /// Unwraps `data` / `body` / `result` wrappers from auth profile responses.
  static List<Map<String, dynamic>> profilePayloadLayers(dynamic decoded) {
    if (decoded is! Map) return const [];
    final root = Map<String, dynamic>.from(decoded);
    final layers = <Map<String, dynamic>>[root];
    for (final key in ['data', 'body', 'result', 'response', 'payload']) {
      final nested = root[key];
      if (nested is Map) {
        layers.add(Map<String, dynamic>.from(nested));
      }
    }
    return layers;
  }

  /// `user` object whether it lives at root or under `data.user`.
  static Map<String, dynamic>? resolveUserJson(dynamic decoded) {
    for (final layer in profilePayloadLayers(decoded)) {
      final user = layer['user'];
      if (user is Map) {
        return Map<String, dynamic>.from(user);
      }
    }
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map.containsKey('email') ||
          map.containsKey('userId') ||
          map.containsKey('userType')) {
        return map;
      }
    }
    return null;
  }

  /// Reads Salesforce account id from profile/login user JSON or response root.
  static String? parseAccountIdFromPayload(dynamic decoded) {
    for (final layer in profilePayloadLayers(decoded)) {
      final id = _parseAccountIdFromMap(layer);
      if (id != null) return id;
    }
    return null;
  }

  static String? _parseAccountIdFromMap(Map<String, dynamic> map) {
    for (final key in _taggedAccountObjectKeys) {
      final fromObj = _accountIdFromTaggedNode(map[key]);
      if (fromObj != null) return fromObj;
    }

    for (final key in _taggedAccountListKeys) {
      final id = _accountIdFromTaggedList(map[key]);
      if (id != null) return id;
    }

    final userJson = map['user'];
    if (userJson is Map) {
      final id = _parseAccountIdFromUserMap(Map<String, dynamic>.from(userJson));
      if (id != null) return id;
    }

    final direct = _firstString(map, _accountIdKeys);
    if (direct != null) return direct;

    return _parseAccountIdFromUserMap(map);
  }

  static String? _parseAccountIdFromUserMap(Map<String, dynamic> userMap) {
    for (final objKey in _taggedAccountObjectKeys) {
      final fromObj = _accountIdFromTaggedNode(userMap[objKey]);
      if (fromObj != null) return fromObj;
    }
    for (final key in _taggedAccountListKeys) {
      final id = _accountIdFromTaggedList(userMap[key]);
      if (id != null) return id;
    }
    final fromUser = UserData.fromJson(userMap).accountId;
    if (fromUser != null && fromUser.isNotEmpty) return fromUser;
    return _firstString(userMap, _accountIdKeys);
  }

  static String? _accountIdFromTaggedList(dynamic list) {
    if (list is! List || list.isEmpty) return null;
  for (final item in list) {
      final id = _accountIdFromTaggedNode(item);
      if (id != null) return id;
    }
    return null;
  }

  /// Display name for admin-tagged account when profile/login includes it.
  static String? parseTaggedAccountNameFromPayload(dynamic decoded) {
    final accountId = parseAccountIdFromPayload(decoded);
    for (final layer in profilePayloadLayers(decoded)) {
      final name = _parseTaggedAccountNameFromMap(layer, accountId);
      if (name != null) return name;
    }
    return null;
  }

  static String? _parseTaggedAccountNameFromMap(
    Map<String, dynamic> map,
    String? accountId,
  ) {
    for (final key in _taggedAccountObjectKeys) {
      final node = map[key];
      if (accountId != null &&
          _accountIdFromTaggedNode(node) != null &&
          !_sameSfId(_accountIdFromTaggedNode(node), accountId)) {
        continue;
      }
      final name = _nameFromTaggedNode(node);
      if (name != null) return name;
    }

    for (final key in _taggedAccountListKeys) {
      final name = _nameFromTaggedList(map[key], accountId);
      if (name != null) return name;
    }

    final userJson = map['user'];
    if (userJson is Map) {
      final userMap = Map<String, dynamic>.from(userJson);
      for (final objKey in _taggedAccountObjectKeys) {
        final name = _nameFromTaggedNode(userMap[objKey]);
        if (name != null) return name;
      }
      final fromList = _nameFromTaggedList(
        userMap['taggedAccounts'] ?? userMap['assignedAccounts'],
        accountId,
      );
      if (fromList != null) return fromList;
      final direct = _firstString(userMap, _looseTaggedAccountNameKeys);
      if (direct != null) return direct;
    }

    return _firstString(map, _looseTaggedAccountNameKeys);
  }

  static String? _nameFromTaggedList(dynamic list, String? accountId) {
    if (list is! List) return null;
    for (final item in list) {
      if (accountId != null) {
        final id = _accountIdFromTaggedNode(item);
        if (id != null && !_sameSfId(id, accountId)) continue;
      }
      final name = _nameFromTaggedNode(item);
      if (name != null) return name;
    }
    return null;
  }

  static bool _sameSfId(String? a, String? b) {
    final x = a?.trim().toLowerCase() ?? '';
    final y = b?.trim().toLowerCase() ?? '';
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    final shortX = x.length >= 15 ? x.substring(0, 15) : x;
    final shortY = y.length >= 15 ? y.substring(0, 15) : y;
    return shortX == shortY;
  }

  static String? _accountIdFromTaggedNode(dynamic node) {
    if (node is! Map) return null;
    final m = Map<String, dynamic>.from(node);
    return _firstString(m, [
      ..._accountIdKeys,
      'Id',
      'id',
      'sfId',
      'SF_Account_Id__c',
    ]);
  }

  static String? _nameFromTaggedNode(dynamic node) {
    if (node is! Map) return null;
    final m = Map<String, dynamic>.from(node);
    final account = m['Account'] ?? m['account'];
    if (account is Map) {
      final nested = _firstString(
        Map<String, dynamic>.from(account),
        const ['Name', 'name'],
      );
      if (nested != null) return nested;
    }
    return _firstString(m, _taggedAccountNameKeys);
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Best-effort Indian state for internal profiles (`state`, branch, SF shapes).
  static String? parseIndianStateFromPayload(dynamic decoded) {
    if (decoded == null) return null;

    final candidates = <String>[];

    for (final layer in profilePayloadLayers(decoded)) {
      for (final key in const [
        'state',
        'stateCode',
        'State',
        'StateCode',
        'salespersonState',
        'branchState',
        'officeState',
      ]) {
        final v = _firstString(layer, [key]);
        if (v != null) candidates.add(v);
      }
      final branch = layer['branch'] ?? layer['Branch'];
      if (branch is Map) {
        final m = Map<String, dynamic>.from(branch);
        for (final key in const ['state', 'stateCode', 'State']) {
          final v = _firstString(m, [key]);
          if (v != null) candidates.add(v);
        }
      }
      final userJson = resolveUserJson({'user': layer});
      if (userJson != null) {
        final u = UserData.fromJson(userJson);
        final fromUser = (u.state ?? u.region ?? '').trim();
        if (fromUser.isNotEmpty) candidates.add(fromUser);
      }
    }

    void walk(dynamic node, [int depth = 0]) {
      if (depth > 4 || node == null) return;
      if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key.toString().toLowerCase();
          if (key.contains('state') && !key.contains('statement')) {
            final t = entry.value?.toString().trim() ?? '';
            if (t.isNotEmpty) candidates.add(t);
          }
          walk(entry.value, depth + 1);
        }
      } else if (node is List) {
        for (final e in node) {
          walk(e, depth + 1);
        }
      }
    }

    walk(decoded);

    for (final raw in candidates) {
      final name = CountryUtils.displayIndianStateName(raw);
      if (name == null || name.trim().isEmpty) continue;
      if (CountryUtils.getIndianStates().contains(name)) return name;
    }
    return null;
  }

  UserData copyWith({String? accountId, String? contactId}) {
    return UserData(
      userId: userId,
      username: username,
      firstName: firstName,
      lastName: lastName,
      designation: designation,
      department: department,
      email: email,
      alternateEmail: alternateEmail,
      mobile: mobile,
      alternateMobile: alternateMobile,
      landlineNumber: landlineNumber,
      extentionNumber: extentionNumber,
      address: address,
      country: country,
      region: region,
      termsAccepted: termsAccepted,
      isActive: isActive,
      companyName: companyName,
      activeRmsUser: activeRmsUser,
      userType: userType,
      deviceType: deviceType,
      profileImageUrl: profileImageUrl,
      profileImageFile: profileImageFile,
      fcmToken: fcmToken,
      lastUpdatedBy: lastUpdatedBy,
      id: id,
      gstin: gstin,
      createdAt: createdAt,
      updatedAt: updatedAt,
      v: v,
      accountId: accountId ?? this.accountId,
      contactId: contactId ?? this.contactId,
      branchName: branchName,
      street: street,
      city: city,
      postalCode: postalCode,
      state: state,
      accountType: accountType,
      salespersonId: salespersonId,
      salespersonName: salespersonName,
    );
  }

  static Map<String, dynamic>? _nestedMap(Map<String, dynamic> json, String key) {
    final node = json[key];
    if (node is Map) return Map<String, dynamic>.from(node);
    return null;
  }

  static String? _personName(Map<String, dynamic>? source) {
    if (source == null) return null;
    final first = _firstString(source, const [
      'firstName',
      'FirstName',
    ]);
    final last = _firstString(source, const ['lastName', 'LastName']);
    final joined = [first, last]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    return joined.isEmpty ? null : joined;
  }

  static String? _layerString(
    Map<String, dynamic> json,
    Map<String, dynamic>? nested,
    List<String> keys,
  ) {
    final fromRoot = _firstString(json, keys);
    if (fromRoot != null) return fromRoot;
    if (nested != null) return _firstString(nested, keys);
    return null;
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    final branch = _nestedMap(json, 'branch') ?? _nestedMap(json, 'Branch');
    final salesperson =
        _nestedMap(json, 'salesperson') ??
        _nestedMap(json, 'salesPerson') ??
        _nestedMap(json, 'Salesperson');

    final salespersonName =
        _firstString(json, const [
          'salespersonName',
          'salesPersonName',
          'SalespersonName',
        ]) ??
        _firstString(salesperson ?? const {}, const [
          'name',
          'Name',
          'fullName',
          'displayName',
        ]) ??
        _personName(salesperson);

    return UserData(
      userId: json['userId'],
      username: json['username'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      designation: json['designation'],
      department: json['department'],
      email: json['email'],
      alternateEmail: json['alternateEmail'],
      mobile: json['mobile'],
      alternateMobile: json['alternateMobile'],
      landlineNumber: json['landlineNumber'],
      extentionNumber: json['extentionNumber'],
      address: json['address'],
      country: json['country'],
      region: json['region'],
      termsAccepted: json['termsAccepted'],
      isActive: json['isActive'],
      companyName: json['companyName'],
      activeRmsUser: json['Active_RMS_User'],
      userType: json['userType'],
      deviceType: json['deviceType'],
      profileImageUrl: json['profileImageUrl'],
      profileImageFile: null,
      fcmToken: json['fcmToken'],
      lastUpdatedBy: json['lastUpdatedBy'],
      id: json['_id'],
      gstin: json['gstin'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      v: json['__v'],
      accountId: _firstString(json, _accountIdKeys),
      contactId: _firstString(json, const [
        'contactId',
        'ContactId',
        'salesforceContactId',
      ]),
      branchName: _layerString(json, branch, const [
        'branchName',
        'branch_name',
        'BranchName',
      ]),
      street: _layerString(json, branch, const [
            'street',
            'Street',
            'streetAddress',
          ]) ??
          _firstString(json, const ['street', 'Street']),
      city: _layerString(json, branch, const ['city', 'City']) ??
          _firstString(json, const ['city', 'City']),
      postalCode: _layerString(json, branch, const [
            'postalCode',
            'postal_code',
            'PostalCode',
            'zip',
          ]) ??
          _firstString(json, const ['postalCode', 'postal_code', 'zip']),
      state: _layerString(json, branch, const [
            'state',
            'stateCode',
            'State',
          ]) ??
          _firstString(json, const ['state', 'stateCode']),
      accountType: () {
        final direct = _firstString(json, const [
          'accountType',
          'account_type',
          'AccountType',
        ]);
        if (direct != null) return direct;
        final raw = json['accountTypes'];
        if (raw is List && raw.isNotEmpty) {
          return raw.first.toString().trim();
        }
        if (raw is String && raw.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List && decoded.isNotEmpty) {
              return decoded.first.toString().trim();
            }
          } catch (_) {}
        }
        return null;
      }(),
      salespersonId:
          _firstString(json, const [
            'salespersonId',
            'salesPersonId',
            'SalespersonId',
          ]) ??
          _firstString(salesperson ?? const {}, const ['id', 'Id', 'userId']),
      salespersonName: salespersonName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'designation': designation,
      'department': department,
      'email': email,
      'alternateEmail': alternateEmail,
      'mobile': mobile,
      'alternateMobile': alternateMobile,
      'landlineNumber': landlineNumber,
      'extentionNumber': extentionNumber,
      'address': address,
      'country': country,
      'region': region,
      'termsAccepted': termsAccepted,
      'isActive': isActive,
      'companyName': companyName,
      'Active_RMS_User': activeRmsUser,
      'userType': userType,
      'deviceType': deviceType,
      'profileImageUrl': profileImageUrl,
      'fcmToken': fcmToken,
      'lastUpdatedBy': lastUpdatedBy,
      '_id': id,
      'gstin': gstin,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      '__v': v,
      'accountId': accountId,
      'contactId': contactId,
      'branchName': branchName,
      'street': street,
      'city': city,
      'postalCode': postalCode,
      'state': state,
      'accountType': accountType,
      'salespersonId': salespersonId,
      'salespersonName': salespersonName,
      // profileImageFile is not included in JSON
    };
  }
}
