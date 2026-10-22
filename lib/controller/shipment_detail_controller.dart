import 'package:get/get.dart';

class ShipmentDetailController extends GetxController {
    var bookingId = "#43975749".obs;
  var statusText = "Container Discharged at Trans-shipment Port".obs;
  var vesselName = "Evergreen Teresa - V.284".obs;
  var containerId = "2325928".obs;
  var referenceNumber = "29547364023752".obs;

    var isExpanded = false.obs;
    void toggleExpansion() {
      isExpanded.value = !isExpanded.value;
    }
    final List<Map<String, dynamic>> timelineData = [
    {"status": "Booked", "date": "18/07/2025", "isCompleted": true},
    {"status": "Container Picked Up", "sub": "Si Submitted", "date": "18/07/2025", "isCompleted": true},
    {"status": "Container Gated In", "date": "18/07/2025", "isCompleted": true},
    {"status": "Container Discharged at Trans-shipment Port", "date": "18/07/2025", "isCompleted": true},
    {"status": "Empty Container Delivered on 12 Sep", "date": "18/07/2025", "isCompleted": false}, // Green color for last status
  ];
}