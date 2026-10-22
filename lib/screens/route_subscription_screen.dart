import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class RouteSubscriptionScreen extends StatefulWidget {
  @override
  _RouteSubscriptionScreenState createState() =>
      _RouteSubscriptionScreenState();
}

class _RouteSubscriptionScreenState extends State<RouteSubscriptionScreen> {
  final TextEditingController origin1 = TextEditingController();
  final TextEditingController origin2 = TextEditingController();
  final TextEditingController destination1 = TextEditingController();
  final TextEditingController destination2 = TextEditingController();

  List<Map<String, String>> subscriptions = [
    {"origin": "Nhava Sheva", "destination": "Ajman"},
    {"origin": "Panama Canal", "destination": "Russia"},
    {"origin": "Malacca", "destination": "Strait"},
    {"origin": "Sri Lanka", "destination": "Ajman"},
    {"origin": "Nhava Sheva", "destination": "Ajman"},
  ];

  void addSubscription() {
    if (origin1.text.isNotEmpty && destination1.text.isNotEmpty) {
      setState(() {
        subscriptions.add({
          "origin": origin1.text,
          "destination": destination1.text,
        });
      });
      origin1.clear();
      destination1.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(title: "Route Subscription", onActionPressed: () {}),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔶 Search Route Box
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Search Route",
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    /// Origin label
                    Text(
                      "Origin",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                    SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: buildTextField("Indian Ocean", origin1),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: buildTextField("Indian Ocean", origin2),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    /// Destination label
                    Text(
                      "Destination",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                    SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: buildTextField("Nhava Sheva", destination1),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: buildTextField("Gulf", destination2)),
                      ],
                    ),

                    SizedBox(height: 25),
                    MainButton(text: 'Add Subscription', onPressed: () {}),
                  ],
                ),
              ),

              SizedBox(height: 25),

              // 🔽 Subscription List
              Text(
                "Subscription Route",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    buildTableHeader(),
                    Divider(),
                    ...subscriptions.asMap().entries.map((entry) {
                      int index = entry.key;
                      var item = entry.value;
                      return buildRouteRow(
                        index,
                        item["origin"]!,
                        item["destination"]!,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Colors.grey, // 👈 border color
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.main, // 👈 border on focus
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget buildTableHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              "Origin",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              "Destination",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: SizedBox(), // space for delete icon column
          ),
        ],
      ),
    );
  }


  Widget buildRouteRow(int index, String origin, String destination) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.main, size: 18),
                    SizedBox(width: 6),
                    Flexible(child: Text(origin)),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.main, size: 18),
                    SizedBox(width: 6),
                    Flexible(child: Text(destination)),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      subscriptions.removeAt(index);
                    });
                  },
                  child: Icon(Icons.delete, color: AppColors.secondary),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 0),
      ],
    );
  }

}
