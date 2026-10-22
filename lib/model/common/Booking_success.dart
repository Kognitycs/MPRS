import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/main_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  /// Pass the support contacts from your API response or hardcode them.
  final List<ContactPerson> contacts;

  const BookingSuccessScreen({
    super.key,
    this.contacts = const [],
  });

  static void goToShipments() {
    Get.offAll(
      () => const MainScreen(initialTab: 3, initialShipmentsTab: 0),
    );
  }

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const BookingSuccessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.black),
          onPressed: BookingSuccessScreen.goToShipments,
        ),
        title: const Text(
          "Request Submitted",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── SUCCESS BANNER ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xffEEF7EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Green check circle with decorative dots
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Decorative dots
                      _dot(top: -18, left: 10),
                      _dot(top: -14, right: 14),
                      _dot(bottom: -10, left: 5),
                      _dot(bottom: -12, right: 8),

                      Container(
                        height: 72,
                        width: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xff4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Request is raised with our team.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Our team will come back to you once the\nbooking is completed.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── DIVIDER WITH HEADPHONE ICON ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.headset_mic_outlined,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── CONTACT SECTION HEADER ─────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: AppColors.main,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Need Help? Contact Our Team",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── CONTACT CARDS ──────────────────────────────────────────
            if (contacts.isEmpty)
            // Fallback demo contacts (replace with real data)
              ...[
                _buildContactCard(
                  ContactPerson(
                    name: "Kanchan Hargane",
                    email: "shubham@kognitycs.com",
                    phone: "9869213221",
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactCard(
                  ContactPerson(
                    name: "Lubna Patel",
                    email: "lubna.pateltest@mprsshipping.com",
                    phone: "9987462095",
                  ),
                ),
              ]
            else
              ...contacts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildContactCard(c),
              )),

            const SizedBox(height: 32),

            // ── BACK TO LIST BUTTON ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: BookingSuccessScreen.goToShipments,
                child: const Text(
                  "View booked shipment",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildContactCard(ContactPerson contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle with first letter
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.purple.shade100,
            child: Text(
              contact.name.isNotEmpty
                  ? contact.name[0].toUpperCase()
                  : "?",
              style: TextStyle(
                color: Colors.purple.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                _infoRow(
                  icon: Icons.mail_outline,
                  text: "Mail : ${contact.email}",
                ),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.phone_outlined,
                  text: "Phone : ${contact.phone}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.main),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Small decorative dot used around the success icon.
  Widget _dot({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        height: 7,
        width: 7,
        decoration: const BoxDecoration(
          color: Color(0xff4CAF50),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── DATA MODEL ──────────────────────────────────────────────────────────────

class ContactPerson {
  final String name;
  final String email;
  final String phone;

  const ContactPerson({
    required this.name,
    required this.email,
    required this.phone,
  });
}