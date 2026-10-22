import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/widget/common_appbar.dart';

import 'invoice_detail_screen.dart';

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final invoices = List.generate(4, (_) => InvoiceData());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Invoice",
        onActionPressed: () {},
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return InvoiceCard(data: invoices[index]);
        },
      ),
    );
  }
}
class InvoiceCard extends StatelessWidget {
  final InvoiceData data;

  const InvoiceCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// INVOICE HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Invoice #${data.invoiceNumber}",
                  style: AppTextStyles.montserratSemiBold.copyWith(
                    fontSize: 15,
                  ),
                ),
                Text(
                  "Delivered on ${data.deliveryDate}",
                  style: AppTextStyles.montserratSemiBold.copyWith(
                    color: Colors.green,
                    fontSize: 14,
                  ),
                )
              ],
            ),

            const SizedBox(height: 14),

            /// TRACKING NUMBER
            Row(
              children: [
                Text(
                  "Tracking Number:",
                  style: AppTextStyles.montserratRegular
                      .copyWith(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  "#${data.trackingNumber}",
                  style: AppTextStyles.montserratRegular.copyWith(fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// ORIGIN
            Row(
              children: [
                Text(
                  "Origin:",
                  style: AppTextStyles.montserratRegular
                      .copyWith(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  data.origin,
                  style: AppTextStyles.montserratRegular.copyWith(fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// DESTINATION
            Row(
              children: [
                Text(
                  "Destination:",
                  style: AppTextStyles.montserratRegular
                      .copyWith(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  data.destination,
                  style:
                  AppTextStyles.montserratRegular.copyWith(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// DATA MODEL
class InvoiceData {
  final String invoiceNumber;
  final String trackingNumber;
  final String origin;
  final String destination;
  final String deliveryDate;

  InvoiceData({
    this.invoiceNumber = "43975749",
    this.trackingNumber = "43975749",
    this.origin = "New York, NY",
    this.destination = "Los Angeles, CA",
    this.deliveryDate = "12 Oct",
  });
}
