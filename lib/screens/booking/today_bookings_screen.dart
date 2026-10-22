import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart';
import 'package:mprs_android/screens/booking/booking_detail_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';

/// Booked orders whose CreatedDate is today.
class TodayBookingsScreen extends StatefulWidget {
  final List<Records> orders;

  const TodayBookingsScreen({super.key, required this.orders});

  @override
  State<TodayBookingsScreen> createState() => _TodayBookingsScreenState();
}

class _TodayBookingsScreenState extends State<TodayBookingsScreen> {
  String? _openingOrderId;

  BookingController get _bookings {
    if (Get.isRegistered<BookingController>(tag: 'all_bookings')) {
      return Get.find<BookingController>(tag: 'all_bookings');
    }
    return Get.put(BookingController(), tag: 'all_bookings');
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Today Booking'),
      body: orders.isEmpty
          ? Center(
              child: Text(
                'No bookings today',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _TodayBookingCard(
                  booking: orders[index],
                  opening: _openingOrderId == orders[index].id?.toString(),
                  onTap: () => _openDetail(orders[index]),
                );
              },
            ),
    );
  }

  Future<void> _openDetail(Records booking) async {
    final orderId = booking.id?.toString().trim() ?? '';
    if (orderId.isEmpty || _openingOrderId != null) return;
    setState(() => _openingOrderId = orderId);
    final ctrl = _bookings;
    try {
      await ctrl.fetchBookingDetails(
        quoteId: booking.quoteId?.toString() ?? '',
        orderId: orderId,
      );
      if (!mounted) return;

      ApiProvider.debugLogOrderDocuments(
        orderId: orderId,
        documents: ctrl.orderDocuments,
        source: 'Today booking',
      );

      final detail = <String, dynamic>{};
      if (ctrl.bookingDetailData is Map) {
        detail.addAll(Map<String, dynamic>.from(ctrl.bookingDetailData as Map));
      }
      void fill(String key, dynamic value) {
        final existing = detail[key];
        final empty = existing == null || existing.toString().trim().isEmpty;
        if (empty && value != null && value.toString().trim().isNotEmpty) {
          detail[key] = value;
        }
      }

      for (final entry in booking.toJson().entries) {
        fill(entry.key, entry.value);
      }
      fill('CreatedDate', booking.createdDate);
      fill('Container_Size__c', booking.containerSizeC);
      fill('Container_Type__c', booking.containerTypeC);
      fill('Mode_of_Shipment__c', booking.modeOfShipmentC);
      fill('Lead_Type__c', booking.leadTypeC);

      await Get.to(
        () => const BookingDetailScreen(),
        arguments: {'orderId': orderId, 'detailData': detail},
      );
    } finally {
      if (mounted) setState(() => _openingOrderId = null);
    }
  }
}

class _TodayBookingCard extends StatelessWidget {
  final Records booking;
  final bool opening;
  final VoidCallback onTap;

  const _TodayBookingCard({
    required this.booking,
    required this.opening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pol = booking.portOfLoadingC?.toString().trim() ?? '';
    final pod = booking.portOfDestinationC?.toString().trim() ?? '';
    final route = [if (pol.isNotEmpty) pol, if (pod.isNotEmpty) pod];
    final orderNo = booking.displayOrderNumber;
    final status = booking.trackingStatusC?.toString().trim() ?? '';
    final booked =
        Records.formatListDate(booking.createdDate) ??
        Records.formatListDate(booking.bookedDateC);
    final mode = booking.modeOfShipmentC?.toString().toLowerCase() ?? '';
    final ocean = !mode.contains('air');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: opening ? null : onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      ocean ? Icons.directions_boat_filled : Icons.flight_rounded,
                      color: AppColors.main,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.isEmpty ? 'Shipment' : route.join('  →  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            height: 1.25,
                          ),
                        ),
                        if (orderNo.isNotEmpty) _line('Order: $orderNo'),
                        if (status.isNotEmpty) _line(status),
                        if (booked != null) _line('Booked date: $booked'),
                      ],
                    ),
                  ),
                  opening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF667085),
          height: 1.3,
        ),
      ),
    );
  }
}
