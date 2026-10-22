
import 'package:flutter/material.dart';
import 'package:mprs_android/widget/common_appbar.dart';

import '../../core/constants/app_colors.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {

  final List<TrackingStep> trackingSteps = [
    TrackingStep(
      title: "Booked",
      date: "18/07/2025",
      color: AppColors.main,
    ),
    TrackingStep(
      title: "Container Picked Up SI Submitted",
      date: "18/07/2025",
      color: AppColors.main,
    ),
    TrackingStep(
      title: "Container Gated In",
      date: "18/07/2025",
      color: AppColors.main,
    ),
    TrackingStep(
      title: "Container Loaded On Board",
      date: "18/07/2025",
      color: AppColors.main,
    ),
    TrackingStep(
      title: "Vessel Sailed",
      date: "18/07/2025",
      color: AppColors.main,
    ),
    TrackingStep(
      title: "Container Discharged at Trans-shipment Port",
      date: "18/07/2025",
      color: Colors.green,
    ),
    TrackingStep(
      title: "Container Loaded from Trans-shipment port",
      date: "18/07/2025",
      color: Colors.grey,
    ),
    TrackingStep(
      title: "Container Discharged at Destination",
      date: "18/07/2025",
      color: Colors.grey,
    ),
    TrackingStep(
      title: "Cargo Cleared at Consignee",
      date: "18/07/2025",
      color: Colors.grey,
    ),
    TrackingStep(
      title: "Empty Container Returned",
      date: "18/07/2025",
      color: Colors.grey,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Notification",
        onActionPressed: () {},
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              "Shipment Booked",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              "Your shipment [#12345] has been successfully booked! We’ll notify "
                  "you once it's picked up. Track your shipment anytime in the app.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 25),

            // Tracking History Title
            const Text(
              "Tracking History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Timeline list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trackingSteps.length,
              itemBuilder: (context, index) {
                return TimelineTile(
                  isLast: index == trackingSteps.length - 1,
                  step: trackingSteps[index],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineTile extends StatelessWidget {
  final bool isLast;
  final TrackingStep step;

  const TimelineTile({
    super.key,
    required this.isLast,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Timeline
        Column(
          children: [
            // Dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: step.color,
                shape: BoxShape.circle,
              ),
            ),

            // Line (if not last)
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey.shade400,
              ),
          ],
        ),

        const SizedBox(width: 12),

        // Right Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: step.color == Colors.grey
                        ? Colors.grey.shade600
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class TrackingStep {
  final String title;
  final String date;
  final Color color;

  TrackingStep({
    required this.title,
    required this.date,
    required this.color,
  });
}
