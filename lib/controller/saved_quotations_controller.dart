import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:mprs_android/core/auth_data_helper.dart';

import '../core/constants/api_provider.dart';
import '../core/constants/data_response.dart';
import '../core/constants/db_helper.dart';
import '../model/get_quote_detail_model.dart';
import '../model/order_document_model.dart';
import '../model/quote_line_details_result.dart';
import '../model/saved_quotations_model.dart';

class SavedQuotationsController extends GetxController {
  /// List screen / dashboard grid only.
  bool isLoading = true;

  /// Quote card detail screen only (must not touch [isLoading]).
  bool isDetailLoading = false;
  bool isPdfLoading = false;
  List<SavedQuotationsModel> quotesList = [];
  List<GetQuoteDetailModel> bookingDetailItems = [];
  SavedQuotationsModel? activeQuoteDetail;
  List<OrderDocumentModel> quotePdfList = [];
  String quotePdfError = '';
  String errorMessage = '';

  /// True when the last quotations fetch failed (home can fall back to sample stats).
  bool quotesLoadFailed = false;

  /// Tracks the account ID used for the last successful fetch.
  /// If the logged-in user changes, we detect it here and force a refresh
  /// so the new user never sees another user's quotations.
  String _lastLoadedAccountId = '';

  /// Reads accountId from DbHelper first; falls back to AuthDataHelper so a
  /// stale DbHelper (e.g. after a profile refresh that didn't return accountId)
  /// never causes an empty account ID and lost quotations.
  String get _currentAccountId {
    final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
    if (fromDb.isNotEmpty) return fromDb;
    return AuthDataHelper.getAccountId().trim();
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('🎯 SavedQuotationsController initialized');
  }

  /// Call from dashboard / Recent Quotations screen when the list should load.
  /// Automatically forces a refresh when the logged-in account changes.
  void ensureQuotesLoaded({bool forceRefresh = false}) {
    final accountId = _currentAccountId;
    final accountChanged =
        accountId.isNotEmpty && accountId != _lastLoadedAccountId;
    if (!forceRefresh &&
        !accountChanged &&
        !isLoading &&
        quotesList.isNotEmpty) {
      return;
    }
    fetchSavedQuotes();
  }

  Future<void> fetchSavedQuotes() async {
    debugPrint("🔄 fetchSavedQuotes Started...");

    // Snapshot the account ID we're fetching for, so we can detect staleness.
    final fetchingForAccount = _currentAccountId;

    isLoading = true;
    quotesLoadFailed = false;
    // Clear stale data from a previous account immediately so the UI never
    // shows another user's quotations while the new fetch is in flight.
    if (fetchingForAccount != _lastLoadedAccountId &&
        _lastLoadedAccountId.isNotEmpty) {
      quotesList = [];
      debugPrint(
        "🔄 Account changed ($fetchingForAccount) — cleared stale quotes",
      );
    }
    update();

    try {
      var response = await ApiProvider().savedQuotations();
      debugPrint("📡 API Response Message: ${response.message}");

      if (response.success == true ||
          response.code == 200 ||
          (response.body?.isNotEmpty ?? false)) {
        quotesList = SavedQuotationsModel.forRecentList(response.body ?? []);
        _lastLoadedAccountId = fetchingForAccount;
        quotesLoadFailed = false;
        debugPrint(
          "✅ Quotes loaded for account=$fetchingForAccount: ${quotesList.length}",
        );
      } else if (response.message?.toString().contains(
            "No matching record find",
          ) ??
          false) {
        quotesList = [];
        quotesLoadFailed = false;
        _lastLoadedAccountId = fetchingForAccount;
      } else {
        quotesList = [];
        quotesLoadFailed = true;
        Get.snackbar("Error", response.message ?? "Failed to fetch data");
      }
    } catch (e, stack) {
      debugPrint("❗️ Controller Catch: $e");
      debugPrint("❗️ StackTrace: $stack");
      quotesList = [];
      quotesLoadFailed = true;
    } finally {
      isLoading = false;
      update();
    }
  }

  void removeQuote(int index) {
    quotesList.removeAt(index);
    update();
  }

  ///--------------------- Get Quote Details------------------

