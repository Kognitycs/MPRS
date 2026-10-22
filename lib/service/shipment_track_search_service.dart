import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/core/constants/base_client.dart';
import 'package:mprs_android/core/constants/data_response.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart' as booking;
import 'package:mprs_android/model/get_shipment_model.dart' as shipment;
import 'package:mprs_android/model/saved_quotations_model.dart';

enum TrackSearchKind { booked, inProgress, shipment }

class TrackSearchHit {
  final TrackSearchKind kind;
  final String title;
  final String subtitle;
  final String? quoteId;
  final String? orderId;
  final booking.Records? bookingRecord;
  final shipment.Records? shipmentRecord;
  final SavedQuotationsModel? quoteSeed;

  const TrackSearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.quoteId,
    this.orderId,
    this.bookingRecord,
    this.shipmentRecord,
    this.quoteSeed,
  });
}

/// Home "Track your Shipment" search — QT number, order number, MSL opportunity.
class ShipmentTrackSearchService {
  static bool matchesQuery(
    String query, {
    String? qtNumber,
    String? orderNumber,
    String? mslOpportunity,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;

    for (final raw in [qtNumber, orderNumber, mslOpportunity]) {
      final value = (raw ?? '').toString().trim().toLowerCase();
      if (value.isNotEmpty && value.contains(q)) return true;
    }
    return false;
  }

  static bool matchesBooking(booking.Records record, String query) {
    return matchesQuery(
      query,
      qtNumber: record.quoteName?.toString(),
      orderNumber: record.orderNumber?.toString(),
      mslOpportunity: record.opportunityName?.toString(),
    );
  }

  static bool matchesShipment(
    shipment.Records record,
    String query, {
    String? opportunityName,
  }) {
    return matchesQuery(
      query,
      qtNumber: record.name?.toString(),
      orderNumber: record.orderNumber?.toString(),
      mslOpportunity:
          record.opportunity?.name?.toString() ?? opportunityName,
    );
  }

  Future<List<TrackSearchHit>> search(
    String query, {
    required BookingController bookingController,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    await bookingController.getConfirmedBookings();
    await bookingController.getInProgressBookings();

    final hits = <TrackSearchHit>[];
    final seenKeys = <String>{};

    void addHit(TrackSearchHit hit) {
      final key = hit.orderId?.isNotEmpty == true
          ? 'order:${hit.orderId}'
          : 'quote:${hit.quoteId ?? hit.title}';
      if (seenKeys.add(key)) hits.add(hit);
    }

    final bookedRecords = [
      ...bookingController.allBookings,
      ...await _loadSfBookedOrders(),
    ];

    for (final record in bookedRecords) {
      if (!matchesBooking(record, q)) continue;
      addHit(
        TrackSearchHit(
          kind: TrackSearchKind.booked,
          title: record.orderNumber?.toString() ?? record.quoteName?.toString() ?? 'Booking',
          subtitle: _bookingSubtitle(record),
          quoteId: record.quoteId?.toString(),
          orderId: record.id?.toString(),
          bookingRecord: record,
        ),
      );
    }

    for (final record in bookingController.inProgressBookings) {
      if (!matchesBooking(record, q)) continue;
      addHit(
        TrackSearchHit(
          kind: TrackSearchKind.inProgress,
          title: record.quoteName?.toString() ?? 'Quote',
          subtitle: record.opportunityName?.toString() ?? 'In progress',
          quoteId: record.quoteId?.toString() ?? record.id?.toString(),
          bookingRecord: record,
        ),
      );
    }

    final adminQuotes = AuthDataHelper.isAdminUser()
        ? await ApiProvider().fetchAdminAppCreatedQuotations()
        : <SavedQuotationsModel>[];
    final adminById = {
      for (final quote in adminQuotes)
        if (quote.id != null && quote.id!.trim().isNotEmpty)
          quote.id!.trim(): quote,
    };

    final shipmentRecords = await _loadShipmentRecords();
    for (final record in shipmentRecords) {
      final id = record.id?.toString().trim() ?? '';
      final seed = adminById[id];
      if (!matchesShipment(record, q, opportunityName: seed?.opportunityName)) {
        continue;
      }
      addHit(
        TrackSearchHit(
          kind: TrackSearchKind.shipment,
          title: record.name?.toString() ?? seed?.name ?? 'Quote',
          subtitle: record.opportunity?.name?.toString() ??
              seed?.opportunityName ??
              record.status?.toString() ??
              '',
          quoteId: id.isNotEmpty ? id : null,
          orderId: record.orderNumber?.toString(),
          shipmentRecord: record,
          quoteSeed: seed,
        ),
      );
    }

    return hits;
  }

  static String _bookingSubtitle(booking.Records record) {
    final parts = <String>[
      if ((record.quoteName ?? '').toString().trim().isNotEmpty)
        record.quoteName.toString(),
      if ((record.opportunityName ?? '').toString().trim().isNotEmpty)
        record.opportunityName.toString(),
    ];
    if (parts.isEmpty) {
      return '${record.portOfLoadingC ?? ''} → ${record.portOfDestinationC ?? ''}';
    }
    return parts.join(' • ');
  }

  Future<List<booking.Records>> _loadSfBookedOrders() async {
    if (AuthDataHelper.isAdminUser()) return [];

    final accountId = DbHelper().getUserModel()?.accountId ?? '';
    if (accountId.isEmpty) return [];

    try {
      final response = await BaseClient().handleRequest(
        ApiRequest(
          url: ApiConstants.getDataBookings(accountId),
          method: DioMethod.get,
        ),
      );
      final records = <booking.Records>[];
      final raw = response?['records'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            records.add(
              booking.Records.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<List<shipment.Records>> _loadShipmentRecords() async {
    final results = <shipment.Records>[];

    if (AuthDataHelper.isAdminUser()) {
      final quotes = await ApiProvider().fetchAdminAppCreatedQuotations();
      for (final q in quotes) {
        results.add(
          shipment.Records.fromJson(q.toShipmentRecordJson()),
        );
      }
      return results;
    }

    final accountId = DbHelper().getUserModel()?.accountId ?? '';
    if (accountId.isEmpty) return results;

    for (final url in [
      ApiConstants.getBookingRequestReceived(accountId),
      ApiConstants.getBookingSentToCustomer(accountId),
    ]) {
      try {
        final response = await BaseClient().handleRequest(
          ApiRequest(url: url, method: DioMethod.get),
        );
        final parsed = DataResponse<shipment.GetShipmentModel?>.fromJson(
          response,
          (json) => shipment.GetShipmentModel.fromJson(json),
        );
        if (parsed.body?.records != null) {
          results.addAll(parsed.body!.records!);
        }
      } catch (_) {}
    }

    return results;
  }
}
