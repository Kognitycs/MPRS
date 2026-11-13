import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/service/http_client_helper.dart';

/// One row in the internal-user account step.
class SalesAccountChoice {
  final String id;
  final String name;
  final bool isSelf;

  /// True when [id] came from [ApiConstants.opportunityAccounts].
  final bool fromApi;

  const SalesAccountChoice({
    required this.id,
    required this.name,
    this.isSelf = false,
    this.fromApi = false,
  });

  /// Customer account id safe to put on an opportunity or quote.
  String? get accountIdForApi {
    if (isSelf || !fromApi) return null;
    final text = id.trim();
    return text.isEmpty ? null : text;
  }
}

class SalesAccountLoad {
  final List<SalesAccountChoice> choices;

  const SalesAccountLoad({required this.choices});
}

/// Accounts for the signed-in internal user (self row + salesperson-owned SF accounts).
///
/// GET {staging|production}/api/user/opportunity/accounts
/// Headers: Authorization + `app_name` (staging vs prod via [AppConfig]).
class SalesAccountDirectory {
  static Future<SalesAccountLoad> loadForCurrentUser() async {
    if (!_isInternalSalesUser()) {
      return SalesAccountLoad(choices: [_self()]);
    }
    final accounts = await _fetchAssignedAccounts();
    return SalesAccountLoad(choices: [_self(), ...accounts]);
  }

  static bool _isInternalSalesUser() {
    return AuthDataHelper.getUserType().toLowerCase().trim() == 'internal';
  }

  static SalesAccountChoice _self() {
    final name = AuthDataHelper.getFullName().trim();
    final id = AuthDataHelper.getId().trim();
    return SalesAccountChoice(
      id: id.isEmpty ? 'self' : id,
      name: name.isEmpty ? 'Internal user' : name,
      isSelf: true,
    );
  }

  static Future<List<SalesAccountChoice>> _fetchAssignedAccounts() async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) {
      debugPrint('SalesAccountDirectory: no auth token');
      return const <SalesAccountChoice>[];
    }

    final url = ApiConstants.opportunityAccounts;
    debugPrint(
      'SalesAccountDirectory: GET $url (host=${AppConfig.domain}, '
      'app_name=${AppConfig.apiAppNameHeader})',
    );

    try {
      final response = await HttpClientHelper.getWithBearer(url, token);
      final code = response.statusCode;
      final ok = code >= 200 && code < 300;

      if (!ok) {
        final message = parseApiErrorMessage(
          response.data,
          fallback: response.message ?? response.data,
        );
        debugPrint('SalesAccountDirectory: HTTP $code $message');
        return const <SalesAccountChoice>[];
      }

      final body = _decodeJson(response.data);
      if (body == null) {
        debugPrint('SalesAccountDirectory: empty or non-JSON body');
        return const <SalesAccountChoice>[];
      }

      final apiError = _readApiFailureMessage(body);
      if (apiError != null) {
        debugPrint('SalesAccountDirectory: $apiError');
        return const <SalesAccountChoice>[];
      }

      final accounts = parseAccounts(body);
      debugPrint('SalesAccountDirectory: parsed ${accounts.length} account(s)');
      return accounts;
    } catch (e, st) {
      debugPrint('SalesAccountDirectory: $e\n$st');
      return const <SalesAccountChoice>[];
    }
  }

  static dynamic _decodeJson(dynamic raw) {
    if (raw is Map || raw is List) return raw;
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (e) {
      debugPrint('SalesAccountDirectory jsonDecode: $e');
      return null;
    }
  }

  /// Some RMS endpoints return HTTP 200 with `{ status: false, message: ... }`.
  static String? _readApiFailureMessage(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final status = map['status'] ?? map['success'];
    if (_isApiFailure(status)) {
      return parseApiErrorMessage(map, fallback: 'Could not load accounts');
    }
    return null;
  }

  static bool _isApiFailure(dynamic status) {
    if (status == null) return false;
    if (status is bool) return !status;
    if (status is num) return status == 0;
    final text = status.toString().toLowerCase().trim();
    return text == 'false' || text == 'failed' || text == 'error';
  }

  static List<SalesAccountChoice> parseAccounts(dynamic body) {
    final rows = _rowsOf(body);
    final parsed = <SalesAccountChoice>[];
    final seenIds = <String>{};

    for (final row in rows) {
      final choice = _parseRow(row);
      if (choice == null) continue;
      if (seenIds.add(choice.id)) {
        parsed.add(choice);
      }
    }
    parsed.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return parsed;
  }

  static SalesAccountChoice? _parseRow(dynamic row) {
    if (row is! Map) return null;
    var map = Map<String, dynamic>.from(row);

    final nestedAccount = map['Account'] ?? map['account'];
    if (nestedAccount is Map) {
      map = {...map, ...Map<String, dynamic>.from(nestedAccount)};
    }

    var id = _firstNonEmpty(map, const [
      'accountId',
      'AccountId',
      'account_id',
      'salesforceAccountId',
      'sfAccountId',
      'id',
      'Id',
      '_id',
    ]);
    id ??= _idFromSalesforceAttributes(map);

    var name = _firstNonEmpty(map, const [
      'accountName',
      'AccountName',
      'account_name',
      'companyName',
      'CompanyName',
      'company_name',
      'name',
      'Name',
    ]);

    final idText = id?.trim() ?? '';
    final nameText = name?.trim() ?? '';
    if (idText.isEmpty || nameText.isEmpty) return null;

    return SalesAccountChoice(id: idText, name: nameText, fromApi: true);
  }

  static String? _firstNonEmpty(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _idFromSalesforceAttributes(Map<String, dynamic> map) {
    final attributes = map['attributes'];
    if (attributes is! Map) return null;
    final url = attributes['url']?.toString();
    if (url == null || !url.contains('/')) return null;
    final segment = url.split('/').where((p) => p.isNotEmpty).lastOrNull;
    return segment?.trim().isNotEmpty == true ? segment : null;
  }

  static List<dynamic> _rowsOf(dynamic body) {
    if (body is List) return body;
    if (body is! Map) return const [];

    final map = Map<String, dynamic>.from(body);
    for (final key in [
      'data',
      'accounts',
      'records',
      'result',
      'items',
      'body',
    ]) {
      final value = map[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _rowsOf(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }
}