  Future<void> fetchQuoteDetails(
    String id, {
    SavedQuotationsModel? seedQuote,
  }) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      errorMessage = 'Quote id is required.';
      update();
      return;
    }

    try {
      isDetailLoading = true;
      isPdfLoading = true;
      errorMessage = '';
      bookingDetailItems = [];
      activeQuoteDetail = seedQuote;
      quotePdfList = [];
      quotePdfError = '';
      update();

      SavedQuotationsModel? cached = seedQuote;
      for (final quote in quotesList) {
        if (quote.id?.trim() == trimmedId) {
          cached = SavedQuotationsModel.merge([cached, quote]);
          break;
        }
      }

      if (cached?.hasResolvedPorts != true ||
          cached?.loadType == null ||
          (cached?.netWeight == null && cached?.grossWeight == null)) {
        final listResponse = await ApiProvider().savedQuotations();
        if (_isApiSuccess(listResponse) && listResponse.body != null) {
          for (final quote in listResponse.body!) {
            if (quote.id?.trim() == trimmedId) {
              cached = SavedQuotationsModel.merge([cached, quote]);
              break;
            }
          }
        }
      }

      final headerResponse = await ApiProvider().fetchQuoteHeader(
        quoteId: trimmedId,
      );
      final lineResponse = await ApiProvider().getQuoteDetails(
        quoteId: trimmedId,
      );

      final headerOk = _isApiSuccess(headerResponse);
      final lineOk = _isApiSuccess(lineResponse);

      final lineBody = lineResponse.body;
      final lineQuote = lineOk ? lineBody?.quote : null;

      activeQuoteDetail = SavedQuotationsModel.merge([
        seedQuote,
        cached,
        lineQuote,
        headerOk ? headerResponse.body : null,
      ]);

      if (lineOk && lineBody != null) {
        bookingDetailItems = lineBody.lineItems;
        debugPrint('✅ Quote line items: ${bookingDetailItems.length}');
      } else {
        bookingDetailItems = [];
      }

      final hasHeader =
          activeQuoteDetail != null &&
          (activeQuoteDetail!.hasDisplayData ||
              activeQuoteDetail!.hasResolvedPorts ||
              activeQuoteDetail!.loadType != null ||
              activeQuoteDetail!.netWeight != null ||
              activeQuoteDetail!.grossWeight != null);
      final lineApiOk = lineOk || lineQuote != null;

      if (bookingDetailItems.isEmpty && !hasHeader) {
        errorMessage =
            lineApiOk
                ? (lineResponse.message ??
                    'No line items found for this quote.')
                : (lineResponse.message ?? 'Failed to fetch quote line items.');
      } else {
        errorMessage = '';
      }

      if (!hasHeader && !lineApiOk && !headerOk) {
        errorMessage =
            lineResponse.message ??
            headerResponse.message ??
            'Failed to fetch quote details.';
      }

      isDetailLoading = false;
      update();

      await _loadQuotePdfs(trimmedId);

      debugPrint(
        '✅ Quote header: ports=${activeQuoteDetail?.originPortR?.name}'
        ' → ${activeQuoteDetail?.destinationPortR?.name}, '
        'loadType=${activeQuoteDetail?.loadType}, '
        'net=${activeQuoteDetail?.netWeight}, '
        'gross=${activeQuoteDetail?.grossWeight}',
      );
    } catch (e) {
      debugPrint('❌ fetchQuoteDetails error: $e');
      bookingDetailItems = [];
      activeQuoteDetail = SavedQuotationsModel.merge([
        seedQuote,
        activeQuoteDetail,
      ]);
      quotePdfList = [];
      quotePdfError = '';
      errorMessage = 'Failed to fetch quote details.';
    } finally {
      isDetailLoading = false;
      isPdfLoading = false;
      update();
    }
  }

  void clearDetailState() {
    isDetailLoading = false;
    isPdfLoading = false;
    activeQuoteDetail = null;
    bookingDetailItems = [];
    quotePdfList = [];
    quotePdfError = '';
    errorMessage = '';
  }

  Future<void> _loadQuotePdfs(String quoteId) async {
    isPdfLoading = true;
    quotePdfList = [];
    quotePdfError = '';
    update();

    try {
      final pdfResponse = await ApiProvider().fetchQuotePdfs(quoteId: quoteId);
      _applyQuotePdfResponse(pdfResponse);
    } catch (e) {
      debugPrint('❌ _loadQuotePdfs error: $e');
      quotePdfList = [];
      quotePdfError = 'Unable to load quote PDFs.';
    } finally {
      isPdfLoading = false;
      update();
    }
  }

  void _applyQuotePdfResponse(DataResponse<List<OrderDocumentModel>> response) {
    final documents = response.body ?? [];
    if (documents.isNotEmpty) {
      quotePdfList = documents;
      quotePdfError = '';
      debugPrint('✅ Quote PDFs loaded: ${quotePdfList.length}');
      return;
    }

    quotePdfList = [];
    final apiMessage = response.message?.trim();
    if (response.success == true ||
        response.code == 200 ||
        response.code == 404) {
      quotePdfError =
          apiMessage?.isNotEmpty == true
              ? apiMessage!
              : 'No PDF documents available for this quote.';
    } else {
      quotePdfError =
          apiMessage?.isNotEmpty == true
              ? apiMessage!
              : 'Failed to load quote PDFs.';
    }
    debugPrint('⚠️ Quote PDFs empty — message=$quotePdfError');
  }

  bool _isApiSuccess(dynamic response) {
    return response.success == true ||
        response.success == 200 ||
        response.code == 200 ||
        (response.body != null &&
            response.body is QuoteLineDetailsResult &&
            ((response.body as QuoteLineDetailsResult).quote?.hasDisplayData ==
                    true ||
                (response.body as QuoteLineDetailsResult)
                    .lineItems
                    .isNotEmpty));
  }
}
