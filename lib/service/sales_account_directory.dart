import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/screens/user/user_cache.dart';
import 'package:mprs_android/service/http_client_helper.dart';

enum _CustomerTier { normal, vip, vvip }

_CustomerTier _normalizeCustomerTier(String? raw) {
  final text = raw?.trim().toLowerCase() ?? '';
  if (text == 'vvip') return _CustomerTier.vvip;
  if (text == 'vip') return _CustomerTier.vip;
  return _CustomerTier.normal;
}

/// VIP / VVIP / everyone else (External, etc.) tallies from assigned accounts.
class SalesAccountCustomerTierCounts {
  final int normal;
  final int vip;
  final int vvip;

  const SalesAccountCustomerTierCounts({
    required this.normal,
    required this.vip,
    required this.vvip,
  });

  static const zero = SalesAccountCustomerTierCounts(
    normal: 0,
    vip: 0,
    vvip: 0,
  );

  int get total => normal + vip + vvip;

  /// [accounts] from [SalesAccountDirectory.parseAccounts].
  static SalesAccountCustomerTierCounts fromAccounts(
    List<SalesAccountChoice> accounts,
  ) {
    var normal = 0;
    var vip = 0;
    var vvip = 0;
    for (final row in accounts) {
      switch (_normalizeCustomerTier(row.userType)) {
        case _CustomerTier.vvip:
          vvip++;
        case _CustomerTier.vip:
          vip++;
        case _CustomerTier.normal:
          normal++;
      }
    }
    return SalesAccountCustomerTierCounts(normal: normal, vip: vip, vvip: vvip);
  }
}

/// One row in the internal-user account step.
class SalesAccountChoice {
  final String id;
  final String name;
  final bool isSelf;

  /// RMS user type when returned on opportunity account rows (`VIP`, `VVIP`, `External`, …).
  final String? userType;

  /// True when [id] came from [ApiConstants.opportunityAccounts].
  final bool fromApi;

  const SalesAccountChoice({
    required this.id,
    required this.name,
    this.isSelf = false,
    this.userType,
    this.fromApi = false,
  });

  String get customerTierLabel {
    final tier = _normalizeCustomerTier(userType);
    return switch (tier) {
      _CustomerTier.vvip => 'VVIP',
      _CustomerTier.vip => 'VIP',
      _CustomerTier.normal => 'Normal',
    };
  }

  /// Customer Salesforce account id for opportunities and quotes.
  String? get accountIdForApi {
    if (isSelf) return null;
    final text = id.trim();
    return text.isEmpty ? null : text;
  }
}

class SalesAccountLoad {
  final List<SalesAccountChoice> choices;
  final String? errorMessage;

  const SalesAccountLoad({required this.choices, this.errorMessage});
}

/// Opportunity accounts API (same path, two behaviors):
/// - **GET** `/user/opportunity/accounts` — Internal user’s Salesforce **OwnerId** portfolio.
/// - **POST** `{ "email" }` — Accounts linked to **Contact.Email** (admin: prospective
///   Internal email; Internal: own email only).
class SalesAccountDirectory {
  /// Internal user (Home Accounts, Search Rates) — same Contact.Email POST as
  /// admin add/edit Internal user, plus GET OwnerId portfolio and profile tag.
  static Future<SalesAccountLoad> loadForCurrentUser() async {
    if (!_isInternalSalesUser()) {
      return const SalesAccountLoad(choices: []);
    }

    final email = _loginEmail();
    SalesAccountLoad postLoad = const SalesAccountLoad(choices: []);
    if (email.isNotEmpty) {
      postLoad = await _fetchByContactEmailPost(email);
      debugPrint(
        'SalesAccountDirectory: Internal load POST email=$email '
        '→ ${postLoad.choices.length} account(s)',
      );
    }

    final ownerLoad = await _fetchByOwnerId();
    final profileRows = await _choicesFromTaggedProfile(refresh: true);

    var merged = _mergeAccountLists([
      ...postLoad.choices,
      ...ownerLoad.choices,
      ...profileRows,
    ]);
    merged = _dedupeByAccountId(merged);

    if (merged.isEmpty) {
      return SalesAccountLoad(
        choices: const [],
        errorMessage:
            postLoad.errorMessage ??
            ownerLoad.errorMessage ??
            'No accounts found for your email',
      );
    }

    if (merged.length == 1) {
      _persistTaggedAccountIdIfEmpty(merged.first.id);
    }

    return SalesAccountLoad(choices: merged);
  }

