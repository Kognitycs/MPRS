import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/model/get_booking_list_model.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/reserved_quote_store.dart';

class BookQuoteResult {
  final bool success;
  final String message;

  const BookQuoteResult({required this.success, required this.message});
}

class BookingService {
  /// Account id from profile DB, falling back to login session storage.
  static String resolveAccountId() {
    final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
    if (fromDb.isNotEmpty) return fromDb;
    return AuthDataHelper.getAccountId().trim();
  }

  /// POST /user/book/quote — reserves space for the given quote.
  static Future<BookQuoteResult> reserveQuoteSpace(String quoteId) async {
    final trimmedQuoteId = quoteId.trim();
    if (trimmedQuoteId.isEmpty) {
      return const BookQuoteResult(
        success: false,
        message: 'Quote id is missing — cannot reserve space.',
      );
    }

    final accountId = resolveAccountId();
    if (accountId.isEmpty) {
      return const BookQuoteResult(
        success: false,
        message: 'Account information is missing. Please sign in again.',
      );
    }

    final token = AuthDataHelper.getToken();
    if (token.isEmpty) {
      return const BookQuoteResult(
        success: false,
        message: 'Session expired. Please sign in again.',
      );
    }

    try {
      final response = await HttpClientHelper.postWithBearer(
        ApiConstants.bookQuoteApi,
        token,
        body: jsonEncode({'quoteId': trimmedQuoteId, 'accountId': accountId}),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await ReservedQuoteStore.add(trimmedQuoteId);
        return BookQuoteResult(
          success: true,
          message:
              _extractMessage(response.data) ??
              'Booking submitted successfully',
        );
      }

      return BookQuoteResult(
        success: false,
        message:
            _extractMessage(response.data) ??
            'Booking failed. Please try again.',
      );
    } catch (e) {
      debugPrint('BOOK ERROR: $e');
      return const BookQuoteResult(
        success: false,
        message: 'Booking failed. Please try again.',
      );
    }
  }

  static String? _extractMessage(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  /// Fetch all bookings for the logged-in user using their account_id
  static Future<GetBookingListModel?> getUserBookings() async {
    try {
      final token = AuthDataHelper.getToken();
      final accountId = AuthDataHelper.getAccountId();

      if (token.isEmpty) {
        print('❌ No auth token found');
        return null;
      }

      if (accountId.isEmpty) {
        print('❌ No account_id found for user');
        return null;
      }

      final url = '${ApiConstants.userBookings}?account_id=$accountId';
      print('📡 Fetching bookings from: $url');

      final response = await HttpClientHelper.getWithBearer(url, token);

      print('📡 Booking API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('📡 Raw API Data: ${response.data}');

        final jsonData =
            response.data is String
                ? json.decode(response.data)
                : response.data;

        // final jsonData = json.decode(response.data);
        return GetBookingListModel.fromJson(jsonData);
      } else {
        print('❌ Failed to fetch bookings: ${response.statusCode}');
        print('Response: ${response.data}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching bookings: $e');
      return null;
    }
  }
}
