import 'package:flutter/material.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/screens/home_screen/track_search_results_screen.dart';
import 'package:mprs_android/screens/main_tabs.dart';
import 'package:mprs_android/screens/quote/get_quote_screen.dart';
import 'package:mprs_android/screens/support_screen.dart';
import 'package:mprs_android/service/shipment_track_search_service.dart';

/// Routes the home Genie prompt to the same screens the app already uses.
class HomeActions {
  static bool looksLikeTrackingId(String raw) {
    final query = raw.trim();
    if (query.length < 4) return false;
    if (RegExp(
      r'^(QT|MSL|ORD|BL)[- ]?[A-Z0-9]+',
      caseSensitive: false,
    ).hasMatch(query)) {
      return true;
    }
    if (RegExp(r'^[A-Z]{4}\d{6,7}$', caseSensitive: false).hasMatch(query)) {
      return true;
    }
    if (RegExp(r'^\d{5,}$').hasMatch(query)) return true;
    return false;
  }

  static Future<void> trackShipment(
    BuildContext context,
    String query,
    BookingController bookingController,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _snack(context, 'Enter a QT number, order number, or container number');
      return;
    }

    try {
      final hits = await ShipmentTrackSearchService().search(
        trimmed,
        bookingController: bookingController,
      );
      if (!context.mounted) return;
      if (hits.isEmpty) {
        _snack(context, 'No shipment found for "$trimmed"');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => TrackSearchResultsScreen(
                query: trimmed,
                hits: hits,
                bookingController: bookingController,
              ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Search failed: $e');
    }
  }

  /// Handles the Genie field and the shortcut chips.
  static Future<void> handlePrompt(
    BuildContext context,
    String raw,
    BookingController bookingController,
  ) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final lower = query.toLowerCase();

    if (looksLikeTrackingId(query) ||
        lower.startsWith('track ') ||
        lower.startsWith('container ')) {
      final id =
          looksLikeTrackingId(query)
              ? query
              : query.replaceFirst(
                RegExp(r'^(track|container)\s+', caseSensitive: false),
                '',
              );
      await trackShipment(context, id, bookingController);
      return;
    }

    if (lower.contains('support') ||
        lower.contains('contact') ||
        lower.contains('help')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
      );
      return;
    }

    if (lower.contains('quote') || lower.contains('quotation')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GetQuoteScreen()),
      );
      return;
    }

    if (lower.contains('book')) {
      MainTabs.open(
        const MainTabRequest(
          index: MainTabs.book,
          bookTab: 1,
          bookQuoteFilter: 1,
        ),
      );
      return;
    }

    if (lower.contains('track') ||
        lower.contains('container') ||
        lower.contains('shipment')) {
      MainTabs.open(const MainTabRequest(index: MainTabs.track));
      return;
    }

    if (lower.contains('rate') ||
        lower.contains('cheap') ||
        lower.contains('route') ||
        lower.contains(' to ')) {
      MainTabs.open(const MainTabRequest(index: MainTabs.search));
      return;
    }

    MainTabs.open(
      MainTabRequest(index: MainTabs.genie, geniePrompt: query),
    );
  }

  static void openSearch() {
    MainTabs.open(const MainTabRequest(index: MainTabs.search));
  }

  static void openBook({int bookTab = 0, int? quoteFilter}) {
    MainTabs.open(
      MainTabRequest(
        index: MainTabs.book,
        bookTab: bookTab,
        bookQuoteFilter: quoteFilter,
      ),
    );
  }

  static void openTrack({int? shipmentsTab}) {
    MainTabs.open(
      MainTabRequest(index: MainTabs.track, shipmentsTab: shipmentsTab),
    );
  }

  static void openGenie([String? prompt]) {
    MainTabs.open(MainTabRequest(index: MainTabs.genie, geniePrompt: prompt));
  }

  static Future<void> openSupport(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
    );
  }

  static Future<void> openCreateQuote(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GetQuoteScreen()),
    );
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
