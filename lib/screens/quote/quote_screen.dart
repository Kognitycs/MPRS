import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/booking/booking_detail_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedFilter = 'All';

  final List<Map<String, String>> bookings = List.generate(
    6,
        (index) => {
      'id': '#34765433',
      'from': 'Nhava Sheva',
      'to': 'Ajman',
      'status': 'Complete',
      'statusColor': index.isEven ? 'green' : 'orange',
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,

      appBar: CommonAppBar(title: "Quote"),

      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: SearchBar(controller: _searchController)),
                const SizedBox(width: 8),
                Container(
                  width: 100,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedFilter,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedFilter = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final isGreen = booking['statusColor'] == 'green';

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking['id']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.main,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {

                              },
                              child:  Text(
                                "Show Details",
                                style: TextStyle(
                                  color: AppColors.main,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,   // <-- ADD THIS
                                  decorationColor: AppColors.main,        // optional: match color
                                  decorationThickness: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppColors.yellow,
                                ),
                                const SizedBox(width: 6),
                                Text(booking['from']!),
                              ],
                            ),
                            const Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.black26,
                                indent: 10,
                                endIndent: 10,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.yellow,
                                ),
                                const SizedBox(width: 6),
                                Text(booking['to']!),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 🚢 Status
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color:
                              isGreen ? AppColors.green : AppColors.yellow,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                booking['status']!,
                                style: TextStyle(
                                  color:
                                  isGreen
                                      ? AppColors.green
                                      : AppColors.yellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController? controller;

  const SearchBar({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.grey, size: 22),
          hintText: "Search tracking ID",
          hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
      ),
    );
  }
}
