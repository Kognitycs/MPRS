import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class OfferCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String validUntil;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApply;

  const OfferCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.validUntil,
    required this.onEdit,
    required this.onDelete,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE (semibold)
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 6),

                // DESCRIPTION
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 10),

                // VALID DATE
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: "Valid until ",
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                      TextSpan(
                        text: validUntil,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    // EDIT
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ), // FIX
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Edit",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // DELETE
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ), // FIX
                          side: BorderSide(color: AppColors.secondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Delete",
                          style: TextStyle(color: AppColors.secondary),
                          overflow:
                              TextOverflow.visible, // ENSURES TEXT NOT CUT
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // APPLY NOW (bigger)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onApply,
                        style: ElevatedButton.styleFrom(
                          padding:  EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.main,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Apply Now"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
