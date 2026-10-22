import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/widget/common_appbar.dart';

class QuoteDetailScreen extends StatefulWidget {
  const QuoteDetailScreen({super.key});

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  final SavedQuotationsController controller =
      Get.find<SavedQuotationsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String? quoteId = Get.arguments;
      if (quoteId != null) {
        controller.fetchQuoteDetails(quoteId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Get.back(result: true);
      },
      child: Scaffold(
        appBar: CommonAppBar(
          title: "Quote Detail",
          onBack: () => Get.back(result: true),
        ),
        backgroundColor: AppColors.white,
        body: GetBuilder<SavedQuotationsController>(
          builder: (ctrl) {
            if (ctrl.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (ctrl.bookingDetailItems.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    ctrl.errorMessage.isEmpty
                        ? "No items found"
                        : ctrl.errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            final firstItem = ctrl.bookingDetailItems.first;

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Text(
                          "Line No: #${firstItem.lineNumber ?? 'N/A'}",
                          style: AppTextStyles.montserratBold.copyWith(
                            color: AppColors.main,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Service Type / Product
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            firstItem.product ?? "Service Details",
                            style: AppTextStyles.montserratSemiBold.copyWith(
                              color: Colors.blue,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Fare Breakdown",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Divider(),
                          ...ctrl.bookingDetailItems.map((item) {
                            final amount = item.lineAmountByFinalSell;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.product ?? "Charge",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    amount.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E7EC)),

                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            "Application Method",
                            firstItem.applicationMethod ?? "N/A",
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            "Currency",
                            firstItem.currencyIsoCode ?? "N/A",
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow("Tax", "${firstItem.tax ?? 0}%"),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            "Quantity",
                            "${firstItem.quantity?.toInt() ?? 0}",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                    Text("Documents", style: AppTextStyles.montserratBold),
                    const SizedBox(height: 16),
                    _buildDownloadCard(
                      "Quote Proposal - ${firstItem.lineNumber}",
                    ),
                    const SizedBox(height: 12),
                    _buildDownloadCard("Terms & Conditions"),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.montserratSemiBold.copyWith(
            color: AppColors.grey,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.montserratSemiBold.copyWith(
            color: AppColors.black,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadCard(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.montserratSemiBold.copyWith(fontSize: 14),
            ),
          ),
          const Icon(
            Icons.file_download_outlined,
            size: 22,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}
