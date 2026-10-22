import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/shipment_detail_controller.dart';

class ShipmentDetailScreen extends StatelessWidget {
  final controller = Get.put(ShipmentDetailController());

  ShipmentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Obx(() => Text(controller.bookingId.value,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// --- Title ID ---
            Obx(() => Text(controller.bookingId.value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC)))),
            const SizedBox(height: 12),

            /// --- Current Status Row ---
            Row(
              children: [
                const Icon(Icons.directions_boat_filled, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(() => Text(controller.statusText.value,
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// --- Route Row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPortInfo("Nhava Sheva", "28-04-2023"),
                Expanded(child: Container(height: 1, color: Colors.black, margin: const EdgeInsets.symmetric(horizontal: 10))),
                _buildPortInfo("Ajman", "14-05-2023", crossAlign: CrossAxisAlignment.end),
              ],
            ),
            const SizedBox(height: 20),

            /// --- Vessel Detail Card (Full Width Fixed) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem("Vessel Name & Voyage Number:", controller.vesselName.value),
                  const SizedBox(height: 12),
                  _buildDetailItem("Container ID:", controller.containerId.value),
                  const SizedBox(height: 12),
                  _buildDetailItem("Reference Number:", controller.referenceNumber.value),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /// --- Timeline with Expand Logic ---
            Obx(() {
              // Agar expanded nahi hai to sirf pehla aur aakhri item dikhao
              final displayList = controller.isExpanded.value
                  ? controller.timelineData
                  : [controller.timelineData.first, controller.timelineData.last];

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final item = displayList[index];
                  // Last Green Text check
                  bool isLastItem = item['status'] == controller.timelineData.last['status'];
                  // Line tabhi dikhao jab current item aakhri na ho
                  bool showLine = index != displayList.length - 1;

                  return _buildTimelineItem(
                    item['status'],
                    item['date'],
                    isLastItem,
                    showLine: showLine,
                    sub: item['sub'],
                  );
                },
              );
            }),

            /// --- Toggle Button ---
            Obx(() => TextButton(
                onPressed: () => controller.toggleExpansion(),
                child: Text(
                    controller.isExpanded.value ? "Show less" : "See all updates",
                    style: const TextStyle(decoration: TextDecoration.underline, color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold)
                )
            )),

            const SizedBox(height: 20),
            const Text("Downloads", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            /// --- Download Invoice Button ---
            _buildDownloadCard("Download invoice"),
          ],
        ),
      ),
    );
  }

  /// Port helper
  Widget _buildPortInfo(String name, String date, {CrossAxisAlignment crossAlign = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Row(
          children: [
            const Icon(Icons.directions_boat, size: 16, color: Colors.deepOrangeAccent),
            const SizedBox(width: 4),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  /// Detail Item helper
  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }

  /// Timeline Row helper (Line Logic Updated)
  Widget _buildTimelineItem(String title, String date, bool isGreen, {required bool showLine, String? sub}) {
    Color activeColor = isGreen ? Colors.green : const Color(0xFF3F63B5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.circle, size: 12, color: activeColor),
            if (showLine)
              Container(
                  width: 2,
                  height: sub != null ? 60 : 40,
                  color: Colors.grey.shade300
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: activeColor)),
              if (sub != null) Text(sub, style: TextStyle(color: activeColor)),
              Text(date, style: TextStyle(color: isGreen ? Colors.green.shade300 : Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  /// Download Card helper
  Widget _buildDownloadCard(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: Color(0xFF3F63B5)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(color: Colors.grey.shade700))),
          const Icon(Icons.print_outlined, color: Colors.grey),
          const SizedBox(width: 16),
          const Icon(Icons.file_download_outlined, color: Colors.grey),
        ],
      ),
    );
  }
}