import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/widget/common_appbar.dart';

class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "#43975749",
        onActionPressed: () {},
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 10),

            /// Top Status Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                  "#43975749",
                  style: AppTextStyles.montserratBold.copyWith(
                    color: AppColors.main,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

          Row(
            children: [
              const Icon(Icons.local_shipping, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Container Discharged at Trans-Shipment Port",
                  style: AppTextStyles.montserratSemiBold.copyWith(
                    color: Colors.green,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.visible, // optional
                  softWrap: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

            /// Route Information
            Row(
              children: [

                Column(
                  children:  [
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color:  AppColors.yellow,
                        ),
                        SizedBox(width: 3),
                        Text("Nhava Sheva", style: AppTextStyles.montserratSemiBold.copyWith(),)
                    ]),
                    SizedBox(height: 4),
                    Text("28-04-2023", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(thickness: 1),
                  ),
                ),
                Column(
                  children:  [
                    Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            color:  AppColors.yellow,
                          ),
                          SizedBox(width: 3),
                          Text("Ajman", style: AppTextStyles.montserratSemiBold.copyWith()),
                        ]),

                    SizedBox(height: 4),
                    Text("14-05-2023", style: AppTextStyles.montserratSemiBold.copyWith(color: Colors.grey)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// Vessel Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:  [
                  Text(
                    "Vessel Name & Voyage Number:",
                    style: AppTextStyles.montserratSemiBold.copyWith(color: AppColors.grey),
                  ),
                  SizedBox(height: 4),
                  Text("Evergreen Teresa - V.284",style: AppTextStyles.montserratSemiBold.copyWith(color: AppColors.black)),

                  SizedBox(height: 12),

                  Text("Container ID:", style: AppTextStyles.montserratSemiBold.copyWith(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text("2325928",style: AppTextStyles.montserratSemiBold.copyWith(color: AppColors.black)),

                  SizedBox(height: 12),

                  Text("Reference Number:", style: AppTextStyles.montserratSemiBold.copyWith(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text("29547364023752",style: AppTextStyles.montserratSemiBold.copyWith(color: AppColors.black)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// Timeline Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    /// Blue Bullet
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.main,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:  [
                        Text(
                          "Booked",
                          style: AppTextStyles.montserratSemiBold.copyWith(fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text("18/07/2025", style: AppTextStyles.montserratSemiBold.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    /// Green Bullet
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:  [
                        Text(
                          "Empty Container Delivered on 12 Sep",
                          style: AppTextStyles.montserratSemiBold.copyWith(
                            fontSize: 15,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text("12/09/2025", style: AppTextStyles.montserratSemiBold.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
             Text(
              "See all updates",
              style: AppTextStyles.montserratSemiBold.copyWith(color: AppColors.main),
            ),

            const SizedBox(height: 30),

            /// Downloads Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Row(
                children:  [
                  Icon(Icons.insert_drive_file, color: AppColors.main, size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Download invoice",
                      style: AppTextStyles.montserratSemiBold.copyWith(fontSize: 16,),
                    ),
                  ),
                  Icon(Icons.download, size: 28),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
