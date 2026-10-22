import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/quote/get_quote_screen.dart';

import '../../model/pricebook_entry_model.dart';

class AdditionalService {
  final String title;
  final String? badge;
  final Color? badgeColor;
  final String description;
  final String detail;
  final String price;
  final String unit;
  final IconData icon;
  bool added;

  AdditionalService({
    required this.title,
    this.badge,
    this.badgeColor,
    required this.description,
    required this.detail,
    required this.price,
    required this.unit,
    required this.icon,
    this.added = false,
  });
}

class AdditionalServicesScreen extends StatefulWidget {
  final String? origin;
  final String? destination;
  final String? originDate;
  final String? destinationDate;
  final String? transitTime;
  final double? unitPrice;
  final String? selectedContainerString;
  final String? initialLoadType;
  final String? initialPol;
  final String? initialPod;
  final String? opportunityId;
  final String? initialPolId;
  final String? initialPodId;
  final String? initialContainerType;
  final String? initialContainerSize;
  final String? initialShipmentMode;
  final String? initialContainerQuantity;
  final String? weightPerContainer;
  final String? cargoValue;
  final String? mloCode;
  final List<PricebookEntryModel>? pricebookEntries;
  final String? commodity;
  final String? validFrom;

  const AdditionalServicesScreen({
    super.key,
    this.origin,
    this.destination,
    this.originDate,
    this.destinationDate,
    this.transitTime,
    this.unitPrice,
    this.selectedContainerString,
    this.initialLoadType,
    this.initialPol,
    this.initialPod,
    this.opportunityId,
    this.initialPolId,
    this.initialPodId,
    this.initialContainerType,
    this.initialContainerSize,
    this.initialShipmentMode,
    this.initialContainerQuantity,
    this.weightPerContainer,
    this.cargoValue,
    this.mloCode,
    this.pricebookEntries,
    this.commodity,
    this.validFrom,
  });

  @override
  State<AdditionalServicesScreen> createState() =>
      _AdditionalServicesScreenState();
}

class _AdditionalServicesScreenState extends State<AdditionalServicesScreen> {
  // ── Static placeholder services (real data comes from Salesforce later) ──
  final List<AdditionalService> _services = [
    AdditionalService(
      title: 'Additional Freetime Destination',
      badge: 'New',
      badgeColor: AppColors.main,
      description: 'Additional Time, More Flexibility',
      detail:
      'Purchase additional free time at destination upfront at a discount and plan shipments better in advance.',
      price: 'AED 397',
      unit: '/Container',
      icon: Icons.access_time_rounded,
    ),
    AdditionalService(
      title: 'Cargo Shield',
      badge: 'Recommended',
      badgeColor: AppColors.main,
      description: 'Shield your Cargo, protect your Business.',
      detail:
      'Our additional layer of protection for your cargo protects up to USD 60,000/container.',
      price: 'USD 28',
      unit: '/Container',
      icon: Icons.shield_rounded,
    ),
    AdditionalService(
      title: 'Live Position',
      badge: null,
      description: 'Track your container in real-time throughout the entire journey.',
      detail: '',
      price: 'USD 15',
      unit: '/Container',
      icon: Icons.location_on_rounded,
      added: false, // pre-selected as per design
    ),
    AdditionalService(
      title: 'Ship Green',
      badge: 'Popular',
      badgeColor: const Color(0xFF34A853),
      description:
      'Expected CO₂e Ocean-leg Emissions of Your Shipment: - tons CO₂e',
      detail:
      'Avoid your CO₂e emissions by 100, 50 or 25%.',
      price: 'USD 14',
      unit: '/Container',
      icon: Icons.eco_rounded,
    ),
  ];

