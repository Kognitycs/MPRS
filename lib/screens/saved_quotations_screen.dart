import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/screens/quote/quote_card_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import '../controller/saved_quotations_controller.dart';
import '../model/saved_quotations_model.dart';

class SavedQuotationsScreen extends StatefulWidget {
  const SavedQuotationsScreen({super.key});

  @override
  State<SavedQuotationsScreen> createState() => _SavedQuotationsScreenState();
}

class _SavedQuotationsScreenState extends State<SavedQuotationsScreen> {
  late SavedQuotationsController controller;

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 Stateful Screen: initState triggered");

    if (Get.isRegistered<SavedQuotationsController>()) {
      controller = Get.find<SavedQuotationsController>();
    } else {
      controller = Get.put(SavedQuotationsController());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.ensureQuotesLoaded(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Recent Quotations",
        onActionPressed: () => controller.fetchSavedQuotes(),
      ),
      body: GetBuilder<SavedQuotationsController>(
        builder: (ctrl) {
          debugPrint(
            "🎨 GetBuilder: Redrawing UI (isLoading: ${ctrl.isLoading})",
          );

          if (ctrl.isLoading) {
            return _buildShimmerLoading();
          }

          if (ctrl.quotesList.isEmpty) {
            return _buildNoDataFound();
          }

          return Padding(
            padding: const EdgeInsets.only(top: 15.0, right: 15, left: 15),
            child: GridView.builder(
              padding: const EdgeInsets.only(top: 0, bottom: 40),
              itemCount: ctrl.quotesList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 25,
                childAspectRatio: 1.10,
              ),
              itemBuilder: (context, index) {
                final q = ctrl.quotesList[index];
                final Color dynamicColor =
                    (index % 2 == 0)
                        ? Colors.deepOrange
                        : const Color(0xFF2456D5);
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: QuotationCard(
                    data: q,
                    onDelete: () => ctrl.removeQuote(index),
                    accentColor: dynamicColor,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// --- SHIMMER LOADING UI ---
  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: GridView.builder(
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 1.10,
        ),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  /// --- NO DATA FOUND UI ---
  Widget _buildNoDataFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No Saved Quotations Found",
            style: AppTextStyles.montserratBold.copyWith(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your saved quotes will appear here.",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class QuotationCard extends StatelessWidget {
  final SavedQuotationsModel data;
  final VoidCallback? onDelete;
  final Color accentColor; // Naya parameter

  const QuotationCard({
    super.key,
    required this.data,
    this.onDelete,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 26;

    return GestureDetector(
      onTap: () => QuoteCardDetailScreen.open(context, data),
      onLongPress: onDelete,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            /// MAIN CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: Colors.deepOrange,
                          ),
                          Container(
                            width: 2,
                            height: 38,
                            color: Colors.grey.shade300,
                          ),
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: Colors.deepOrange,
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                data.originPortLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppTextStyles.montserratSemiBold.copyWith(
                                  fontSize: 13,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                data.destinationPortLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppTextStyles.montserratSemiBold.copyWith(
                                  fontSize: 13,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_right_alt_sharp,
                        color: Colors.deepOrange,
                        size: 24,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    "Starting from",
                    style: AppTextStyles.montserratMedium.copyWith(
                      color: AppColors.grey.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.formattedPrice,
                    style: AppTextStyles.montserratSemiBold.copyWith(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: -12,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_boat,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
