import 'package:flutter/material.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart';

/// Route details on pricebook / MLO result cards (routing, transit time).
class PricebookEntryCardDetails extends StatelessWidget {
  const PricebookEntryCardDetails({super.key, required this.entry});

  final PricebookEntryModel entry;

  static String routingLabel(PricebookEntryModel entry) {
    return entry.routingDisplay == 'Direct' ? 'Direct' : 'Indirect';
  }

  static String transitLabel(PricebookEntryModel entry) {
    final transit = entry.transitTimeDisplay?.trim() ?? '';
    return transit.isEmpty ? 'NA' : transit;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          _infoBox('Routing: ${routingLabel(entry)}'),
          const SizedBox(height: 10),
          _infoBox('Estimated Transit Time: ${transitLabel(entry)}'),
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Color(0xFF222222),
        ),
      ),
    );
  }
}