  /// Salesforce Account Ids for the logged-in Internal user (OwnerId portfolio).
  static Future<Set<String>> portfolioAccountIdSet() async {
    final load = await loadForCurrentUser();
    final ids = <String>{};
    for (final choice in load.choices) {
      final id = choice.id.trim();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  /// True when [quote]'s AccountId is in the salesperson portfolio.
  static bool quoteMatchesPortfolio(
    SavedQuotationsModel quote,
    Iterable<String> portfolioIds,
  ) {
    final onQuote = quote.accountId?.trim() ?? '';
    if (onQuote.isEmpty) return false;
    for (final pid in portfolioIds) {
      if (_sameSalesforceAccountId(pid, onQuote)) return true;
    }
    return false;
  }

  static List<SavedQuotationsModel> filterQuotesToPortfolio(
    List<SavedQuotationsModel> quotes,
    Set<String> portfolioIds,
  ) {
    if (portfolioIds.isEmpty) return [];
    return quotes.where((q) => quoteMatchesPortfolio(q, portfolioIds)).toList();
  }

  static bool rowAccountInPortfolio(
    String? accountId,
    Set<String> portfolioIds,
  ) {
    final onRow = accountId?.trim() ?? '';
    if (onRow.isEmpty) return false;
    for (final pid in portfolioIds) {
      if (_sameSalesforceAccountId(pid, onRow)) return true;
    }
    return false;
  }

  /// Profile read-only “Tagged account” for Internal users.
  /// Shows only the Salesforce account [accountId] assigned by admin on the user
  /// record (login / GET profile) — not the full opportunity-accounts portfolio.
  static Future<String> labeledTaggedAccountForInternalProfile() async {
    final tagged = await _readTaggedAccountFromProfileApi();
    var accountId = tagged.id.trim();
    if (accountId.isEmpty) {
      accountId = await refreshInternalTaggedAccountId();
    }
    if (accountId.isEmpty) {
      accountId = _localTaggedAccountIdFallback();
    }
    if (accountId.isEmpty) return 'None';

    final salesforceName = (await resolveAccountDisplayName(accountId)).trim();
    if (salesforceName.isNotEmpty &&
        !_isAccountIdPlaceholder(salesforceName)) {
      return salesforceName;
    }

    final fromApi = tagged.name?.trim() ?? '';
    if (fromApi.isNotEmpty && !_sameAsOwnCompany(fromApi)) return fromApi;

    final email = _loginEmail();
    if (email.isNotEmpty) {
      final postLoad = await _fetchByContactEmailPost(email);
      final match = findByAccountId(postLoad.choices, accountId);
      final matchName = match?.name.trim() ?? '';
      if (matchName.isNotEmpty &&
          !_sameAsOwnCompany(matchName) &&
          !_isAccountIdPlaceholder(matchName)) {
        return matchName;
      }
    }

    return 'None';
  }

  static String _ownCompanyName() {
    final fromPrefs = AuthDataHelper.getCompanyName().trim();
    if (fromPrefs.isNotEmpty) return fromPrefs;
    return DbHelper().getUserModel()?.companyName?.trim() ?? '';
  }

  static bool _sameAsOwnCompany(String label) {
    final company = _ownCompanyName();
    if (company.isEmpty) return false;
    return label.trim().toLowerCase() == company.toLowerCase();
  }

  static bool _isAccountIdPlaceholder(String name) {
    final text = name.trim().toLowerCase();
    return text == 'account' ||
        text == 'assigned account' ||
        text.startsWith('account …') ||
        text.startsWith('account ...');
  }

  static String _localTaggedAccountIdFallback() {
    final prefs = AuthDataHelper.getAccountId().trim();
    if (prefs.isNotEmpty) return prefs;
    final db = DbHelper().getUserModel();
    final fromDb = db?.accountId?.trim() ?? '';
    if (fromDb.isNotEmpty) return fromDb;
    return UserCache.localAccountId(
          userId: db?.userId,
          mongoId: db?.id,
        )?.trim() ??
        '';
  }

  static Future<({String id, String? name})>
  _readTaggedAccountFromProfileApi() async {
    const empty = (id: '', name: null as String?);
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) return empty;

    try {
      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.profile,
        token,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return empty;
      }
      final decoded = _decodeJson(response.data);
      if (decoded is! Map) return empty;
      final map = Map<String, dynamic>.from(decoded);

      final accountId = UserData.parseAccountIdFromPayload(map)?.trim() ?? '';
      final accountName =
          UserData.parseTaggedAccountNameFromPayload(map)?.trim();

      if (accountId.isNotEmpty) {
        _persistTaggedAccountId(accountId);
        debugPrint(
          'SalesAccountDirectory: tagged account from profile '
          'id=$accountId name=${accountName ?? "(lookup)"}',
        );
      } else {
        debugPrint(
          'SalesAccountDirectory: profile had no tagged accountId. '
          'rootKeys=${map.keys.toList()} '
          'userKeys=${UserData.resolveUserJson(map)?.keys.toList()}',
        );
      }

      return (
        id: accountId,
        name:
            accountName != null && accountName.isNotEmpty ? accountName : null,
      );
    } catch (e) {
      debugPrint('SalesAccountDirectory tagged profile read: $e');
      return empty;
    }
  }

