import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/screens/booking/booking_detail_screen.dart';
import 'package:mprs_android/screens/quote/quote_card_detail_screen.dart';
import 'package:mprs_android/service/shipment_track_search_service.dart';

/// Opens booking / quote detail for a track-search hit (home search results).
class TrackSearchNavigation {
  TrackSearchNavigation._();

  static Future<void> openHit(
    BuildContext context, {
    required TrackSearchHit hit,
    required BookingController bookingController,
  }) async {
    switch (hit.kind) {
      case TrackSearchKind.booked:
        final record = hit.bookingRecord;
        if (record == null) return;
        final orderId = hit.orderId ?? record.id?.toString() ?? '';
        final quoteId = hit.quoteId ?? record.quoteId?.toString() ?? '';
        await bookingController.fetchBookingDetails(
          quoteId: quoteId,
          orderId: orderId,
        );
        if (!context.mounted) return;
        await Get.to(
          () => const BookingDetailScreen(),
          arguments: {
            'orderId': orderId,
            'detailData': bookingController.bookingDetailData,
          },
        );
        return;

      case TrackSearchKind.inProgress:
        final record = hit.bookingRecord;
        if (record == null) return;
        final quote = SavedQuotationsModel(
          id: hit.quoteId ?? record.id?.toString(),
          name: record.quoteName?.toString(),
          status: record.trackingStatusC?.toString(),
          opportunityName: record.opportunityName?.toString(),
        );
        if (!context.mounted) return;
        QuoteCardDetailScreen.open(context, quote);
        return;

      case TrackSearchKind.shipment:
        final record = hit.shipmentRecord;
        if (record == null) return;
        if (!context.mounted) return;
        if (hit.quoteSeed != null) {
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => QuoteCardDetailScreen(
                quote: hit.quoteSeed!,
                shipmentRecord: record,
              ),
            ),
          );
        } else {
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => QuoteCardDetailScreen.fromShipment(record),
            ),
          );
        }
        return;
    }
  }
}
