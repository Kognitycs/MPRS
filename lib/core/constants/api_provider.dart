import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart' hide MultipartFile;
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/app_secrets.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/model/common/user_data.dart';
import 'package:mprs_android/model/get_shipment_model.dart';
import 'package:path/path.dart';

import '../../model/booking_detail_model.dart';
import '../../model/get_booking_list_model.dart';
import '../../model/get_booking_list_model_new.dart' as booking;
import '../../model/order_document_model.dart';
import '../../model/get_quote_detail_model.dart';
import '../../model/quote_line_details_result.dart';
import '../../model/notification_item.dart';
import '../../model/notifications_response.dart';
import '../../model/saved_quotations_model.dart';
import '../utils/progress_dialog.dart';
import 'api_constants.dart';
import 'base_client.dart';
import 'data_response.dart';
import '../../service/http_client_helper.dart';
import '../../service/reserved_quote_store.dart';
import '../../service/fcm_token_service.dart';
import '../../service/notification/notification_inbox_store.dart';
import '../../service/notification/notification_poll_service.dart';

/// Counts from last `fetchOrderDocuments` — backend vs UI.
class OrderDocumentsFetchStats {
  final String orderId;
  final int backendFileCount;
  final int uiFileCount;
  final int skippedDuplicates;
  final int skippedQuotePdf;
  final int skippedNoDisplayData;
  final int skippedInvalidItem;
  final List<String> notShownInUi;

  const OrderDocumentsFetchStats({
    required this.orderId,
    required this.backendFileCount,
    required this.uiFileCount,
    required this.skippedDuplicates,
    required this.skippedQuotePdf,
    required this.skippedNoDisplayData,
    required this.skippedInvalidItem,
    required this.notShownInUi,
  });

  int get notShownCount => backendFileCount - uiFileCount;
}

/// Result for Books → In Progress tab (mirrors Shipments tab data).
class InProgressShipmentData {
  final List<booking.Records> records;
  final Map<String, SavedQuotationsModel> adminQuoteById;
  final Map<String, Records> shipmentRecordById;

  const InProgressShipmentData({
    required this.records,
    this.adminQuoteById = const {},
    this.shipmentRecordById = const {},
  });
}

class ApiProvider {
  static final ApiProvider _singleton = ApiProvider._internal();
  late BaseClient _baseClient;

  /// Set after each document fetch for debug (backend vs UI).
  static OrderDocumentsFetchStats? lastDocumentStats;

  factory ApiProvider() {
    return _singleton;
  }

  ApiProvider._internal() {
    _baseClient = BaseClient();
  }

  /// Returns the logged-in user's Salesforce account ID.
  /// DbHelper (written on login & on profile refresh) is the primary source.
  /// Falls back to the separately stored AuthDataHelper key so that a stale
  /// DbHelper record (e.g. after a profile fetch that didn't include accountId)
  /// never silently breaks quote/booking fetches.
  String _accountId() {
    final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
    if (fromDb.isNotEmpty) return fromDb;
    return AuthDataHelper.getAccountId().trim();
  }

  /// ------------------------- Auth apis ------------------------------------