  static bool _sameSalesforceAccountId(String? a, String? b) {
    final x = a?.trim().toLowerCase() ?? '';
    final y = b?.trim().toLowerCase() ?? '';
    if (x.isEmpty || y.isEmpty) return x == y;
    if (x == y) return true;
    final shortX = x.length >= 15 ? x.substring(0, 15) : x;
    final shortY = y.length >= 15 ? y.substring(0, 15) : y;
    return shortX == shortY;
  }

  static bool sameSalesforceAccountId(String? a, String? b) =>
      _sameSalesforceAccountId(a, b);

  static bool isSalesforceContactId(String id) {
    final t = id.trim();
    return (t.length == 15 || t.length == 18) && t.startsWith('003');
  }

  static String? canonicalAccountIdForAdminTag(
    String? raw, {
    List<SalesAccountChoice>? choices,
  }) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    String? best;
    if (choices != null) {
      for (final row in choices) {
        if (!_sameSalesforceAccountId(row.id, trimmed)) continue;
        final candidate = (row.accountIdForApi ?? row.id).trim();
        if (candidate.isEmpty || isSalesforceContactId(candidate)) continue;
        if (best == null || candidate.length > best.length) {
          best = candidate;
        }
      }
    }

    if (best != null && !isSalesforceContactId(best)) return best;
    if (isSalesforceContactId(trimmed)) return null;
    return trimmed;
  }

  static SalesAccountChoice? findChoiceByDisplayName(
    List<SalesAccountChoice> choices,
    String label,
  ) {
    final needle = label.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final row in choices) {
      if (row.name.trim().toLowerCase() == needle) return row;
    }
    return null;
  }

  /// Match a Salesforce account id to a row from [loadForCurrentUser].
  static SalesAccountChoice? findByAccountId(
    List<SalesAccountChoice> choices,
    String accountId,
  ) {
    final id = accountId.trim();
    if (id.isEmpty) return null;
    for (final choice in choices) {
      if (_sameSalesforceAccountId(choice.id, id)) return choice;
    }
    return null;
  }

  static List<SalesAccountChoice> _mergeAccountLists(
    List<SalesAccountChoice> rows,
  ) {
    return rows;
  }

  static void _persistTaggedAccountId(String accountId) {
    final id = accountId.trim();
    if (id.isEmpty) return;
    AuthDataHelper.saveAccountId(id);
    final base = DbHelper().getUserModel();
    if (base != null) {
      DbHelper().saveUserModel(base.copyWith(accountId: id));
    }
  }

  static void _persistTaggedAccountIdIfEmpty(String accountId) {
    if (AuthDataHelper.getAccountId().trim().isNotEmpty) return;
    if (DbHelper().getUserModel()?.accountId?.trim().isNotEmpty ?? false) {
      return;
    }
    _persistTaggedAccountId(accountId);
  }

  /// POST Contact.Email lookup, or GET OwnerId when [allowProspectiveEmail] is false.
  static Future<SalesAccountLoad> loadForEmail(
    String email, {
    required bool allowProspectiveEmail,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return const SalesAccountLoad(
        choices: [],
        errorMessage: 'Email is required',
      );
    }

    if (!allowProspectiveEmail) {
      return _fetchByOwnerId();
    }

    if (!_canPostContactEmailLookup(trimmed)) {
      return const SalesAccountLoad(
        choices: [],
        errorMessage:
            'You can only look up accounts for your own email address',
      );
    }

    return _fetchByContactEmailPost(trimmed);
  }

  /// Admin add/edit Internal user — POST prospective Internal user's email only.
  static Future<SalesAccountLoad> loadForAdminAccountPicker({
    required String internalUserEmail,
  }) async {
    if (!AuthDataHelper.canLookupAccountsByContactEmail()) {
      return const SalesAccountLoad(
        choices: [],
        errorMessage: 'Only admin can load accounts for another email',
      );
    }

    final email = internalUserEmail.trim();
    if (email.isEmpty) {
      return const SalesAccountLoad(
        choices: [],
        errorMessage:
            'Enter the Internal user’s email, then load accounts (POST)',
      );
    }

    return _fetchByContactEmailPost(email);
  }

  static bool _canPostContactEmailLookup(String targetEmail) {
    if (AuthDataHelper.canLookupAccountsByContactEmail()) return true;
    if (!_isInternalSalesUser()) return false;
    final own = _loginEmail().trim().toLowerCase();
    if (own.isEmpty) return false;
    return targetEmail.trim().toLowerCase() == own;
  }

  static Future<String> resolveAccountDisplayName(String accountId) async {
    final id = accountId.trim();
    if (id.isEmpty) return '';

    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) {
      return id.length >= 6 ? 'Account …${id.substring(id.length - 6)}' : id;
    }

    try {
      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.salesforceAccountById(id),
        token,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return id.length >= 6 ? 'Account …${id.substring(id.length - 6)}' : id;
      }
      final body = _decodeJson(response.data);
      if (body == null) {
        return id.length >= 6 ? 'Account …${id.substring(id.length - 6)}' : id;
      }
      final rows = parseAccounts(body);
      if (rows.isEmpty) {
        return id.length >= 6 ? 'Account …${id.substring(id.length - 6)}' : id;
      }
      return rows.first.name.trim();
    } catch (e) {
      debugPrint('SalesAccountDirectory account name: $e');
      return id.length >= 6 ? 'Account …${id.substring(id.length - 6)}' : id;
    }
  }

  static bool _isInternalSalesUser() {
    return AuthDataHelper.getUserType().toLowerCase().trim() == 'internal';
  }

  static String _loginEmail() {
    final fromPrefs = AuthDataHelper.getEmail().trim();
    if (fromPrefs.isNotEmpty) return fromPrefs;
    return DbHelper().getUserModel()?.email?.trim() ?? '';
  }

  /// Loads accounts for the salesperson [OwnerId] on the JWT (staging: POST + email).
  static Future<SalesAccountLoad> _fetchByOwnerId() async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) {
      debugPrint('SalesAccountDirectory: no auth token');
      return const SalesAccountLoad(choices: []);
    }

    final url = ApiConstants.opportunityAccounts;
    debugPrint(
      'SalesAccountDirectory: GET $url (OwnerId from token) '
      '(host=${AppConfig.domain}, app_name=${AppConfig.apiAppNameHeader})',
    );

    try {
      final response = await HttpClientHelper.getWithBearer(url, token);
      return _parseAccountResponse(response, label: 'GET+OwnerId');
    } catch (e, st) {
      debugPrint('SalesAccountDirectory GET: $e\n$st');
      return const SalesAccountLoad(
        choices: [],
        errorMessage: 'Could not load accounts (GET OwnerId)',
      );
    }
  }

  static Future<SalesAccountLoad> _fetchByContactEmailPost(String email) async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) {
      debugPrint('SalesAccountDirectory: no auth token');
      return const SalesAccountLoad(choices: []);
    }

    debugPrint(
      'SalesAccountDirectory: POST ${ApiConstants.opportunityAccounts} '
      'email=$email (Contact.Email)',
    );

    try {
      final response = await _postOpportunityAccounts(token, {
        'email': email.trim(),
      });
      return _parseAccountResponse(response, label: 'POST+ContactEmail');
    } catch (e, st) {
      debugPrint('SalesAccountDirectory POST: $e\n$st');
      return const SalesAccountLoad(
        choices: [],
        errorMessage: 'Could not load accounts',
      );
    }
  }

  static Future<dynamic> _postOpportunityAccounts(
    String token,
    Map<String, dynamic> body,
  ) {
    return HttpClientHelper.postWithBearer(
      ApiConstants.opportunityAccounts,
      token,
      body: jsonEncode(body),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  static SalesAccountLoad _parseAccountResponse(
    dynamic response, {
    required String label,
  }) {
    final code = response.statusCode as int? ?? 0;
    final ok = code >= 200 && code < 300;

    if (!ok) {
      final message = parseApiErrorMessage(
        response.data,
        fallback: response.message ?? response.data,
      );
      debugPrint('SalesAccountDirectory $label: HTTP $code $message');
      return SalesAccountLoad(choices: const [], errorMessage: message);
    }

    var body = _decodeJson(response.data);
    if (body == null) {
      debugPrint('SalesAccountDirectory $label: empty or non-JSON body');
      return const SalesAccountLoad(choices: []);
    }

    body = _unwrapStringifiedPayload(body);

    final apiError = _readApiFailureMessage(body);
    if (apiError != null) {
      debugPrint('SalesAccountDirectory $label: $apiError');
      return SalesAccountLoad(choices: const [], errorMessage: apiError);
    }

    final rawRows = _rowsOf(body);
    var accounts = parseAccounts(body);
    accounts = _dedupeByAccountId(accounts);
    if (accounts.isEmpty && _isInternalSalesUser()) {
      accounts = _mergeInternalFallbackAccounts(accounts, body);
    }

    debugPrint(
      'SalesAccountDirectory $label: parsed ${accounts.length} account(s) '
      'from ${rawRows.length} raw row(s)',
    );
    if (accounts.isEmpty && body is Map) {
      final map = Map<String, dynamic>.from(body);
      debugPrint(
        'SalesAccountDirectory: response keys ${map.keys.take(16).toList()}',
      );
      final rawAccounts = map['accounts'] ?? map['Accounts'];
      debugPrint(
        'SalesAccountDirectory: totalAccounts=${map['totalAccounts']} '
        'accounts type=${rawAccounts?.runtimeType}',
      );
      if (rawAccounts is List && rawAccounts.isNotEmpty) {
        final first = rawAccounts.first;
        if (first is Map) {
          debugPrint(
            'SalesAccountDirectory: accounts[0] keys ${first.keys.take(14).toList()}',
          );
        }
      }
    }
    return SalesAccountLoad(choices: accounts);
  }

  static dynamic _unwrapStringifiedPayload(dynamic body) {
    if (body is! Map) return body;
    final map = Map<String, dynamic>.from(body);
    for (final key in ['data', 'body', 'result', 'accounts', 'Accounts']) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        try {
          map[key] = jsonDecode(value);
        } catch (_) {}
      }
    }
    return map;
  }

  /// RMS staging: `{ totalAccounts, success, accounts: [...] }` (or string / map).
  static List<dynamic> _coerceToRowList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return _flattenAccountRows(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        return _coerceToRowList(jsonDecode(value));
      } catch (_) {}
      return const [];
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in [
        'records',
        'data',
        'items',
        'list',
        'rows',
        'accounts',
        'users',
      ]) {
        final nested = map[key];
        final rows = _coerceToRowList(nested);
        if (rows.isNotEmpty) return rows;
      }
      final values = map.values.toList();
      if (values.isNotEmpty && values.every((v) => v is Map)) {
        return values;
      }
      if (_rowLooksLikeAccount(map) || _rowLooksLikeCustomerUser(map)) {
        return [map];
      }
    }
    return const [];
  }

  static List<dynamic> _extractTopLevelAccountRows(Map<String, dynamic> map) {
    for (final key in ['accounts', 'Accounts', 'assignedAccounts']) {
      final rows = _coerceToRowList(map[key]);
      if (rows.isNotEmpty) return rows;
    }
    return const [];
  }

  /// Loads tagged `accountId` for Internal user from prefs, DB, then GET profile.
  static Future<String> refreshInternalTaggedAccountId({
    bool forceProfileFetch = false,
  }) async {
    var accountId = AuthDataHelper.getAccountId().trim();
    final dbUser = DbHelper().getUserModel();
    if (accountId.isEmpty) {
      accountId = dbUser?.accountId?.trim() ?? '';
    }
    if (!forceProfileFetch && accountId.isNotEmpty) {
      return accountId;
    }

    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) return accountId;

    try {
      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.profile,
        token,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return accountId;
      }
      final decoded = _decodeJson(response.data);
      final fromApi = UserData.parseAccountIdFromPayload(
        decoded is Map ? Map<String, dynamic>.from(decoded) : decoded,
      );
      if (fromApi != null && fromApi.isNotEmpty) {
        accountId = fromApi;
        AuthDataHelper.saveAccountId(fromApi);
        final base = dbUser ?? DbHelper().getUserModel();
        if (base != null) {
          DbHelper().saveUserModel(base.copyWith(accountId: fromApi));
        }
        debugPrint('SalesAccountDirectory: profile tagged accountId=$fromApi');
      }
    } catch (e) {
      debugPrint('SalesAccountDirectory refreshTaggedAccount: $e');
    }
    return accountId;
  }

  /// When `accounts: []` but admin tagged a Salesforce account on the user profile.
  static Future<List<SalesAccountChoice>> _choicesFromTaggedProfile({
    required bool refresh,
  }) async {
    var accountId = await refreshInternalTaggedAccountId(
      forceProfileFetch: refresh,
    );
    if (accountId.isEmpty) return const [];

    var displayName = await resolveAccountDisplayName(accountId);
    if (displayName.isEmpty) {
      displayName =
          accountId.length >= 6
              ? 'Account …${accountId.substring(accountId.length - 6)}'
              : 'Assigned account';
    }

    return [
      SalesAccountChoice(id: accountId, name: displayName, fromApi: true),
    ];
  }

  static List<SalesAccountChoice> _mergeInternalFallbackAccounts(
    List<SalesAccountChoice> parsed,
    dynamic body,
  ) {
    final merged = [...parsed];
    final seen = merged.map((c) => c.id.trim().toLowerCase()).toSet();

    void addAll(Iterable<SalesAccountChoice> rows) {
      for (final row in rows) {
        final id = row.id.trim();
        if (id.isEmpty || !seen.add(id.toLowerCase())) continue;
        merged.add(row);
      }
    }

    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      for (final key in [
        'account',
        'Account',
        'taggedAccount',
        'defaultAccount',
      ]) {
        final node = map[key];
        if (node is Map) {
          addAll(_parseRowExpanded(node));
        }
      }
    }

    final taggedId = AuthDataHelper.getAccountId().trim();
    final dbId = DbHelper().getUserModel()?.accountId?.trim() ?? '';
    final id = taggedId.isNotEmpty ? taggedId : dbId;
    if (id.isNotEmpty) {
      var name = AuthDataHelper.getCompanyName().trim();
      if (name.isEmpty) {
        name = DbHelper().getUserModel()?.companyName?.trim() ?? '';
      }
      if (name.isEmpty) {
        name =
            id.length >= 6
                ? 'Account …${id.substring(id.length - 6)}'
                : 'Assigned account';
      }
      addAll([SalesAccountChoice(id: id, name: name, fromApi: true)]);
    }

    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  static List<SalesAccountChoice> _dedupeByAccountId(
    List<SalesAccountChoice> rows,
  ) {
    final byId = <String, SalesAccountChoice>{};
    for (final row in rows) {
      final id = row.id.trim().toLowerCase();
      if (id.isEmpty) continue;
      final existing = byId[id];
      if (existing == null) {
        byId[id] = row;
        continue;
      }
      if ((existing.userType ?? '').isEmpty &&
          (row.userType ?? '').isNotEmpty) {
        byId[id] = row;
      }
    }
    final list =
        byId.values.toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return list;
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
    if (status is num) {
      if (status >= 200 && status < 300) return false;
      return status == 0;
    }
    final text = status.toString().toLowerCase().trim();
    return text == 'false' || text == 'failed' || text == 'error';
  }

  static List<SalesAccountChoice> parseAccounts(dynamic body) {
    final rows = _rowsOf(body);
    final parsed = <SalesAccountChoice>[];
    final seenIds = <String>{};

    for (final row in rows) {
      final choices = _parseRowExpanded(row);
      for (final choice in choices) {
        final dedupeKey =
            '${choice.id.trim().toLowerCase()}|${(choice.userType ?? '').trim().toLowerCase()}';
        if (seenIds.add(dedupeKey)) {
          parsed.add(choice);
        }
      }
    }
    parsed.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return parsed;
  }

  static List<SalesAccountChoice> _parseRowExpanded(dynamic row) {
    if (row is! Map) return const [];
    var map = Map<String, dynamic>.from(row);

    final nestedAccount =
        map['Account'] ?? map['account'] ?? map['accountDetails'];
    if (nestedAccount is Map) {
      map = {...map, ...Map<String, dynamic>.from(nestedAccount)};
    }

    final sfType = _salesforceObjectType(map);
    final preferAccountId =
        sfType.contains('opportunity') ||
        sfType.contains('contact') ||
        map.containsKey('AccountId');

    var id =
        preferAccountId
            ? _firstNonEmpty(map, const [
              'AccountId',
              'accountId',
              'account_id',
              'salesforceAccountId',
              'sfAccountId',
            ])
            : null;
    id ??= _firstNonEmpty(map, const [
      'accountId',
      'AccountId',
      'account_id',
      'salesforceAccountId',
      'sfAccountId',
      'sfId',
      'SF_Account_Id__c',
      'id',
      'Id',
      '_id',
    ]);
    id ??= _idFromNestedAccountRef(map);
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
      'Label',
      'label',
    ]);
    name ??= _userDisplayName(map);

    var idText = id?.trim() ?? '';
    var nameText = name?.trim() ?? '';
    if (idText.isEmpty) return const [];

    if (sfType.contains('contact') || isSalesforceContactId(idText)) {
      final accountOnly =
          _firstNonEmpty(map, const [
            'AccountId',
            'accountId',
            'account_id',
            'salesforceAccountId',
          ]) ??
          _idFromNestedAccountRef(map);
      if (accountOnly == null || accountOnly.trim().isEmpty) {
        return const [];
      }
      idText = accountOnly.trim();
    }

    if (nameText.isEmpty) {
      nameText =
          idText.length >= 6
              ? 'Account …${idText.substring(idText.length - 6)}'
              : 'Account';
    }

    final nestedUsers =
        map['users'] ??
        map['Users'] ??
        map['contacts'] ??
        map['Contacts'] ??
        map['rmsUsers'] ??
        map['customers'];
    if (nestedUsers is List && nestedUsers.isNotEmpty) {
      final parsed = <SalesAccountChoice>[];
      for (final entry in nestedUsers) {
        final type = _readUserType(entry) ?? _readUserType(map);
        parsed.add(
          SalesAccountChoice(
            id: idText,
            name: nameText,
            userType: type,
            fromApi: true,
          ),
        );
      }
      return parsed;
    }

    return [
      SalesAccountChoice(
        id: idText,
        name: nameText,
        userType: _readUserType(map),
        fromApi: true,
      ),
    ];
  }

  static String? _readUserType(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    return _firstNonEmpty(map, const [
      'userType',
      'UserType',
      'user_type',
      'customerType',
      'CustomerType',
      'customer_type',
      'rmsUserType',
      'RMS_User_Type__c',
      'tier',
      'Tier',
      'type',
      'Type',
    ]);
  }

  static String? _userDisplayName(Map<String, dynamic> map) {
    final company = map['companyName']?.toString().trim() ?? '';
    if (company.isNotEmpty) return company;
    final first = map['firstName']?.toString().trim() ?? '';
    final last = map['lastName']?.toString().trim() ?? '';
    final full = [first, last].where((p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return map['email']?.toString().trim();
  }

  static String? _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _idFromNestedAccountRef(Map<String, dynamic> map) {
    for (final key in ['account', 'Account', 'accountDetails', 'Account__r']) {
      final nested = map[key];
      if (nested is! Map) continue;
      final id = _firstNonEmpty(Map<String, dynamic>.from(nested), const [
        'accountId',
        'AccountId',
        'Id',
        'id',
      ]);
      if (id != null && id.isNotEmpty) return id;
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

  static String _salesforceObjectType(Map<String, dynamic> map) {
    final attributes = map['attributes'];
    if (attributes is! Map) return '';
    return attributes['type']?.toString().toLowerCase().trim() ?? '';
  }

  static List<dynamic> _flattenAccountRows(List<dynamic> list) {
    final out = <dynamic>[];
    for (final item in list) {
      if (item is Map) {
        final row = Map<String, dynamic>.from(item);
        final records = row['records'];
        if (records is List) {
          out.addAll(records);
          continue;
        }
        if (_rowLooksLikeAccount(row) || _rowLooksLikeCustomerUser(row)) {
          out.add(item);
          continue;
        }
        final nested = _rowsOf(item);
        if (nested.isNotEmpty) {
          out.addAll(nested);
          continue;
        }
      }
      out.add(item);
    }
    return out;
  }

  static bool _rowLooksLikeCustomerUser(Map<String, dynamic> map) {
    final hasAccount =
        _firstNonEmpty(map, const ['accountId', 'AccountId', 'account_id']) !=
        null;
    return hasAccount &&
        (_readUserType(map) != null ||
            map.containsKey('email') ||
            map.containsKey('companyName'));
  }

  static List<dynamic> _rowsOf(dynamic body) {
    if (body is List) return _flattenAccountRows(body);
    if (body is! Map) return const [];

    final map = Map<String, dynamic>.from(body);

    final fromAccountsKey = _extractTopLevelAccountRows(map);
    if (fromAccountsKey.isNotEmpty) return fromAccountsKey;

    final data = map['data'];
    if (data is List) return _flattenAccountRows(data);
    if (data is Map) {
      final records = data['records'];
      if (records is List) return records;
      final nested = _rowsOf(data);
      if (nested.isNotEmpty) return nested;
    }

    if (map['records'] is List) return map['records'] as List;

    for (final key in [
      'data',
      'accounts',
      'records',
      'result',
      'items',
      'body',
      'accountsData',
      'users',
      'Users',
      'customerUsers',
      'rmsUsers',
      'assignedAccounts',
      'account',
      'Account',
      'rows',
      'list',
    ]) {
      final value = map[key];
      if (value is List) return _flattenAccountRows(value);
      if (value is Map) {
        final nested = _rowsOf(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    if (_rowLooksLikeAccount(map) || _rowLooksLikeCustomerUser(map)) {
      return [map];
    }
    return const [];
  }

  static bool _rowLooksLikeAccount(Map<String, dynamic> map) {
    if (_firstNonEmpty(map, const [
          'accountId',
          'AccountId',
          'account_id',
          'salesforceAccountId',
          'Id',
          'id',
        ]) !=
        null) {
      return true;
    }
    if (_idFromNestedAccountRef(map) != null) return true;
    return _idFromSalesforceAttributes(map) != null;
  }
}