  double get _addedTotal {
    return _services.where((s) => s.added).fold(0.0, (sum, s) {
      final num = double.tryParse(
          s.price.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;
      return sum + num;
    });
  }

  void _toggleService(int index) {
    setState(() => _services[index].added = !_services[index].added);
  }

  void _proceed() {

    String? mappedLoadType =
        widget.initialLoadType;

    if (widget.selectedContainerString != null) {

      if (widget.selectedContainerString!
          .contains('FCL')) {

        mappedLoadType = 'FCL';

      } else if (widget
          .selectedContainerString!
          .contains('LCL')) {

        mappedLoadType = 'LCL';

      } else if (widget
          .selectedContainerString!
          .contains('AIR')) {

        mappedLoadType = 'AIR';
      }
    }

    debugPrint(
      "PASSING ENTRIES : "
          "${widget.pricebookEntries?.length}",
    );

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => GetQuoteScreen(

          /// OPPORTUNITY
          opportunityId:
          widget.opportunityId,

          /// LOAD TYPE
          initialLoadType:
          mappedLoadType,

          /// PORTS
          initialPol:
          widget.initialPol,

          initialPod:
          widget.initialPod,

          initialPolId:
          widget.initialPolId,

          initialPodId:
          widget.initialPodId,

          /// CONTAINER
          initialContainerType:
          widget.initialContainerType,

          initialContainerSize:
          widget.initialContainerSize,

          initialShipmentMode:
          (mappedLoadType == "AIR")
              ? "Air"
              : "Ocean",

          initialContainerQuantity:
          widget.initialContainerQuantity,

          initialWeightPerContainer:
          widget.weightPerContainer,

          initialGoodsValue:
          widget.cargoValue,

          /// IMPORTANT
          /// SEND PRICEBOOK ENTRIES
          pricebookEntries:
          widget.pricebookEntries,

          /// MLO
          selectedMloCode:
          widget.mloCode,

          /// COMMODITY
          initialCommodity:
          widget.commodity,

          /// VALID FROM DATE
          initialValidFrom:
          widget.validFrom,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Additional Services',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.main,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Progress steps ─────────────────────────────────────────────
          // _buildProgressBar(),

          // ── Route summary card ─────────────────────────────────────────
          if (widget.origin != null) _buildRouteSummary(),

          // ── Services list ──────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildServiceCard(_services[index], index),
            ),
          ),
        ],
      ),

      // ── Sticky bottom bar ──────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────

  // Widget _buildProgressBar() {
  //   const steps = ['Search', 'Offer Selection', 'Additional Services', 'Review & Next Steps'];
  //   const current = 2; // 0-indexed — we are on step 3
  //
  //   return Container(
  //     color: Colors.white,
  //     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
  //     child: Row(
  //       children: List.generate(steps.length, (i) {
  //         final isDone = i < current;
  //         final isActive = i == current;
  //         return Expanded(
  //           child: Row(
  //             children: [
  //               // Circle
  //               Container(
  //                 width: 24,
  //                 height: 24,
  //                 decoration: BoxDecoration(
  //                   shape: BoxShape.circle,
  //                   color: isDone
  //                       ? AppColors.main
  //                       : isActive
  //                       ? AppColors.secondary
  //                       : Colors.grey.shade300,
  //                 ),
  //                 child: Center(
  //                   child: isDone
  //                       ? const Icon(Icons.check, color: Colors.white, size: 14)
  //                       : Text(
  //                     '${i + 1}',
  //                     style: TextStyle(
  //                       color: isActive ? Colors.white : Colors.grey,
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.w700,
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 4),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       steps[i],
  //                       style: TextStyle(
  //                         fontSize: 9,
  //                         fontWeight: isActive
  //                             ? FontWeight.w700
  //                             : FontWeight.w400,
  //                         color: isActive
  //                             ? AppColors.secondary
  //                             : isDone
  //                             ? AppColors.main
  //                             : Colors.grey,
  //                       ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                     // Connector line (except last)
  //                     if (i < steps.length - 1)
  //                       Container(
  //                         height: 2,
  //                         margin: const EdgeInsets.only(top: 2, right: 4),
  //                         color: isDone
  //                             ? AppColors.main
  //                             : Colors.grey.shade300,
  //                       ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         );
  //       }),
  //     ),
  //   );
  // }

  Widget _buildRouteSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          _routePoint(widget.origin ?? '', widget.originDate ?? '', true),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.arrow_forward, color: AppColors.secondary, size: 18),
                if (widget.transitTime != null)
                  Text(
                    widget.transitTime!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          _routePoint(widget.destination ?? '', widget.destinationDate ?? '', false),
        ],
      ),
    );
  }

  Widget _routePoint(String place, String date, bool isOrigin) {
    return Column(
      crossAxisAlignment:
      isOrigin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            if (!isOrigin) const SizedBox(width: 4),
            Icon(Icons.location_on, color: AppColors.secondary, size: 16),
            if (isOrigin) const SizedBox(width: 4),
            Text(place,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        Text(date,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildServiceCard(AdditionalService service, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: service.added
            ? Border.all(color: AppColors.main, width: 1.5)
            : Border.all(color: Colors.transparent),

      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon box ─────────────────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(service.icon, color: AppColors.main, size: 34),
            ),

            const SizedBox(width: 12),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (service.badge != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (service.badgeColor ?? AppColors.main)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            service.badge!,
                            style: TextStyle(
                              color: service.badgeColor ?? AppColors.main,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    service.description,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF555555)),
                  ),

                  if (service.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showBenefits(service),
                      child: const Text(
                        '→ See Benefits',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.main,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Price + Add/Remove button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'from ${service.price}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            service.unit,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _toggleService(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: service.added
                                ? Colors.red.shade50
                                : AppColors.secondary,
                            borderRadius: BorderRadius.circular(8),
                            border: service.added
                                ? Border.all(color: Colors.red.shade300)
                                : null,
                          ),
                          child: Text(
                            service.added ? 'Remove' : 'Add',
                            style: TextStyle(
                              color: service.added
                                  ? Colors.red
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final addedCount = _services.where((s) => s.added).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
      ),
      child: Row(
        children: [
          // Summary
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$addedCount service${addedCount != 1 ? 's' : ''} added',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
                if (addedCount > 0)
                  Text(
                    '+ \$${_addedTotal.toStringAsFixed(0)} /container',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.main,
                    ),
                  ),
              ],
            ),
          ),

          // Next button
          ElevatedButton(
            onPressed: _proceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Next →',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showBenefits(AdditionalService service) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 12),
            Text(service.detail,
                style:
                const TextStyle(fontSize: 14, color: Color(0xFF444444))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('Got it',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}