  ///----->> SignIn Api----->>
  Future<DataResponse<UserData?>> signIn({
    required Map<String, dynamic> data,
  }) async {
    ProgressLoader.show(Get.context!);
    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.login,
      method: DioMethod.post,
      body: data,
    );
    try {
      var response = await _baseClient.handleRequest(apiRequest);
      ProgressLoader.hide(Get.context!);
      return DataResponse.fromJson(response, (data) => UserData.fromJson(data));
    } catch (e) {
      ProgressLoader.hide(Get.context!);
      final res = (e as dynamic).response;
      if (res != null) {
        return DataResponse.fromJson(res.data, (data) => null);
      }
      return DataResponse(message: e.toString());
    }
  }

  /// Inbox for External / VIP / VVIP (admin-pushed, filtered by role).
  /// Fetch notification inbox from the server.
  ///
  /// • Admin / Internal  → admin/get/allNotifications
  /// • External / VIP / VVIP → FCM delivery + local SQLite only (user API 404)
  // API keys required by the server — included in every notification request
  // so the server can authenticate the service call regardless of JWT role.
  static Map<String, String> get _notifApiKeys => {
    ...AppConfig.apiHeaders,
    ...AppSecrets.apiKeyHeaders,
  };

  Future<List<NotificationItem>> fetchInboxNotifications() async {
    final userType = AuthDataHelper.getUserType().trim();
    if (userType.isEmpty) return [];

    final token = AuthDataHelper.getToken();
    if (token.isEmpty) return [];

    final isPrivileged =
        AuthDataHelper.isAdminUser() || AuthDataHelper.isInternalUser();

    debugPrint('🔔 Inbox fetch: userType=$userType');

    if (isPrivileged) {
      return _tryInboxUrl(ApiConstants.getAllNotifications, token, userType);
    }

    // External / VIP / VVIP — inbox comes from FCM → SQLite (user API returns 404).
    debugPrint('🔔 Inbox fetch skipped for $userType — FCM local cache only');
    return [];
  }

  Future<List<NotificationItem>> _tryInboxUrl(
    String baseUrl,
    String token,
    String userType, {
    Map<String, String>? extraHeaders,
  }) async {
    // derive a short label for logging (strip query string)
    final label = baseUrl.split('/').last.split('?').first;
    try {
      final list = await _fetchInboxPagesHttp(
        baseUrl,
        token,
        userType,
        extraHeaders: extraHeaders,
      );
      debugPrint('🔔 Inbox [$label] → ${list.length} items');
      return list;
    } catch (e) {
      debugPrint('🔔 Inbox [$label] → error: $e');
      return [];
    }
  }

  Future<List<NotificationItem>> _fetchInboxPagesHttp(
    String baseUrl,
    String token,
    String userType, {
    bool serverPrefiltered = false,
    Map<String, String>? extraHeaders,
  }) async {
    final all = <NotificationItem>[];

    for (var page = 1; page <= 30; page++) {
      // Use '&' if baseUrl already contains query params, '?' otherwise.
      final sep = baseUrl.contains('?') ? '&' : '?';
      final url = '$baseUrl${sep}page=$page&isActive=true';
      final resp = await HttpClientHelper.getWithBearer(
        url,
        token,
        headers: extraHeaders,
      );
      debugPrint('🔔 Inbox page $page → ${resp.statusCode}');
      if (resp.statusCode != 200 && resp.statusCode != 201) break;

      final batch = _parseInboxResponse(resp.data);
      if (batch.isEmpty) break;

      final visible =
          batch
              .where(
                (n) => n.isVisibleToUserType(
                  userType,
                  serverPrefiltered: serverPrefiltered,
                ),
              )
              .toList();
      all.addAll(visible);

      final totalPages = _inboxTotalPagesFromBody(resp.data);
      if (page >= totalPages) break;
    }

    return all;
  }

  /// Same as [_fetchInboxPagesHttp] but uses API-keys-only auth (no JWT).
  /// Used as fallback when External JWT results in 403 on admin endpoints.
  Future<List<NotificationItem>> _fetchInboxPagesHttpNoJwt(
    String baseUrl,
    String userType,
  ) async {
    final all = <NotificationItem>[];

    for (var page = 1; page <= 30; page++) {
      final sep = baseUrl.contains('?') ? '&' : '?';
      final url = '$baseUrl${sep}page=$page&isActive=true';
      debugPrint('🔔 Inbox (no-JWT) page $page → fetching...');
      final resp = await HttpClientHelper.getWithApiKeysOnly(url);
      debugPrint('🔔 Inbox (no-JWT) page $page → ${resp.statusCode}');
      if (resp.statusCode != 200 && resp.statusCode != 201) break;

      final batch = _parseInboxResponse(resp.data);
      if (batch.isEmpty) break;

      final visible =
          batch.where((n) => n.isVisibleToUserType(userType)).toList();
      all.addAll(visible);

      final totalPages = _inboxTotalPagesFromBody(resp.data);
      if (page >= totalPages) break;
    }

    return all;
  }

  int _inboxTotalPagesFromBody(dynamic body) {
    try {
      final decoded = body is String ? jsonDecode(body) : body;
      if (decoded is! Map) return 1;
      var map = Map<String, dynamic>.from(decoded);
      // Direct totalPages field (admin/get/allNotifications style)
      if (map['totalPages'] != null) {
        final tp = int.tryParse(map['totalPages'].toString()) ?? 1;
        return tp > 0 ? tp : 1;
      }
      map = _unwrapInboxPayload(map);
      final tp = map['totalPages'];
      if (tp != null) {
        final pages = int.tryParse(tp.toString()) ?? 1;
        return pages > 0 ? pages : 1;
      }
    } catch (_) {}
    return 1;
  }

  List<NotificationItem> _parseInboxResponse(dynamic response) {
    try {
      dynamic decoded = response;
      if (response is String && response.trim().isNotEmpty) {
        decoded = jsonDecode(response);
      }

      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (decoded is! Map) return [];

      var map = Map<String, dynamic>.from(decoded);
      map = _unwrapInboxPayload(map);

      if (map['data'] is List &&
          (map.containsKey('currentPage') || map.containsKey('totalPages'))) {
        return NotificationsResponse.fromJson(map).data;
      }

      if (map['data'] is List) {
        return (map['data'] as List)
            .whereType<Map>()
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (map['notifications'] is List) {
        return (map['notifications'] as List)
            .whereType<Map>()
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ parseInbox: $e');
    }
    return [];
  }

  /// Flattens `{ data: { data: [...], currentPage } }` or `{ body: { ... } }`.
  Map<String, dynamic> _unwrapInboxPayload(Map<String, dynamic> map) {
    for (final key in ['data', 'body', 'result']) {
      final nested = map[key];
      if (nested is Map) {
        final inner = Map<String, dynamic>.from(nested);
        if (inner['data'] is List ||
            inner.containsKey('currentPage') ||
            inner.containsKey('totalPages')) {
          return inner;
        }
      }
    }
    return map;
  }

  ///------------- GET Saved Quotations-------------

  Future<DataResponse<List<SavedQuotationsModel>>> savedQuotations() async {
    final isAdmin = AuthDataHelper.isAdminUser();
    final accountId = _accountId();

    if (!isAdmin && accountId.isEmpty) {
      return DataResponse(
        message: 'Account id is required',
        success: false,
        body: [],
      );
    }

    final url = ApiConstants.userQuotes(accountId: isAdmin ? null : accountId);

    ApiRequest apiRequest = ApiRequest(url: url, method: DioMethod.get);

    debugPrint('🚀 user/quote ${isAdmin ? "(admin — all users)" : ""}: $url');

    try {
      var response = await _baseClient.handleRequest(apiRequest);
      debugPrint('✅ user/quote RESPONSE RECEIVED');

      var quotes = _parseSavedQuotesList(response);
      final appQuoteCount = quotes.length;

      if (isAdmin) {
        quotes = _allQuotesForAdminList(quotes);
        debugPrint(
          '✅ Admin quotations: ${quotes.length} quotes '
          '(from user/quote, no account_id)',
        );
      } else {
        final sfQuotes = await _fetchAccountQuotesFromSf(accountId);
        quotes = _mergeAppAndSfQuotes(quotes, sfQuotes);
        debugPrint(
          '✅ Recent quotations: ${quotes.length} merged '
          '(user/quote=$appQuoteCount, sf=${sfQuotes.length})',
        );
        quotes = SavedQuotationsModel.forRecentList(quotes);
      }

      final status = response is Map ? response['status'] : null;
      return DataResponse(
        success: status == 200 || status == true || quotes.isNotEmpty,
        code: status is int ? status : null,
        message: response is Map ? response['message']?.toString() : null,
        body: quotes,
      );
    } catch (e) {
      debugPrint('❌ API PROVIDER ERROR: $e');
      return DataResponse(message: e.toString(), success: false, body: []);
    }
  }

  /// All users: quotations whose Opportunity was created from the RMS app.
  Future<List<SavedQuotationsModel>> fetchAdminAppCreatedQuotations() async {
    final sfRms = await _fetchAdminRmsQuotesFromSf();
    final appQuotes = await _fetchAllUsersQuotesFromApi();

    final byId = <String, SavedQuotationsModel>{};

    // SF list = source of truth (all accounts, Opp_From_RMS_App__c = true).
    for (final quote in sfRms) {
      final id = quote.id?.trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = quote.asAppOpportunityQuote();
    }

    // user/quote (all users): include any row with RMS flag; enrich SF rows.
    for (final quote in appQuotes) {
      final id = quote.id?.trim();
      if (id == null || id.isEmpty) continue;
      if (!quote.isOpportunityFromRms && !byId.containsKey(id)) continue;
      final merged = SavedQuotationsModel.merge([byId[id], quote]) ?? quote;
      byId[id] =
          merged.isOpportunityFromRms ? merged : merged.asAppOpportunityQuote();
    }

    final result =
        SavedQuotationsModel.sortNewestFirst(
          byId.values.toList(),
        ).where((q) => !q.isTestQuoteData).toList();
    debugPrint(
      '✅ Admin app-created quotations: ${result.length} '
      '(SF RMS=${sfRms.length}, user/quote all users=${appQuotes.length}, '
      'excl. QT test)',
    );
    return result;
  }

  /// Admin Booked tab: confirmed orders on RMS app opportunities only.
  Future<List<booking.Records>> fetchAdminRmsBookedOrders() async {
    try {
      debugPrint(
        '📡 Admin RMS booked orders: ${ApiConstants.adminRmsOpportunityOrdersSf}',
      );
      final response = await _baseClient.handleRequest(
        ApiRequest(
          url: ApiConstants.adminRmsOpportunityOrdersSf,
          method: DioMethod.get,
        ),
      );
      final orders = _parseBookingRecordsList(response);
      final sorted = booking.Records.sortNewestFirst(orders);
      debugPrint('✅ Admin RMS booked orders: ${sorted.length}');
      return sorted;
    } catch (e) {
      debugPrint('⚠️ Admin RMS booked orders failed: $e');
      return [];
    }
  }

  /// Admin In Progress tab: RMS app quotes not yet Accepted/Denied.
  Future<List<booking.Records>> fetchAdminRmsInProgressBookings() async {
    final data = await fetchInProgressShipmentData();
    return data.records;
  }

  /// Books → In Progress tab: same data as Shipments tab (Import + Export merged).
  /// Admin sees all app-created quotations; other users see their own account only.
  Future<InProgressShipmentData> fetchInProgressShipmentData({
    bool accountScoped = false,
  }) async {
    if (AuthDataHelper.isAdminUser() && !accountScoped) {
      return _fetchAdminInProgressShipmentData();
    }
    return _fetchUserInProgressShipmentData();
  }

  Future<InProgressShipmentData> _fetchAdminInProgressShipmentData() async {
    final bookedQuoteIds = await _fetchBookedQuoteIds();
    final quotes =
        (await fetchAdminAppCreatedQuotations())
            .where((q) => !q.isTestQuoteData)
            .where((q) => !q.isEmptyOpportunityShellQuote)
            .where((q) => q.shouldShowInQuotationsList)
            .where((q) => SavedQuotationsModel.isQuotationsTabStatus(q.status))
            .where((q) {
              final id = q.id?.trim() ?? '';
              return id.isEmpty || !bookedQuoteIds.contains(id);
            })
            .toList();

    final adminQuoteById = <String, SavedQuotationsModel>{
      for (final q in quotes)
        if (q.id != null && q.id!.trim().isNotEmpty) q.id!.trim(): q,
    };

    final shipmentById = <String, Records>{
      for (final entry in adminQuoteById.entries)
        entry.key: Records.fromJson(entry.value.toShipmentRecordJson()),
    };

    await _enrichInProgressQuotesContainerFields(
      quoteById: adminQuoteById,
      shipmentById: shipmentById,
    );

    final records = booking.Records.sortNewestFirst(
      SavedQuotationsModel.sortNewestFirst(adminQuoteById.values.toList())
          .map((q) => booking.Records.fromJson(q.toInProgressBookingJson()))
          .toList(),
    );

    debugPrint(
      '✅ Admin in-progress (shipments data): ${records.length} quotation(s)',
    );
    return InProgressShipmentData(
      records: records,
      adminQuoteById: adminQuoteById,
      shipmentRecordById: shipmentById,
    );
  }

  Future<InProgressShipmentData> _fetchUserInProgressShipmentData() async {
    final accountId = _accountId();
    if (accountId.isEmpty) {
      debugPrint('⚠️ In-progress quotes: account id is empty');
      return const InProgressShipmentData(records: []);
    }

    debugPrint('📡 Loading in-progress quotes for account: $accountId');

    final bookedQuoteIds = await _fetchBookedQuoteIds(accountId: accountId);
    final reservedIds = ReservedQuoteStore.ids();
    final mergedQuotes = await _fetchMergedAccountQuotes(accountId);
    final quoteById = <String, SavedQuotationsModel>{};
    final shipmentById = <String, Records>{};

    for (final quote in mergedQuotes) {
      if (!_quoteBelongsToAccount(quote, accountId)) continue;
      if (quote.isTestQuoteData) continue;
      final id = quote.id?.trim() ?? '';
      final reserved =
          id.isNotEmpty &&
          (reservedIds.contains(id) || _isReserveYourSpaceStatus(quote.status));
      if (!reserved && quote.isEmptyOpportunityShellQuote) continue;
      if (!reserved && !quote.shouldShowInQuotationsList) continue;
      final status = SavedQuotationsModel.normalizeQuoteListStatus(
        quote.status,
      );
      if (status == 'denied') continue;
      // Draft + accepted (not booked). A reserved quote stays visible even
      // when Salesforce status is no longer Draft / Presented / Accepted.
      if (!reserved && !SavedQuotationsModel.isQuotationsTabStatus(status)) {
        continue;
      }
      if (id.isEmpty || bookedQuoteIds.contains(id)) continue;
      final visible =
          reserved && !SavedQuotationsModel.isQuotationsTabStatus(status)
              ? (SavedQuotationsModel.merge([
                    SavedQuotationsModel(
                      id: quote.id,
                      name: quote.name,
                      status: 'Accepted',
                    ),
                    quote,
                  ]) ??
                  quote)
              : quote;
      quoteById[id] = visible;
      shipmentById[id] = Records.fromJson(visible.toShipmentRecordJson());
    }

    final importRecords = await _fetchUserShipmentRecordsForInProgress(
      ApiConstants.getBookingRequestReceived(accountId),
    );
    for (final record in importRecords) {
      if (!_recordBelongsToAccount(record, accountId)) continue;
      final status = SavedQuotationsModel.normalizeQuoteListStatus(
        record.status?.toString(),
      );
      if (status == 'denied') continue;
      // Draft quotes from SF import (Status NOT IN Accepted, Denied).
      if (!SavedQuotationsModel.isDraftStatus(status)) continue;
      final id = record.id?.toString().trim() ?? '';
      if (id.isEmpty || bookedQuoteIds.contains(id)) continue;
      final quote = _savedQuoteFromShipmentRecord(record);
      if (quote.isTestQuoteData) continue;
      if (quote.isEmptyOpportunityShellQuote) continue;
      if (!quote.shouldShowInQuotationsList) continue;
      quoteById[id] =
          SavedQuotationsModel.merge([quoteById[id], quote]) ?? quote;
      shipmentById[id] = Records.fromJson(
        quoteById[id]!.toShipmentRecordJson(),
      );
    }

    for (final id in reservedIds) {
      if (quoteById.containsKey(id) || bookedQuoteIds.contains(id)) continue;
      final header = await _fetchQuoteHeaderFromSf(id);
      if (header == null || !_quoteBelongsToAccount(header, accountId)) {
        continue;
      }
      final visible =
          SavedQuotationsModel.merge([
            SavedQuotationsModel(
              id: header.id,
              name: header.name,
              status: 'Accepted',
            ),
            header,
          ]) ??
          header;
      quoteById[id] = visible;
      shipmentById[id] = Records.fromJson(visible.toShipmentRecordJson());
    }

    await _enrichInProgressQuotesContainerFields(
      quoteById: quoteById,
      shipmentById: shipmentById,
    );

    final records = booking.Records.sortNewestFirst(
      shipmentById.values
          .map((r) => booking.Records.fromJson(_shipmentRecordToBookingJson(r)))
          .toList(),
    );

    debugPrint(
      '✅ User in-progress (account=$accountId): ${records.length} quote(s) '
      '(merged=${mergedQuotes.length}, import=${importRecords.length}, '
      'bookedExcluded=${bookedQuoteIds.length})',
    );
    return InProgressShipmentData(
      records: records,
      adminQuoteById: quoteById,
      shipmentRecordById: shipmentById,
    );
  }

  bool _quoteBelongsToAccount(SavedQuotationsModel quote, String accountId) {
    final expected = accountId.trim();
    if (expected.isEmpty) return true;
    final onQuote = quote.accountId?.trim();
    if (onQuote == null || onQuote.isEmpty) return true;
    return onQuote == expected;
  }

  /// All quotes for [accountId] from user/quote API + Salesforce AccountId query.
  Future<List<SavedQuotationsModel>> _fetchMergedAccountQuotes(
    String accountId,
  ) async {
    List<SavedQuotationsModel> appQuotes = [];
    try {
      final response = await _baseClient.handleRequest(
        ApiRequest(
          url: ApiConstants.userQuotes(accountId: accountId),
          method: DioMethod.get,
        ),
      );
      appQuotes = _parseSavedQuotesList(response);
    } catch (e) {
      debugPrint('⚠️ user/quote for account $accountId failed: $e');
    }

    final sfQuotes = await _fetchAccountQuotesFromSf(accountId);
    final byId = <String, SavedQuotationsModel>{};

    for (final quote in appQuotes) {
      if (!_quoteBelongsToAccount(quote, accountId)) continue;
      final id = quote.id?.trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = quote;
    }

    for (final sf in sfQuotes) {
      if (!_quoteBelongsToAccount(sf, accountId)) continue;
      final id = sf.id?.trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = SavedQuotationsModel.merge([byId[id], sf]) ?? sf;
    }

    debugPrint(
      '📡 Account $accountId quotes merged: user/quote=${appQuotes.length}, '
      'sf=${sfQuotes.length}, total=${byId.length}',
    );
    return byId.values.toList();
  }

  SavedQuotationsModel _savedQuoteFromShipmentRecord(Records record) {
    return SavedQuotationsModel(
      id: record.id?.toString(),
      name: record.name?.toString(),
      status: record.status?.toString(),
      createdDateC: record.createdDate?.toString(),
      expirationDate: record.expirationDate?.toString(),
      loadType: record.leadTypeC?.toString(),
      containerType: record.containerTypeC?.toString(),
      containerSize: record.containerSizeC?.toString(),
      modeOfShipment: record.modeOfShipmentC?.toString(),
      netWeight:
          record.netWeightKgsC is num
              ? record.netWeightKgsC as num
              : num.tryParse(record.netWeightKgsC?.toString() ?? ''),
      grossWeight:
          record.grossWeightKgsC is num
              ? record.grossWeightKgsC as num
              : num.tryParse(record.grossWeightKgsC?.toString() ?? ''),
      goodsValue:
          record.goodsValueC is num
              ? record.goodsValueC as num
              : num.tryParse(record.goodsValueC?.toString() ?? ''),
      totalPrice:
          record.grandTotal is num
              ? record.grandTotal as num
              : num.tryParse(record.grandTotal?.toString() ?? ''),
      opportunityName: record.opportunity?.name?.toString(),
      accountName: record.account?.name?.toString(),
      accountId: record.accountId?.toString(),
      originPortR:
          record.originPortName != null
              ? PortMaster(name: record.originPortName.toString())
              : null,
      destinationPortR:
          record.destinationPortName != null
              ? PortMaster(name: record.destinationPortName.toString())
              : null,
    );
  }

  bool _isInProgressQuoteStatus(String status) {
    return SavedQuotationsModel.isInProgressListStatus(status);
  }

  /// Status left by Reserve Your Space when Salesforce has not created an order yet.
  bool _isReserveYourSpaceStatus(String? raw) {
    final status = raw?.trim().toLowerCase() ?? '';
    if (status.isEmpty) return false;
    return status.contains('reserv') ||
        status.contains('book') ||
        status.contains('confirm');
  }

  /// Reserved quotes that are not yet orders, for the Shipments → Booked list.
  Future<List<booking.Records>> reservedQuotesNotYetBooked({
    required String accountId,
    required Set<String> reservedIds,
    required Set<String> bookedQuoteIds,
  }) async {
    final pending =
        reservedIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty && !bookedQuoteIds.contains(id))
            .toSet();
    if (accountId.trim().isEmpty) return [];

    final byId = <String, SavedQuotationsModel>{};
    for (final quote in await _fetchMergedAccountQuotes(accountId)) {
      final id = quote.id?.trim() ?? '';
      if (id.isEmpty || bookedQuoteIds.contains(id)) continue;
      if (quote.isTestQuoteData) continue;
      final reserved =
          pending.contains(id) || _isReserveYourSpaceStatus(quote.status);
      final accepted = SavedQuotationsModel.isAcceptedStatus(quote.status);
      if (!reserved && !accepted) continue;
      if (!reserved && quote.isEmptyOpportunityShellQuote) continue;
      byId[id] = quote;
    }
    for (final id in pending) {
      if (byId.containsKey(id)) continue;
      final header = await _fetchQuoteHeaderFromSf(id);
      if (header != null && _quoteBelongsToAccount(header, accountId)) {
        byId[id] = header;
      }
    }

    return [
      for (final quote in byId.values)
        booking.Records.fromJson({
          ...quote.toInProgressBookingJson(),
          'Tracking_Status__c': 'Reserved',
        }),
    ];
  }

  /// Quote ids already converted to booked orders — hide from In Progress.
  Future<Set<String>> _fetchBookedQuoteIds({String? accountId}) async {
    try {
      if (AuthDataHelper.isAdminUser()) {
        final orders = await fetchAdminRmsBookedOrders();
        return orders
            .map((o) => o.quoteId?.toString().trim() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }

      final resolvedAccountId = accountId?.trim() ?? _accountId();
      if (resolvedAccountId.isEmpty) return {};

      final response = await _baseClient.handleRequest(
        ApiRequest(
          url: ApiConstants.userBookingsList(resolvedAccountId),
          method: DioMethod.get,
        ),
      );
      if (response is! Map || response['status'] != 200) return {};
      final bookings = response['bookings'];
      if (bookings is! List) return {};

      final ids = <String>{};
      for (final item in bookings) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final quoteId = map['QuoteId']?.toString().trim() ?? '';
        if (quoteId.isNotEmpty) ids.add(quoteId);
      }
      return ids;
    } catch (e) {
      debugPrint('⚠️ Booked quote ids fetch failed: $e');
      return {};
    }
  }

  String _quoteRecordStatus(Records record) {
    return SavedQuotationsModel.normalizeQuoteListStatus(
      record.status?.toString(),
    );
  }

  bool _recordBelongsToAccount(Records record, String accountId) {
    final recordAccountId = record.accountId?.toString().trim() ?? '';
    if (recordAccountId.isEmpty) return true;
    return recordAccountId == accountId;
  }

  bool _quoteNeedsContainerEnrichment(SavedQuotationsModel quote) {
    bool missing(String? value) => value == null || value.trim().isEmpty;
    return missing(quote.containerType) || missing(quote.containerSize);
  }

  String? _readOptionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  SavedQuotationsModel? _containerFieldsFromLineMap(Map<String, dynamic> map) {
    String? type;
    String? size;

    void readFrom(Map<String, dynamic> source) {
      type ??= _readOptionalString(
        source['Container_Type__c'] ?? source['containerType'],
      );
      size ??= _readOptionalString(
        source['Container_Size__c'] ??
            source['containerSize'] ??
            source['Size__c'],
      );
    }

    readFrom(map);
    for (final key in ['PricebookEntry', 'PricebookEntry__r']) {
      final nested = map[key];
      if (nested is Map) {
        readFrom(Map<String, dynamic>.from(nested));
      }
    }
    for (final key in ['Product2', 'Product2__r']) {
      final nested = map[key];
      if (nested is Map) {
        readFrom(Map<String, dynamic>.from(nested));
      }
    }

    if (type == null && size == null) return null;
    return SavedQuotationsModel(containerType: type, containerSize: size);
  }

  Future<SavedQuotationsModel?> _fetchQuoteContainerFieldsFromSf(
    String quoteId,
  ) async {
    try {
      final response = await _baseClient.handleRequest(
        ApiRequest(
          url: ApiConstants.getQuoteContainerFieldsById(quoteId),
          method: DioMethod.get,
        ),
      );
      return _parseQuoteHeader(response, quoteId: quoteId);
    } catch (e) {
      debugPrint('⚠️ Quote container SF fetch failed for $quoteId: $e');
      return null;
    }
  }

  Future<SavedQuotationsModel?> _fetchContainerFieldsFromPricebookEntry(
    String pricebookEntryId,
  ) async {
    try {
      final response = await _baseClient.handleRequest(
        ApiRequest(
          url: ApiConstants.getPricebookEntryContainerFieldsById(
            pricebookEntryId,
          ),
          method: DioMethod.get,
        ),
      );
      final records = _extractRecordsList(response);
      for (final item in records) {
        if (item is! Map) continue;
        final patch = _containerFieldsFromLineMap(
          Map<String, dynamic>.from(item),
        );
        if (patch != null) return patch;
      }
    } catch (e) {
      debugPrint(
        '⚠️ PricebookEntry container fetch failed for $pricebookEntryId: $e',
      );
    }
    return null;
  }

  Future<SavedQuotationsModel?> _fetchContainerSizeFromQuoteLines(
    List<GetQuoteDetailModel>? lines,
  ) async {
    if (lines == null || lines.isEmpty) return null;

    GetQuoteDetailModel? oceanLine;
    for (final line in lines) {
      final product = line.product?.trim().toUpperCase() ?? '';
      if (product.contains('OCEAN FREIGHT')) {
        oceanLine = line;
        break;
      }
    }
    oceanLine ??= lines.first;

    final pbeId = oceanLine.pricebookEntryId?.trim() ?? '';
    if (pbeId.isEmpty) return null;

    final fromEntry = await _fetchContainerFieldsFromPricebookEntry(pbeId);
    if (fromEntry?.containerSize?.trim().isNotEmpty == true) {
      return SavedQuotationsModel(containerSize: fromEntry!.containerSize);
    }
    return null;
  }

  /// Fills container type/size from quote/line when list APIs omit them.
  Future<void> _enrichInProgressQuotesContainerFields({
    required Map<String, SavedQuotationsModel> quoteById,
    required Map<String, Records> shipmentById,
  }) async {
    final quoteIds =
        quoteById.entries
            .where((entry) => _quoteNeedsContainerEnrichment(entry.value))
            .map((entry) => entry.key)
            .toList();
    if (quoteIds.isEmpty) return;

    debugPrint('📡 Enriching container fields for ${quoteIds.length} quote(s)');

    await Future.wait(
      quoteIds.map((id) async {
        try {
          SavedQuotationsModel? merged = SavedQuotationsModel.merge([
            quoteById[id],
            await _fetchQuoteContainerFieldsFromSf(id),
          ]);

          if (_quoteNeedsContainerEnrichment(merged ?? quoteById[id]!)) {
            final response = await getQuoteDetails(quoteId: id);
            merged = SavedQuotationsModel.merge([merged, response.body?.quote]);

            final missingSize =
                merged?.containerSize == null ||
                merged!.containerSize!.trim().isEmpty;
            if (missingSize) {
              merged = SavedQuotationsModel.merge([
                merged,
                await _fetchContainerSizeFromQuoteLines(
                  response.body?.lineItems,
                ),
              ]);
            }
          }

          if (merged == null) return;
          quoteById[id] = merged;
          shipmentById[id] = Records.fromJson(merged.toShipmentRecordJson());
          debugPrint(
            '📦 Container enriched $id: type=${merged.containerType}, '
            'size=${merged.containerSize}',
          );
        } catch (e) {
          debugPrint('⚠️ Container enrich failed for $id: $e');
        }
      }),
    );
  }

  Future<List<Records>> _fetchUserShipmentRecordsForInProgress(
    String url,
  ) async {
    try {
      final response = await _baseClient.handleRequest(
        ApiRequest(url: url, method: DioMethod.get),
      );
      final dataResponse = DataResponse<GetShipmentModel?>.fromJson(
        response,
        (json) => GetShipmentModel.fromJson(json),
      );
      return (dataResponse.body?.records ?? [])
          .whereType<Records>()
          .where((item) => !_isTestShipmentRecord(item))
          .toList();
    } catch (e) {
      debugPrint('⚠️ In-progress shipment fetch failed ($url): $e');
      return [];
    }
  }

  bool _isTestShipmentRecord(Records item) {
    return SavedQuotationsModel.isTestQuoteLabel(
      item.name?.toString(),
      opportunityName: item.opportunity?.name?.toString(),
    );
  }

  Map<String, dynamic> _shipmentRecordToBookingJson(Records record) {
    final loading =
        record.portOfLoadingC?.toString().trim().isNotEmpty == true
            ? record.portOfLoadingC
            : record.originPortName;
    final destination =
        record.portOfDestinationC?.toString().trim().isNotEmpty == true
            ? record.portOfDestinationC
            : record.destinationPortName;
    final quoteStatus = record.status?.toString().trim();
    final hasQuoteStatus = quoteStatus != null && quoteStatus.isNotEmpty;
    final status =
        hasQuoteStatus
            ? quoteStatus
            : record.customStatusC ?? record.trackingStatusC;

    final rawStatus =
        hasQuoteStatus
            ? quoteStatus
            : (record.trackingStatusC ?? status ?? record.customStatusC)
                ?.toString();
    final normalizedStatus = SavedQuotationsModel.normalizeQuoteListStatus(
      rawStatus,
    );

    return {
      'Id': record.id,
      'Name': record.name ?? record.orderNumber,
      'QuoteId': record.id,
      'OrderNumber': record.orderNumber,
      'Status': rawStatus,
      'Custom_Status__c': record.customStatusC,
      'Tracking_Status__c':
          normalizedStatus.isNotEmpty ? normalizedStatus : rawStatus,
      'CreatedDate': record.createdDate,
      'ExpirationDate': record.expirationDate,
      if (loading != null) 'Origin_Port__r': {'Name': loading},
      if (destination != null) 'Destination_Port__r': {'Name': destination},
      if (record.opportunity?.name != null)
        'Opportunity': {'Name': record.opportunity!.name},
      if (record.account?.name != null)
        'Account': {'Name': record.account!.name},
      if (record.grandTotal != null) 'TotalAmount': record.grandTotal,
      if (record.leadTypeC != null) 'Lead_Type__c': record.leadTypeC,
      if (record.containerTypeC != null)
        'Container_Type__c': record.containerTypeC,
      if (record.containerSizeC != null)
        'Container_Size__c': record.containerSizeC,
      if (record.modeOfShipmentC != null)
        'Mode_of_Shipment__c': record.modeOfShipmentC,
    };
  }

  List<booking.Records> _parseBookingRecordsList(dynamic response) {
    final raw = _extractSavedQuotesRawList(response);
    return raw
        .whereType<Map>()
        .map(
          (item) => booking.Records.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((r) {
          final id = r.id?.toString().trim() ?? '';
          return id.isNotEmpty;
        })
        .toList();
  }

  Future<List<SavedQuotationsModel>> _fetchAllUsersQuotesFromApi() async {
    try {
      final response = await _baseClient.handleRequest(
        ApiRequest(url: ApiConstants.userQuotes(), method: DioMethod.get),
      );
      return _allQuotesForAdminList(_parseSavedQuotesList(response));
    } catch (e) {
      debugPrint('⚠️ Admin user/quote (all users) failed: $e');
      return [];
    }
  }

  Future<List<SavedQuotationsModel>> _fetchAdminRmsQuotesFromSf() async {
    for (final url in [
      ApiConstants.adminRmsOpportunityQuotesSf,
      ApiConstants.adminAllQuotesWithRmsFieldSf,
    ]) {
      try {
        debugPrint('📡 Admin app quotes (SF): $url');
        final response = await _baseClient.handleRequest(
          ApiRequest(url: url, method: DioMethod.get),
        );
        var quotes = _parseSavedQuotesList(response);
        if (url == ApiConstants.adminAllQuotesWithRmsFieldSf) {
          quotes = quotes.where((q) => q.isOpportunityFromRms).toList();
        }
        if (quotes.isNotEmpty) {
          debugPrint('✅ Admin app quotes from SF: ${quotes.length}');
          return quotes.map((q) => q.asAppOpportunityQuote()).toList();
        }
      } catch (e) {
        debugPrint('⚠️ Admin SF quote fetch failed: $e');
      }
    }
    return [];
  }

  /// All quote ids from admin `user/quote` (deduped, newest first).
  List<SavedQuotationsModel> _allQuotesForAdminList(
    List<SavedQuotationsModel> list,
  ) {
    final byId = <String, SavedQuotationsModel>{};
    for (final quote in list) {
      final id = quote.id?.trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = SavedQuotationsModel.merge([byId[id], quote]) ?? quote;
    }
    return SavedQuotationsModel.sortNewestFirst(byId.values.toList());
  }

  List<SavedQuotationsModel> _parseSavedQuotesList(dynamic response) {
    final raw = _extractSavedQuotesRawList(response);
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              SavedQuotationsModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((q) => q.id != null && q.id!.isNotEmpty)
        .toList();
  }

  List<dynamic> _extractSavedQuotesRawList(dynamic response) {
    if (response is List) return response;
    if (response is! Map) return [];

    final map = Map<String, dynamic>.from(response);
    final body = map['body'];
    if (body is List) return body;
    if (body is Map) {
      final fromBody = _extractSavedQuotesRawList(body);
      if (fromBody.isNotEmpty) return fromBody;
    }

    for (final key in ['quotes', 'records', 'data', 'items']) {
      final value = map[key];
      if (value is List) return value;
    }

    return [];
  }

  /// Fetches SF quote metadata used only to enrich [appQuotes] (no extra cards).
  Future<List<SavedQuotationsModel>> _fetchAccountQuotesFromSf(
    String accountId,
  ) async {
    try {
      final url = ApiConstants.getAccountQuotesSf(accountId);
      debugPrint('📡 Account quotes SF (enrich): $url');
      final response = await _baseClient.handleRequest(
        ApiRequest(url: url, method: DioMethod.get),
      );
      return _parseSavedQuotesList(response);
    } catch (e) {
      debugPrint('⚠️ getData account quotes failed: $e');
      return [];
    }
  }

  /// Merges user/quote rows with Salesforce (ports, Accepted status, etc.).
  List<SavedQuotationsModel> _mergeAppAndSfQuotes(
    List<SavedQuotationsModel> appQuotes,
    List<SavedQuotationsModel> sfQuotes,
  ) {
    final byId = <String, SavedQuotationsModel>{};

    for (final quote in appQuotes) {
      final id = quote.id?.trim();
      if (id == null || id.isEmpty) continue;
      byId[id] = quote;
    }

    for (final sf in sfQuotes) {
      final id = sf.id?.trim();
      if (id == null || id.isEmpty) continue;

      if (byId.containsKey(id)) {
        byId[id] = SavedQuotationsModel.merge([byId[id], sf]) ?? sf;
        continue;
      }

      // user/quote API may omit Accepted (and other) quotes still in Salesforce
      if (_shouldIncludeSfOnlyQuote(sf)) {
        byId[id] = sf;
      }
    }

    return byId.values.toList();
  }

  /// SF rows missing from user/quote (e.g. Accepted after booking).
  bool _shouldIncludeSfOnlyQuote(SavedQuotationsModel quote) {
    final status = quote.status?.trim().toLowerCase() ?? '';
    return status == 'accepted' || status == 'presented';
  }

  ///------------- LogOut Api -------------

  Future<DataResponse<bool>> logout() async {
    ProgressLoader.show(Get.context!);

    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.logOut,
      method: DioMethod.post,
    );

    try {
      var response = await _baseClient.handleRequest(apiRequest);
      ProgressLoader.hide(Get.context!);

      DbHelper().clearAll();
      AuthDataHelper.clearAllData();
      NotificationInboxStore.instance.clearSession();
      await FcmTokenService.clearOnLogout();
      await NotificationPollService.clearSeenOnLogout();

      return DataResponse(
        success: true,
        message: response['message'] ?? "Logged out successfully",
      );
    } catch (e) {
      // ProgressLoader.hide(Get.context!);
      return DataResponse(message: e.toString(), success: false);
    }
  }

  ///------------- GET User Bookings -------------
  Future<DataResponse<GetBookingListModel?>> getUserBookings() async {
    final accountId = DbHelper().getUserModel()?.accountId;
    final isAdmin = AuthDataHelper.isAdminUser() == true;

    if (isAdmin) {
      debugPrint('🛑 Admin user detected. Skipping API call.');
      return DataResponse(
        message: "Admin users don't have personal bookings.",
        success:
            true, // Ya false, depend karta hai aap UI pe kya dikhana chahte hain
        body: null,
      );
    }
    if (accountId == null || accountId.isEmpty) {
      debugPrint('❌ No account_id found for user');
      return DataResponse(message: "User account not found", success: false);
    }

    ApiRequest apiRequest = ApiRequest(
      url: "${ApiConstants.userBookings}?account_id=$accountId",
      method: DioMethod.get,
    );

    debugPrint('📡 Fetching bookings from: ${apiRequest.url}');

    try {
      var response = await _baseClient.handleRequest(apiRequest);

      debugPrint('📡 Booking API Response: $response');

      return DataResponse<GetBookingListModel?>.fromJson(
        response,
        (json) => GetBookingListModel.fromJson(json),
      );
    } catch (e) {
      debugPrint('❌ Error fetching bookings in Provider: $e');
      return DataResponse(message: e.toString(), success: false);
    }
  }

  Future<DataResponse<booking.GetBookingListModelNew?>>
  getUserBookingsNew() async {
    final accountId = DbHelper().getUserModel()?.accountId;
    final isAdmin = AuthDataHelper.isAdminUser() == true;

    if (isAdmin) {
      debugPrint('🛑 Admin user detected. Skipping API call.');
      return DataResponse(
        message: "Admin users don't have personal bookings.",
        success: true,
        body: null,
      );
    }

    if (accountId == null || accountId.isEmpty) {
      debugPrint('❌ No account_id found for user');
      return DataResponse(message: "User account not found", success: false);
    }

    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.getDataBookings(accountId),
      method: DioMethod.get,
    );

    debugPrint('📡 Fetching bookings from: ${apiRequest.url}');

    try {
      var response = await _baseClient.handleRequest(apiRequest);

      debugPrint('📡 Booking API Response: $response');

      return DataResponse<booking.GetBookingListModelNew?>.fromJson(
        response,
        (json) => booking.GetBookingListModelNew.fromJson(json),
      );
    } catch (e) {
      debugPrint('❌ Error fetching bookings in Provider: $e');
      return DataResponse(message: e.toString(), success: false);
    }
  }

  Future<DataResponse<booking.GetBookingListModelNew?>>
  getUserBookingsOpenBookings() async {
    final accountId = DbHelper().getUserModel()?.accountId;
    final isAdmin = AuthDataHelper.isAdminUser() == true;

    if (isAdmin) {
      debugPrint('🛑 Admin user detected. Skipping API call.');
      return DataResponse(
        message: "Admin users don't have personal bookings.",
        success: true,
        body: null,
      );
    }

    if (accountId == null || accountId.isEmpty) {
      debugPrint('❌ No account_id found for user');
      return DataResponse(message: "User account not found", success: false);
    }

    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.getOpenBookings(accountId),
      method: DioMethod.get,
    );

    debugPrint('📡 Fetching bookings from: ${apiRequest.url}');

    try {
      var response = await _baseClient.handleRequest(apiRequest);

      debugPrint('📡 Booking API Response: $response');

      return DataResponse<booking.GetBookingListModelNew?>.fromJson(
        response,
        (json) => booking.GetBookingListModelNew.fromJson(json),
      );
    } catch (e) {
      debugPrint('❌ Error fetching bookings in Provider: $e');
      return DataResponse(message: e.toString(), success: false);
    }
  }

  Future<DataResponse<GetShipmentModel?>> getShipmentImportData() async {
    final accountId = DbHelper().getUserModel()?.accountId;
    final isAdmin = AuthDataHelper.isAdminUser() == true;

    if (isAdmin) {
      debugPrint('🛑 Admin user detected. Skipping API call.');
      return DataResponse(
        message: "Admin users don't have personal bookings.",
        success: true,
        body: null,
      );
    }

    if (accountId == null || accountId.isEmpty) {
      debugPrint('❌ No account_id found for user');
      return DataResponse(message: "User account not found", success: false);
    }

    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.getBookingRequestReceived(accountId),
      method: DioMethod.get,
    );

    debugPrint('📡 Fetching bookings from: ${apiRequest.url}');

    try {
      var response = await _baseClient.handleRequest(apiRequest);

      debugPrint('📡 Booking API Response: $response');

      return DataResponse<GetShipmentModel?>.fromJson(
        response,
        (json) => GetShipmentModel.fromJson(json),
      );
    } catch (e) {
      debugPrint('❌ Error fetching bookings in Provider: $e');
      return DataResponse(message: e.toString(), success: false);
    }
  }

  Future<DataResponse<GetShipmentModel?>> getShipmentExportData() async {
    final accountId = DbHelper().getUserModel()?.accountId;
    final isAdmin = AuthDataHelper.isAdminUser() == true;

    if (isAdmin) {
      debugPrint('🛑 Admin user detected. Skipping API call.');
      return DataResponse(
        message: "Admin users don't have personal bookings.",
        success: true,
        body: null,
      );
    }

    if (accountId == null || accountId.isEmpty) {
      debugPrint('❌ No account_id found for user');
      return DataResponse(message: "User account not found", success: false);
    }

    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.getBookingSentToCustomer(accountId),
      method: DioMethod.get,
    );

    debugPrint('📡 Fetching bookings from: ${apiRequest.url}');

    try {
      var response = await _baseClient.handleRequest(apiRequest);

      debugPrint('📡 Booking API Response: $response');

      return DataResponse<GetShipmentModel?>.fromJson(
        response,
        (json) => GetShipmentModel.fromJson(json),
      );
    } catch (e) {
      debugPrint('❌ Error fetching bookings in Provider: $e');
      return DataResponse(message: e.toString(), success: false);
    }
  }

  ///------------- Order booking documents (invoices/PDFs) -------------

  Future<DataResponse<List<OrderDocumentModel>>> fetchOrderDocuments({
    required String orderId,
  }) async {
    final trimmedId = orderId.trim();
    if (trimmedId.isEmpty) {
      return DataResponse(
        message: 'Order id is required',
        success: false,
        body: [],
      );
    }

    // Backend serves this route as POST (GET returns 404).
    final apiRequest = ApiRequest(
      url: ApiConstants.orderDocumentsForOrder(trimmedId),
      method: DioMethod.post,
      bodyType: BodyType.json,
      body: <String, dynamic>{},
    );

    debugPrint('📡 Order invoice documents (POST): ${apiRequest.url}');

    try {
      final response = await _baseClient.handleRequest(apiRequest);
      return _orderDocumentsFromResponse(response, orderId: trimmedId);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final responseData = e.response?.data;

      debugPrint('⚠️ fetchOrderDocuments HTTP $status for order $trimmedId');

      if (responseData != null) {
        final parsed = _orderDocumentsFromResponse(
          responseData,
          orderId: trimmedId,
        );
        if (parsed.body?.isNotEmpty ?? false) {
          return parsed;
        }
        final statusCode = _readResponseStatus(responseData);
        if (statusCode == 200 || statusCode == '200') {
          debugLogOrderDocuments(
            orderId: trimmedId,
            documents: const [],
            source: 'fetchOrderDocuments (empty 200)',
          );
          return DataResponse(
            success: true,
            code: 200,
            message: 'No documents available for this order.',
            body: [],
          );
        }
      }

      if (status == 404) {
        return DataResponse(
          success: true,
          code: 404,
          message: 'No documents available for this order.',
          body: [],
        );
      }

      final message = _dioErrorMessage(e);
      debugPrint('❌ fetchOrderDocuments error: $message');
      return DataResponse(message: message, success: false, body: []);
    } catch (e) {
      debugPrint('❌ fetchOrderDocuments error: $e');
      return DataResponse(message: e.toString(), success: false, body: []);
    }
  }

  /// Booking documents — order invoices only (no quote PDF substitute).
  Future<DataResponse<List<OrderDocumentModel>>> fetchOrderDocumentsForBooking({
    required String orderId,
    String? quoteId,
  }) async {
    return fetchOrderDocuments(orderId: orderId);
  }

  /// Upload BL document — `POST /user/uploadBL/documents?order_id=&file_type=`.
  Future<DataResponse<void>> uploadOrderDocument({
    required String orderId,
    required String filePath,
    required String fileType,
    String? fileName,
  }) async {
    final trimmedId = orderId.trim();
    if (trimmedId.isEmpty) {
      return DataResponse(message: 'Order id is required', success: false);
    }

    final resolvedType = fileType.trim();
    if (resolvedType.isEmpty) {
      return DataResponse(message: 'Document type is required', success: false);
    }

    final resolvedName =
        fileName?.trim().isNotEmpty == true
            ? fileName!.trim()
            : basename(filePath);

    try {
      final multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: resolvedName,
      );

      final apiRequest = ApiRequest(
        url: ApiConstants.uploadBlDocument(
          orderId: trimmedId,
          fileType: resolvedType,
        ),
        method: DioMethod.post,
        bodyType: BodyType.formData,
        body: <String, dynamic>{'file': multipartFile},
      );

      debugPrint('📤 Upload BL document: ${apiRequest.url}');

      final response = await _baseClient.handleRequest(apiRequest);
      final map = _coerceResponseToMap(response);
      final status = _responseStatusCode(map ?? response);
      final ok =
          status == 200 ||
          status == 201 ||
          _readResponseStatus(map ?? response) == true ||
          _readResponseStatus(map ?? response) == '200';

      if (ok) {
        return DataResponse(
          success: true,
          code: status is int ? status : 200,
          message: map?['message']?.toString() ?? 'Document uploaded',
        );
      }

      return DataResponse(
        success: false,
        message: map?['message']?.toString() ?? 'Upload failed',
        code: status is int ? status : null,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverMsg =
          _coerceResponseToMap(e.response?.data)?['message']?.toString();
      return DataResponse(
        success: false,
        message:
            serverMsg?.isNotEmpty == true ? serverMsg : _dioErrorMessage(e),
        code: status,
      );
    } catch (e) {
      debugPrint('❌ uploadOrderDocument error: $e');
      return DataResponse(message: e.toString(), success: false);
    }
  }

  /// Backend file count vs UI — and files not shown in the list.
  static void debugLogOrderDocuments({
    required String orderId,
    required List<OrderDocumentModel> documents,
    String source = 'app',
    OrderDocumentsFetchStats? stats,
  }) {
    final resolvedStats =
        stats ??
        (lastDocumentStats?.orderId == orderId.trim()
            ? lastDocumentStats
            : null);

    debugPrint('══════════ ORDER DOCUMENTS ══════════');
    debugPrint('source: $source');
    debugPrint('order_id: $orderId');

    if (resolvedStats != null) {
      debugPrint(
        '📦 BACKEND file count (API total): ${resolvedStats.backendFileCount}',
      );
      debugPrint(
        '📱 UI file count (shown on screen): ${resolvedStats.uiFileCount}',
      );
      debugPrint('🚫 NOT shown in UI: ${resolvedStats.notShownCount} file(s)');
      if (resolvedStats.skippedDuplicates > 0) {
        debugPrint(
          '   • duplicates merged: ${resolvedStats.skippedDuplicates}',
        );
      }
      if (resolvedStats.skippedQuotePdf > 0) {
        debugPrint('   • quote PDF filtered: ${resolvedStats.skippedQuotePdf}');
      }
      if (resolvedStats.skippedNoDisplayData > 0) {
        debugPrint(
          '   • missing type/name/url: ${resolvedStats.skippedNoDisplayData}',
        );
      }
      if (resolvedStats.skippedInvalidItem > 0) {
        debugPrint(
          '   • invalid API item: ${resolvedStats.skippedInvalidItem}',
        );
      }
      if (resolvedStats.notShownInUi.isNotEmpty) {
        debugPrint('─── backend files NOT in UI ───');
        for (var i = 0; i < resolvedStats.notShownInUi.length; i++) {
          debugPrint('   [$i] ${resolvedStats.notShownInUi[i]}');
        }
      }
    } else {
      debugPrint('📱 UI file count (shown on screen): ${documents.length}');
      debugPrint('(no backend stats — fetch documents API first)');
    }

    if (documents.isNotEmpty) {
      debugPrint('─── files SHOWN in UI ───');
      final typeCounts = <String, int>{};
      for (var i = 0; i < documents.length; i++) {
        final doc = documents[i];
        final type =
            doc.fileType?.trim().isNotEmpty == true
                ? doc.fileType!.trim()
                : '(no file_type)';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        debugPrint(
          '   [$i] file_type="$type" | file_name="${doc.displayFileName}"',
        );
      }
      debugPrint('UI count by file_type: $typeCounts');
    }

    debugPrint('══════════════════════════════════════');
  }

  static String _backendFileLabel(Map<String, dynamic> map) {
    final type = (map['file_type'] ?? map['fileType'] ?? '').toString().trim();
    final name = (map['file_name'] ?? map['fileName'] ?? '').toString().trim();
    if (type.isEmpty && name.isEmpty) return '(unknown file)';
    if (type.isEmpty) return name;
    if (name.isEmpty) return type;
    return '$type | $name';
  }

  DataResponse<List<OrderDocumentModel>> _orderDocumentsFromResponse(
    dynamic response, {
    String? orderId,
  }) {
    final normalized = _coerceResponseToMap(response) ?? response;
    _logOrderDocumentsPayload(normalized);

    final firstParse = _parseOrderInvoiceDocuments(
      normalized,
      orderId: orderId,
    );
    if (firstParse.documents.isNotEmpty) {
      return DataResponse(
        success: true,
        body: firstParse.documents,
        message: normalized is Map ? normalized['message']?.toString() : null,
        code: _responseStatusCode(normalized),
      );
    }

    final payload = _unwrapApiPayload(normalized);
    final secondParse = _parseOrderInvoiceDocuments(payload, orderId: orderId);
    final statusCode = _responseStatusCode(normalized);
    final isOk = statusCode == 200 || _readResponseStatus(normalized) == '200';
    return DataResponse(
      success: isOk || secondParse.documents.isNotEmpty,
      code: statusCode,
      message:
          secondParse.documents.isEmpty
              ? (_orderDocumentsEmptyMessage(normalized) ??
                  (normalized is Map
                      ? normalized['message']?.toString()
                      : null))
              : null,
      body: secondParse.documents,
    );
  }

  ({List<OrderDocumentModel> documents, OrderDocumentsFetchStats? stats})
  _parseOrderInvoiceDocuments(dynamic response, {String? orderId}) {
    final rawList = _extractOrderInvoiceList(response);
    final byKey = <String, OrderDocumentModel>{};
    var skippedDuplicates = 0;
    var skippedQuotePdf = 0;
    var skippedNoDisplayData = 0;
    var skippedInvalidItem = 0;
    final notShownInUi = <String>[];

    for (final item in rawList) {
      if (item is! Map) {
        skippedInvalidItem++;
        notShownInUi.add('invalid item (not a JSON object)');
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final label = _backendFileLabel(map);

      if (_isQuotePdfPayload(map)) {
        skippedQuotePdf++;
        notShownInUi.add('$label → quote PDF (filtered)');
        continue;
      }

      final doc = OrderDocumentModel.fromOrderInvoice(map);
      if (!_orderDocumentHasDisplayData(doc)) {
        skippedNoDisplayData++;
        notShownInUi.add('$label → missing file_type, file_name, and URL');
        continue;
      }

      final key = _documentDedupeKey(doc);
      final existing = byKey[key];
      if (existing != null) {
        skippedDuplicates++;
        if (!existing.hasDownloadUrl && doc.hasDownloadUrl) {
          byKey[key] = doc;
          notShownInUi.add(
            '$label → duplicate (merged; UI keeps one with URL)',
          );
        } else {
          notShownInUi.add(
            '$label → duplicate (same type+name as another row)',
          );
        }
        continue;
      }
      byKey[key] = doc;
    }

    final documents = byKey.values.toList();
    final trimmedOrderId = orderId?.trim() ?? '';
    OrderDocumentsFetchStats? stats;

    if (trimmedOrderId.isNotEmpty) {
      stats = OrderDocumentsFetchStats(
        orderId: trimmedOrderId,
        backendFileCount: rawList.length,
        uiFileCount: documents.length,
        skippedDuplicates: skippedDuplicates,
        skippedQuotePdf: skippedQuotePdf,
        skippedNoDisplayData: skippedNoDisplayData,
        skippedInvalidItem: skippedInvalidItem,
        notShownInUi: notShownInUi,
      );
      lastDocumentStats = stats;
      debugLogOrderDocuments(
        orderId: trimmedOrderId,
        documents: documents,
        source: 'invoices/for/order API',
        stats: stats,
      );
    }

    return (documents: documents, stats: stats);
  }

  String _documentDedupeKey(OrderDocumentModel doc) {
    final type = (doc.fileType ?? '').trim().toLowerCase();
    final name = (doc.fileName ?? '').trim().toLowerCase();
    if (type.isNotEmpty || name.isNotEmpty) return '$type|$name';
    return (doc.downloadUrl ?? '').trim().toLowerCase();
  }

  String? _orderDocumentsEmptyMessage(dynamic response) {
    final map = _coerceResponseToMap(response);
    if (map == null) return null;
    final invoices = map['invoices'];
    if (invoices is Map) {
      final msg = invoices['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty && msg.toLowerCase() != 'success') {
        return msg;
      }
    }
    return null;
  }

  int? _responseStatusCode(dynamic response) {
    final status = _readResponseStatus(response);
    if (status is int) return status;
    if (status is String) return int.tryParse(status);
    return null;
  }

  Map<String, dynamic>? _coerceResponseToMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is String) {
      final trimmed = response.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  bool _orderDocumentHasDisplayData(OrderDocumentModel doc) =>
      doc.hasDownloadUrl ||
      (doc.fileType?.trim().isNotEmpty ?? false) ||
      (doc.fileName?.trim().isNotEmpty ?? false);

  bool _isQuotePdfPayload(Map<String, dynamic> map) {
    if (map['pdfUrl'] != null || map['pdf_url'] != null) return true;
    if (map['quoteName'] != null || map['quoteId'] != null) return true;
    final type = map['file_type']?.toString().toLowerCase() ?? '';
    if (type == 'quote' || type == 'quotation') return true;
    return false;
  }

  List<dynamic> _mergeOrderInvoiceItems(
    List<dynamic> into,
    List<dynamic> from,
  ) {
    if (from.isEmpty) return into;
    return [...into, ...from];
  }

  List<dynamic> _extractOrderInvoiceList(dynamic response) {
    final map = _coerceResponseToMap(response);
    if (map == null) {
      if (response is List) return response;
      return [];
    }

    for (final key in ['invoices', 'invoice']) {
      final value = map[key];
      if (value is List) return value;
      if (value is Map) {
        final invoiceMap = Map<String, dynamic>.from(value);
        var merged = <dynamic>[];

        final fromData = invoiceMap['data'];
        if (fromData is List) {
          merged = _mergeOrderInvoiceItems(merged, fromData);
        }

        merged = _mergeOrderInvoiceItems(
          merged,
          _invoiceItemsFromOrderFiles(invoiceMap['orderFiles']),
        );

        if (merged.isNotEmpty) return merged;

        final nested =
            invoiceMap['records'] ??
            invoiceMap['items'] ??
            invoiceMap['invoices'] ??
            invoiceMap['files'];
        if (nested is List && nested.isNotEmpty) return nested;

        if (_looksLikeOrderInvoiceItem(invoiceMap)) {
          return [invoiceMap];
        }
      }
    }

    var merged = <dynamic>[];
    final data = map['data'];
    if (data is List) merged = _mergeOrderInvoiceItems(merged, data);
    merged = _mergeOrderInvoiceItems(
      merged,
      _invoiceItemsFromOrderFiles(map['orderFiles']),
    );
    if (merged.isNotEmpty) return merged;

    final body = map['body'];
    if (body != null) {
      final fromBody = _extractOrderInvoiceList(body);
      if (fromBody.isNotEmpty) return fromBody;
    }

    final result = map['result'];
    if (result != null) {
      final fromResult = _extractOrderInvoiceList(result);
      if (fromResult.isNotEmpty) return fromResult;
    }

    if (_looksLikeOrderInvoiceItem(map)) return [map];

    return [];
  }

  List<dynamic> _invoiceItemsFromOrderFiles(dynamic orderFiles) {
    if (orderFiles is! Map) return [];
    final items = <dynamic>[];
    for (final entry in orderFiles.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value;
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        if (!map.containsKey('file_type') && !map.containsKey('fileType')) {
          map['file_type'] = key;
        }
        items.add(map);
      } else if (value is List) {
        for (final item in value.whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          if (!map.containsKey('file_type') && !map.containsKey('fileType')) {
            map['file_type'] = key;
          }
          items.add(map);
        }
      }
    }
    return items;
  }

  bool _looksLikeOrderInvoiceItem(Map<String, dynamic> map) {
    if (map['pdfUrl'] != null || map['pdf_url'] != null) return false;
    final hasType = map['file_type'] != null || map['fileType'] != null;
    final hasName = map['file_name'] != null || map['fileName'] != null;
    final hasUrl =
        map['public_url'] != null ||
        map['publicUrl'] != null ||
        map['internal_url'] != null ||
        map['internalUrl'] != null;
    return hasUrl && (hasType || hasName);
  }

  String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Failed to fetch order documents';
  }

  void _logOrderDocumentsPayload(dynamic response) {
    if (response is! Map) {
      debugPrint('[invoices/for/order] response type: ${response.runtimeType}');
      return;
    }
    final map = Map<String, dynamic>.from(response);
    debugPrint('[invoices/for/order] keys: ${map.keys.toList()}');
    final invoices = map['invoices'];
    if (invoices is Map) {
      final inv = Map<String, dynamic>.from(invoices);
      final dataLen = inv['data'] is List ? (inv['data'] as List).length : 0;
      final orderFilesLen =
          inv['orderFiles'] is Map ? (inv['orderFiles'] as Map).length : 0;
      debugPrint(
        '[invoices/for/order] invoices keys: ${inv.keys.toList()}, '
        'data.length: $dataLen, orderFiles.keys: $orderFilesLen '
        '(merged in app — duplicates with same type+name are collapsed)',
      );
      final data = inv['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        debugPrint(
          '[invoices/for/order] data[0] keys: '
          '${Map<String, dynamic>.from(data.first as Map).keys.toList()}',
        );
      }
    }
  }

  List<OrderDocumentModel> _parseOrderDocuments(dynamic response) {
    final rawList = _extractOrderDocumentList(response);
    return rawList
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          if (_looksLikeQuotePdfItem(map)) {
            return OrderDocumentModel.fromQuotePdfItem(map);
          }
          return OrderDocumentModel.fromJson(map);
        })
        .where(
          (doc) =>
              doc.fileType != null ||
              doc.fileName != null ||
              doc.hasDownloadUrl,
        )
        .toList();
  }

  bool _looksLikeOrderDocumentMap(Map<String, dynamic> map) {
    return map['file_type'] != null ||
        map['fileType'] != null ||
        map['file_name'] != null ||
        map['fileName'] != null ||
        map['pdfUrl'] != null ||
        map['pdf_url'] != null ||
        map['public_url'] != null ||
        map['publicUrl'] != null ||
        map['internal_url'] != null ||
        map['internalUrl'] != null ||
        map['downloadUrl'] != null ||
        map['download_url'] != null ||
        map['url'] != null;
  }

  bool _looksLikeQuotePdfItem(Map<String, dynamic> map) {
    return map['pdfUrl'] != null || map['pdf_url'] != null;
  }

  List<dynamic> _extractOrderDocumentList(dynamic response) {
    if (response is List) return response;

    if (response is! Map) return [];

    final map = Map<String, dynamic>.from(response);

    if (_looksLikeOrderDocumentMap(map)) return [map];

    final body = map['body'];
    if (body is List) return body;
    if (body is Map) {
      final fromBody = _extractOrderDocumentList(body);
      if (fromBody.isNotEmpty) return fromBody;
    }

    final invoices = map['invoices'] ?? map['invoice'];
    if (invoices is Map) {
      final data = invoices['data'] ?? invoices['records'] ?? invoices['items'];
      if (data is List) return data;
      if (_looksLikeOrderDocumentMap(Map<String, dynamic>.from(invoices))) {
        return [invoices];
      }
    }
    if (invoices is List) return invoices;

    for (final key in [
      'pdf',
      'documents',
      'invoiceList',
      'invoice_list',
      'pdfs',
      'pdfList',
      'quotePdf',
      'records',
      'data',
      'items',
      'files',
    ]) {
      final value = map[key];
      if (value is List) return value;
      if (value is Map) {
        if (_looksLikeOrderDocumentMap(Map<String, dynamic>.from(value)) ||
            _looksLikeQuotePdfItem(Map<String, dynamic>.from(value))) {
          return [value];
        }
        final nested = value['data'] ?? value['records'] ?? value['items'];
        if (nested is List) return nested;
      }
    }

    return [];
  }

  ///------------- Quote PDF documents (pdfForQuote) -------------

  Future<DataResponse<List<OrderDocumentModel>>> fetchQuotePdfs({
    required String quoteId,
  }) async {
    final trimmedId = quoteId.trim();
    if (trimmedId.isEmpty) {
      return DataResponse(
        message: 'Quote id is required',
        success: false,
        body: [],
      );
    }

    final apiRequest = ApiRequest(
      url: ApiConstants.pdfForQuote(trimmedId),
      method: DioMethod.get,
    );

    debugPrint('📡 Quote PDFs: ${apiRequest.url}');

    try {
      final response = await _baseClient.handleRequest(apiRequest);
      return _quotePdfsFromResponse(quoteId: trimmedId, response: response);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final responseData = e.response?.data;

      debugPrint('⚠️ fetchQuotePdfs HTTP $status for quote $trimmedId');

      if (responseData != null) {
        final parsed = _quotePdfsFromResponse(
          quoteId: trimmedId,
          response: responseData,
        );
        if (parsed.body?.isNotEmpty ?? false) {
          return parsed;
        }
      }

      if (status == 404) {
        return DataResponse(
          success: true,
          code: 404,
          message: 'No PDF documents available for this quote.',
          body: [],
        );
      }

      final message = _dioErrorMessage(e);
      debugPrint('❌ fetchQuotePdfs error: $message');
      return DataResponse(message: message, success: false, body: []);
    } catch (e) {
      debugPrint('❌ fetchQuotePdfs error: $e');
      return DataResponse(message: e.toString(), success: false, body: []);
    }
  }

  DataResponse<List<OrderDocumentModel>> _quotePdfsFromResponse({
    required String quoteId,
    required dynamic response,
  }) {
    _logPdfForQuoteResponse(quoteId: quoteId, response: response);

    final documents = _parseQuotePdfDocuments(response);
    _logParsedQuotePdfs(documents);

    final hasData = documents.isNotEmpty;

    // Check if the API returned pdf items but none had a URL (pdfSaved: false).
    final hasPdfItemsWithNoUrl = _responseHasPdfItemsWithNoUrl(response);
    final message =
        hasPdfItemsWithNoUrl && !hasData
            ? 'PDF not yet generated for this quote. Please try again later or contact support.'
            : (response is Map ? response['message']?.toString() : null);

    return DataResponse(
      success: hasData ? true : _readResponseStatus(response),
      code:
          _readResponseStatus(response) is int
              ? _readResponseStatus(response) as int
              : null,
      message: message,
      body: documents,
    );
  }

  /// Returns true when `pdfForQuote` responds with pdf items that all have
  /// `pdfUrl: null` — meaning the quote exists but the PDF hasn't been
  /// generated on Salesforce yet.
  bool _responseHasPdfItemsWithNoUrl(dynamic response) {
    if (response is! Map) return false;
    final pdfList = response['pdf'];
    if (pdfList is! List || pdfList.isEmpty) return false;
    return pdfList.whereType<Map>().every((item) {
      final url = item['pdfUrl'] ?? item['pdf_url'];
      return url == null || url.toString().trim().isEmpty;
    });
  }

  List<OrderDocumentModel> _parseQuotePdfDocuments(dynamic response) {
    if (response is String) {
      final url = response.trim();
      if (url.startsWith('http')) {
        return [OrderDocumentModel.fromDownloadUrl(url)];
      }
      return [];
    }

    if (response is! Map) return [];

    final map = Map<String, dynamic>.from(response);

    // pdfForQuote: `{ status: 200, pdf: [{ pdfUrl, quoteName, ... }] }`
    final pdfList = map['pdf'];
    if (pdfList is List) {
      // First try: items that have a valid download URL.
      final docsWithUrl =
          pdfList
              .whereType<Map>()
              .map(
                (item) => OrderDocumentModel.fromQuotePdfItem(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((doc) => doc.hasDownloadUrl)
              .toList();
      if (docsWithUrl.isNotEmpty) return docsWithUrl;

      // Fallback: include items without a URL so the row still appears
      // (download button will be disabled with a "not generated" label).
      final docsForDisplay =
          pdfList
              .whereType<Map>()
              .map(
                (item) => OrderDocumentModel.fromQuotePdfItem(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((doc) => doc.fileName != null || doc.fileType != null)
              .toList();
      if (docsForDisplay.isNotEmpty) return docsForDisplay;
    }

    final payload = _unwrapApiPayload(response);
    final fromPayload =
        _parseOrderDocuments(
          payload,
        ).where((doc) => doc.hasDownloadUrl).toList();
    if (fromPayload.isNotEmpty) return fromPayload;

    return _parseOrderDocuments(
      response,
    ).where((doc) => doc.hasDownloadUrl).toList();
  }

  ///------------- GET Booking Details (Items) -------------

  Future<DataResponse<List<BookingItem>>> getBookingItems({
    required String orderId,
  }) async {
    ApiRequest apiRequest = ApiRequest(
      url: "${ApiConstants.userBookingDetail}$orderId",
      method: DioMethod.get,
    );

    try {
      var response = await _baseClient.handleRequest(apiRequest);

      return DataResponse<List<BookingItem>>.fromJson(response, (json) {
        List list = json['items'] ?? [];
        return list.map((item) => BookingItem.fromJson(item)).toList();
      });
    } catch (e) {
      return DataResponse(message: e.toString(), success: false, body: []);
    }
  }

  /// Fetches quote header (ports, load type, weights) — NOT from quote/line API.
  Future<DataResponse<SavedQuotationsModel?>> fetchQuoteHeader({
    required String quoteId,
  }) async {
    final accountId = _accountId();
    SavedQuotationsModel? header;
    dynamic lastStatus;
    String? lastMessage;

    try {
      final isAdmin = AuthDataHelper.isAdminUser();
      final canListQuotes = isAdmin || accountId.isNotEmpty;
      if (canListQuotes) {
        final listUrl = ApiConstants.userQuotes(
          accountId: isAdmin ? null : accountId,
        );
        debugPrint('📡 Quote header: $listUrl');
        final listResponse = await _baseClient.handleRequest(
          ApiRequest(url: listUrl, method: DioMethod.get),
        );
        _logQuoteApiPayload('user/quote', listResponse);
        lastStatus = listResponse['status'];
        lastMessage = listResponse['message']?.toString();
        header = _parseQuoteHeader(listResponse, quoteId: quoteId);
        if (header != null) {
          debugPrint('✅ Header from user/quote list (admin=${isAdmin})');
        }
      }

      // Admin / incomplete header: enrich from quote line + Salesforce getData.
      if (!_quoteHeaderHasCoreFields(header)) {
        try {
          final lineResponse = await getQuoteDetails(quoteId: quoteId);
          final lineQuote = lineResponse.body?.quote;
          header = SavedQuotationsModel.merge([header, lineQuote]);
          if (lineQuote != null) {
            debugPrint('✅ Header enriched from quote/line');
          }
        } catch (e) {
          debugPrint('⚠️ quote/line enrich failed: $e');
        }
      }

      if (!_quoteHeaderHasCoreFields(header)) {
        header = SavedQuotationsModel.merge([
          header,
          await _fetchQuoteHeaderFromSf(quoteId),
        ]);
        if (_quoteHeaderHasCoreFields(header)) {
          debugPrint('✅ Header enriched from getData Quote');
        }
      }

      if (_quoteHeaderHasCoreFields(header)) {
        return DataResponse(
          success: lastStatus ?? 200,
          code: lastStatus is int ? lastStatus : 200,
          message: lastMessage,
          body: header,
        );
      }

      if (accountId.isNotEmpty) {
        final bookingUrl = ApiConstants.detailedBooking(accountId, quoteId);
        debugPrint('📡 Quote header: $bookingUrl');
        final bookingResponse = await _baseClient.handleRequest(
          ApiRequest(url: bookingUrl, method: DioMethod.get),
        );
        _logQuoteApiPayload('detailed/booking', bookingResponse);
        lastStatus = bookingResponse['status'];
        lastMessage = bookingResponse['message']?.toString();
        final fromBooking = _parseQuoteFromDetailedBooking(
          bookingResponse,
          quoteId,
        );
        header = SavedQuotationsModel.merge([header, fromBooking]);
        if (header?.hasDisplayData == true &&
            (fromBooking?.originPortR != null ||
                fromBooking?.destinationPortR != null)) {
          debugPrint('✅ Header from detailed/booking');
        }
      }

      header = SavedQuotationsModel.merge([
        header,
        await _fetchQuoteHeaderFromSf(quoteId),
      ]);
      if (header?.loadType != null || header?.originPortR != null) {
        debugPrint('✅ Header from getData Quote');
      }

      return DataResponse(
        success: lastStatus,
        code: lastStatus,
        message: lastMessage,
        body: header,
      );
    } catch (e) {
      debugPrint('❌ fetchQuoteHeader error: $e');
      return DataResponse(message: e.toString(), success: false, body: header);
    }
  }

  @Deprecated('Use fetchQuoteHeader')
  Future<DataResponse<SavedQuotationsModel?>> getQuoteById({
    required String quoteId,
  }) => fetchQuoteHeader(quoteId: quoteId);

  Future<SavedQuotationsModel?> _fetchQuoteHeaderFromSf(String quoteId) async {
    SavedQuotationsModel? merged;

    for (final url in [
      ApiConstants.getQuoteHeaderByIdMinimal(quoteId),
      ApiConstants.getQuoteHeaderFieldsById(quoteId),
      ApiConstants.getQuoteHeaderById(quoteId),
    ]) {
      debugPrint('📡 Quote header (getData): $url');
      try {
        final response = await _baseClient.handleRequest(
          ApiRequest(url: url, method: DioMethod.get),
        );
        _logQuoteApiPayload('getData Quote', response);
        final parsed = _parseQuoteHeader(response, quoteId: quoteId);
        merged = SavedQuotationsModel.merge([merged, parsed]);
        debugPrint(
          '   ↳ merged: loadType=${merged?.loadType}, '
          'net=${merged?.netWeight}, gross=${merged?.grossWeight}, '
          'goods=${merged?.goodsValue}',
        );
        if (_quoteHeaderHasCoreFields(merged)) {
          debugPrint('✅ getData — full header (weights + ports)');
          return merged;
        }
      } catch (e) {
        debugPrint('⚠️ getData attempt failed: $e');
      }
    }

    return merged;
  }

  SavedQuotationsModel? _parseQuoteFromDetailedBooking(
    dynamic json,
    String quoteId,
  ) {
    if (json is! Map) return null;
    final bookings = json['bookings'];
    if (bookings is! List || bookings.isEmpty) return null;

    Map<String, dynamic>? match;
    for (final item in bookings) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map['QuoteId']?.toString() == quoteId) {
        match = map;
        break;
      }
    }
    match ??= Map<String, dynamic>.from(bookings.first as Map);

    if (match['Quote__r'] is Map) {
      return SavedQuotationsModel.fromJson(
        Map<String, dynamic>.from(match['Quote__r'] as Map),
      );
    }
    if (match['Quote'] is Map) {
      return SavedQuotationsModel.fromJson(
        Map<String, dynamic>.from(match['Quote'] as Map),
      );
    }

    return SavedQuotationsModel.fromBookingMap(match, quoteId: quoteId);
  }

  void _logQuoteApiPayload(String label, dynamic json) {
    if (json is! Map) {
      debugPrint('[$label] response is not a Map');
      return;
    }
    debugPrint('[$label] top-level keys: ${json.keys.toList()}');
    for (final key in ['quote', 'quotes', 'records', 'body', 'data']) {
      final value = json[key];
      if (value is List && value.isNotEmpty && value.first is Map) {
        final first = Map<String, dynamic>.from(value.first as Map);
        debugPrint('[$label] $key[0] keys: ${first.keys.toList()}');
      } else if (value is Map) {
        debugPrint(
          '[$label] $key keys: ${Map<String, dynamic>.from(value).keys.toList()}',
        );
      }
    }
  }

  void _logPdfForQuoteResponse({
    required String quoteId,
    required dynamic response,
  }) {
    debugPrint('══════════ pdfForQuote API ══════════');
    debugPrint('[pdfForQuote] quote_id: $quoteId');

    if (response == null) {
      debugPrint('[pdfForQuote] response: null');
      return;
    }

    if (response is! Map) {
      debugPrint('[pdfForQuote] response type: ${response.runtimeType}');
      debugPrint('[pdfForQuote] response: $response');
      return;
    }

    final map = Map<String, dynamic>.from(response);
    debugPrint('[pdfForQuote] status: ${map['status']}');
    debugPrint('[pdfForQuote] message: ${map['message']}');
    debugPrint('[pdfForQuote] top-level keys: ${map.keys.toList()}');

    for (final key in [
      'body',
      'data',
      'pdfs',
      'pdf',
      'documents',
      'records',
      'invoices',
      'files',
      'items',
    ]) {
      final value = map[key];
      if (value == null) continue;

      if (value is List) {
        debugPrint('[pdfForQuote] $key: List (${value.length} items)');
        for (var i = 0; i < value.length && i < 5; i++) {
          debugPrint('[pdfForQuote] $key[$i]: ${value[i]}');
        }
        if (value.length > 5) {
          debugPrint('[pdfForQuote] ... and ${value.length - 5} more');
        }
      } else if (value is Map) {
        debugPrint('[pdfForQuote] $key keys: ${value.keys.toList()}');
        final nested = value['data'] ?? value['records'] ?? value['items'];
        if (nested is List) {
          debugPrint('[pdfForQuote] $key.data: List (${nested.length} items)');
          for (var i = 0; i < nested.length && i < 5; i++) {
            debugPrint('[pdfForQuote] $key.data[$i]: ${nested[i]}');
          }
        } else {
          debugPrint('[pdfForQuote] $key: $value');
        }
      } else {
        debugPrint('[pdfForQuote] $key: $value');
      }
    }

    final rawList = _extractOrderDocumentList(response);
    debugPrint('[pdfForQuote] extracted raw list count: ${rawList.length}');
    for (var i = 0; i < rawList.length && i < 5; i++) {
      debugPrint('[pdfForQuote] raw[$i]: ${rawList[i]}');
    }
    debugPrint('════════════════════════════════════');
  }

  void _logParsedQuotePdfs(List<OrderDocumentModel> documents) {
    debugPrint('[pdfForQuote] parsed documents: ${documents.length}');
    for (var i = 0; i < documents.length; i++) {
      final doc = documents[i];
      debugPrint(
        '[pdfForQuote] [$i] '
        'fileType=${doc.fileType}, '
        'fileName=${doc.fileName}, '
        'publicUrl=${doc.publicUrl}, '
        'internalUrl=${doc.internalUrl}, '
        'downloadUrl=${doc.downloadUrl}',
      );
    }
  }

  ///------------------ Get Quote Line Items + header (quote details) -----------------
  Future<DataResponse<QuoteLineDetailsResult>> getQuoteDetails({
    required String quoteId,
  }) async {
    ApiRequest apiRequest = ApiRequest(
      url: '${ApiConstants.quoteDetails}$quoteId',
      method: DioMethod.get,
    );

    debugPrint('📡 Quote line API: ${apiRequest.url}');

    try {
      final response = await _baseClient.handleRequest(apiRequest);
      _logQuoteApiPayload('quote/line', response);

      final payload = _unwrapApiPayload(response);
      final result = _parseQuoteLineDetailsPayload(payload, quoteId: quoteId);
      final hasData =
          result.quote?.hasDisplayData == true || result.lineItems.isNotEmpty;

      return DataResponse(
        success: hasData ? true : _readResponseStatus(response),
        code:
            _readResponseStatus(response) is int
                ? _readResponseStatus(response) as int
                : null,
        message: response is Map ? response['message']?.toString() : null,
        body: result,
      );
    } catch (e) {
      debugPrint('❌ Quote line API error: $e');
      return DataResponse(
        message: e.toString(),
        success: false,
        body: QuoteLineDetailsResult(),
      );
    }
  }

  dynamic _unwrapApiPayload(dynamic response) {
    if (response is! Map) return response;
    final map = Map<String, dynamic>.from(response);
    final body = map['body'];
    if (body is Map) return body;
    if (body is List) return map;
    return map;
  }

  dynamic _readResponseStatus(dynamic response) {
    if (response is! Map) return null;
    return response['status'] ?? response['success'];
  }

  QuoteLineDetailsResult _parseQuoteLineDetailsPayload(
    dynamic json, {
    required String quoteId,
  }) {
    final rawRecords = _extractRecordsList(json);
    final quoteRecords = <Map<String, dynamic>>[];
    final lineRecords = <dynamic>[];

    for (final item in rawRecords) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (_isQuoteHeaderRecord(map)) {
        quoteRecords.add(map);
      } else if (_looksLikeQuoteLineItem(map)) {
        lineRecords.add(map);
      }
    }

    final rawLines =
        lineRecords.isNotEmpty ? lineRecords : _extractQuoteLineList(json);
    SavedQuotationsModel? mergedHeader;
    for (final qMap in quoteRecords) {
      mergedHeader = SavedQuotationsModel.merge([
        mergedHeader,
        SavedQuotationsModel.fromJson(qMap),
      ]);
    }

    final extractedList =
        json is Map ? _extractSavedQuotesRawList(json) : <dynamic>[];
    final headerFromList = _findQuoteInList(extractedList, quoteId);

    mergedHeader = SavedQuotationsModel.merge([
      mergedHeader,
      headerFromList,
      _parseQuoteHeader(json, quoteId: quoteId),
      _mergeQuoteHeadersFromLineRecords(rawRecords),
      _mergeQuoteHeadersFromLineRecords(rawLines),
    ]);

    return QuoteLineDetailsResult(
      quote: mergedHeader,
      lineItems: _parseQuoteLineItemsFromRaw(rawLines),
    );
  }

  /// Pull Quote header fields from line records (Quote__r / Quote rows).
  SavedQuotationsModel? _mergeQuoteHeadersFromLineRecords(List<dynamic> items) {
    SavedQuotationsModel? merged;
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (_isQuoteHeaderRecord(map)) {
        merged = SavedQuotationsModel.merge([
          merged,
          SavedQuotationsModel.fromJson(map),
        ]);
      }
      merged = SavedQuotationsModel.merge([merged, _extractNestedQuote(map)]);
      merged = SavedQuotationsModel.merge([
        merged,
        _containerFieldsFromLineMap(map),
      ]);
      if (map['QuoteId']?.toString().isNotEmpty == true &&
          (map['Net_Weight_KGS__c'] != null ||
              map['Gross_Weight_KGS__c'] != null ||
              map['Load_Type__c'] != null)) {
        merged = SavedQuotationsModel.merge([
          merged,
          SavedQuotationsModel.fromBookingMap(
            map,
            quoteId: map['QuoteId']?.toString(),
          ),
        ]);
      }
    }
    return merged;
  }

  List<dynamic> _extractRecordsList(dynamic json) {
    if (json is! Map) return [];
    final records = json['records'];
    if (records is List) return records;
    final nested = json['body'];
    if (nested is Map) {
      final inner = nested['records'];
      if (inner is List) return inner;
    }
    return [];
  }

  bool _isQuoteHeaderRecord(Map<String, dynamic> map) {
    final type = map['attributes'];
    if (type is Map) {
      final sfType = type['type']?.toString();
      if (sfType == 'Quote') return true;
      if (sfType == 'QuoteLineItem') return false;
    }
    if (_looksLikeQuoteLineItem(map)) return false;
    return map['GrandTotal'] != null ||
        map['QuoteNumber'] != null ||
        map['Lead_Type__c'] != null ||
        map['Load_Type__c'] != null;
  }

  SavedQuotationsModel? _parseQuoteHeader(
    dynamic json, {
    required String quoteId,
  }) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);

    for (final key in ['quote', 'quoteDetail', 'quoteData', 'quoteInfo']) {
      final value = map[key];
      if (value is Map) {
        return SavedQuotationsModel.fromJson(Map<String, dynamic>.from(value));
      }
    }

    final fromRecords = _findQuoteInList(map['records'], quoteId);
    if (fromRecords != null) return fromRecords;

    final fromQuotes = _findQuoteInList(map['quotes'], quoteId);
    if (fromQuotes != null) return fromQuotes;

    final fromItems = _findQuoteInList(map['items'], quoteId);
    if (fromItems != null) return fromItems;

    final fromExtracted = _findQuoteInList(
      _extractSavedQuotesRawList(map),
      quoteId,
    );
    if (fromExtracted != null) return fromExtracted;

    final body = map['body'];
    if (body is Map) {
      final fromBody = _parseQuoteHeader(body, quoteId: quoteId);
      if (fromBody != null) return fromBody;
    }

    if (map['Id']?.toString() == quoteId || map['id']?.toString() == quoteId) {
      return SavedQuotationsModel.fromJson(map);
    }

    return null;
  }

  bool _quoteHeaderHasCoreFields(SavedQuotationsModel? quote) {
    if (quote == null) return false;
    return quote.hasResolvedPorts &&
        (quote.loadType?.trim().isNotEmpty ?? false) &&
        (quote.netWeight != null || quote.grossWeight != null);
  }

  SavedQuotationsModel? _findQuoteInList(dynamic list, String quoteId) {
    if (list is! List) return null;

    SavedQuotationsModel? headerMatch;
    SavedQuotationsModel? lineWithQuote;

    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['Id']?.toString() ?? map['id']?.toString();

      if (id == quoteId) {
        if (_looksLikeQuoteLineItem(map)) {
          final nested = _extractNestedQuote(map);
          if (nested != null) lineWithQuote = nested;
        } else {
          headerMatch = SavedQuotationsModel.fromJson(map);
        }
      }

      if (map['QuoteId']?.toString() == quoteId) {
        final nested = _extractNestedQuote(map);
        if (nested != null) lineWithQuote = nested;
      }
    }

    return headerMatch ?? lineWithQuote;
  }

  SavedQuotationsModel? _extractNestedQuote(Map<String, dynamic> map) {
    for (final key in ['Quote__r', 'quote__r', 'Quote', 'quote']) {
      final value = map[key];
      if (value is Map) {
        return SavedQuotationsModel.fromJson(Map<String, dynamic>.from(value));
      }
    }
    return null;
  }

  SavedQuotationsModel? _parseQuoteHeaderFromRawLines(List<dynamic> rawLines) {
    for (final item in rawLines) {
      if (item is! Map) continue;
      final nested = _extractNestedQuote(Map<String, dynamic>.from(item));
      if (nested != null) return nested;
    }
    return null;
  }

  bool _looksLikeQuoteLineItem(Map<String, dynamic> map) {
    return map['QuoteId'] != null ||
        map['PricebookEntryId'] != null ||
        map['Product2Id'] != null ||
        map['Charge_Type__c'] != null ||
        map['Product__c'] != null;
  }

  List<GetQuoteDetailModel> _parseQuoteLineItems(dynamic json) {
    return _parseQuoteLineItemsFromRaw(_extractQuoteLineList(json));
  }

  List<GetQuoteDetailModel> _parseQuoteLineItemsFromRaw(List<dynamic> rawList) {
    return rawList
        .whereType<Map>()
        .map(
          (item) =>
              GetQuoteDetailModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  List<dynamic> _extractQuoteLineList(dynamic json) {
    if (json is List) {
      return json.where(_isLineItemMap).toList();
    }
    if (json is! Map) return [];

    const keys = [
      'quoteLineItems',
      'lineItems',
      'quotes',
      'records',
      'items',
      'data',
    ];

    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        final lines = value.where(_isLineItemMap).toList();
        if (lines.isNotEmpty) return lines;
        if (key == 'records' || key == 'quotes') continue;
        if (key != 'quotes') return lines;
      }
      if (value is Map) {
        final nested = value['records'] ?? value['quotes'] ?? value['items'];
        if (nested is List) {
          final lines = nested.where(_isLineItemMap).toList();
          return lines.isNotEmpty ? lines : nested;
        }
      }
    }

    return [];
  }

  bool _isLineItemMap(dynamic item) {
    if (item is! Map) return false;
    final map = Map<String, dynamic>.from(item);
    return _looksLikeQuoteLineItem(map);
  }
}
