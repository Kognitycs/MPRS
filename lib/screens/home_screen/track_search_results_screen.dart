import 'package:flutter/material.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/utils/track_search_navigation.dart';
import 'package:mprs_android/service/shipment_track_search_service.dart';
import 'package:mprs_android/widget/common_appbar.dart';

/// Search results for home "Track your Shipment" — tap a card to open details.
class TrackSearchResultsScreen extends StatelessWidget {
  final String query;
  final List<TrackSearchHit> hits;
  final BookingController bookingController;

  const TrackSearchResultsScreen({
    super.key,
    required this.query,
    required this.hits,
    required this.bookingController,
  });

  static const Color _navy = Color(0xFF185FA5);
  static const Color _border = Color(0xFFE4E7EC);
  static const Color _pageBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: const CommonAppBar(title: 'Search Result'),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: hits.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${hits.length} result${hits.length == 1 ? '' : 's'} for "$query"',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
          final hit = hits[index - 1];
          return _SearchResultCard(
            hit: hit,
            onTap: () => TrackSearchNavigation.openHit(
              context,
              hit: hit,
              bookingController: bookingController,
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final TrackSearchHit hit;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.hit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TrackSearchResultsScreen._border, width: 0.5),

        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForKind(hit.kind),
                color: TrackSearchResultsScreen._navy,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hit.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      _KindChip(kind: hit.kind),
                    ],
                  ),
                  if (hit.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      hit.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForKind(TrackSearchKind kind) {
    switch (kind) {
      case TrackSearchKind.booked:
        return Icons.directions_boat_rounded;
      case TrackSearchKind.inProgress:
        return Icons.access_time_rounded;
      case TrackSearchKind.shipment:
        return Icons.description_outlined;
    }
  }
}

class _KindChip extends StatelessWidget {
  final TrackSearchKind kind;

  const _KindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      TrackSearchKind.booked => 'Booked',
      TrackSearchKind.inProgress => 'In progress',
      TrackSearchKind.shipment => 'Quote',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3B6D11),
        ),
      ),
    );
  }
}
