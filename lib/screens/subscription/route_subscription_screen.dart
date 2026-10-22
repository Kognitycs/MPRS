import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart' show showSnackBar;
import 'package:mprs_android/model/port_model.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/port_service.dart';
import 'package:mprs_android/screens/quote/get_quote_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/widget/searchable_dropdown.dart';

class RouteSubscriptionScreen extends StatefulWidget {
  @override
  _RouteSubscriptionScreenState createState() =>
      _RouteSubscriptionScreenState();
}

class _RouteSubscriptionScreenState extends State<RouteSubscriptionScreen> {
  // Dropdown selections
  String? selectedOriginSector;
  String? selectedOriginPort;
  String? selectedDestinationSector;
  String? selectedDestinationPort;

  // Checkbox selections
  bool isStandardChecked = false;
  bool isHazChecked = false;
  bool isReeferChecked = false;

  // Port data
  List<PortModel> allPorts = [];
  List<String> sectorNames = [];
  bool isLoading = true;
  bool showGetQuoteButton = false;
  bool isSubmittingSubscription = false;
  String? deletingSubscriptionId;

  List<Map<String, String>> subscriptions = [];

  // Sample route data for display
  List<Map<String, dynamic>> routeData = [
    {
      "origin": "Nhava Sheva",
      "destination": "Dammam",
      "price20": "USD 250",
      "container20": "20' FCL",
      "price40": "USD 450",
      "container40": "40'HC FCL",
      "mloCode": "1059",
    },
    {
      "origin": "Panama Canal",
      "destination": "Russia",
      "price20": "USD 300",
      "container20": "20' FCL",
      "price40": "USD 550",
      "container40": "40'HC FCL",
      "mloCode": "2047",
    },
    {
      "origin": "Malacca",
      "destination": "Strait",
      "price20": "USD 180",
      "container20": "20' FCL",
      "price40": "USD 350",
      "container40": "40'HC FCL",
      "mloCode": "3156",
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchPorts();
    _fetchSubscriptions();
  }

  Future<void> _fetchPorts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await PortService.getAllPorts();
      if (response != null && response.data != null) {
        setState(() {
          allPorts = response.data!;
          sectorNames = PortService.getUniqueSectors(allPorts);
          isLoading = false;
        });
        print(
          '✅ Loaded ${allPorts.length} ports with ${sectorNames.length} unique sectors',
        );
      } else {
        setState(() {
          isLoading = false;
        });
        print('❌ Failed to load ports');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('❌ Error loading ports: $e');
    }
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final token = AuthDataHelper.getToken();
      final response = await HttpClientHelper.getWithBearer(
        '${ApiConstants.baseUrl}/user/get/routes/subscription',
        token,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.data);

        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            subscriptions =
                (responseData['data'] as List)
                    .map(
                      (item) => {
                        "_id": item['_id'].toString(),
                        "origin": item['origin'].toString(),
                        "destination": item['destination'].toString(),
                      },
                    )
                    .toList();
          });
          print('✅ Loaded ${subscriptions.length} subscriptions');
        }
      } else {
        print('❌ Failed to load subscriptions: ${response.message}');
      }
    } catch (e) {
      print('❌ Error loading subscriptions: $e');
    }
  }

  Future<void> addSubscription() async {
    if (selectedOriginPort == null ||
        selectedOriginPort!.isEmpty ||
        selectedDestinationPort == null ||
        selectedDestinationPort!.isEmpty) {
      showSnackBar(
        context,
        'Please select both origin and destination ports',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      isSubmittingSubscription = true;
    });

    try {
      final token = AuthDataHelper.getToken();

      final requestBody = jsonEncode({
        'origin': selectedOriginPort,
        'destination': selectedDestinationPort,
      });

      print('🔵 Add Subscription Request:');
      print('URL: ${ApiConstants.baseUrl}/user/create/route/subscription');
      print('Token: $token');
      print('Request Body: $requestBody');

      final response = await HttpClientHelper.postWithBearerNew(
        '${ApiConstants.baseUrl}/user/create/route/subscription',
        token,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the API response
        final responseData = jsonDecode(response.data);

        if (responseData['success'] == true &&
            responseData['routeSubscription'] != null) {
          final routeSubscription = responseData['routeSubscription'];

          showSnackBar(
            context,
            responseData['message'] ?? 'Route subscription added successfully!',
            backgroundColor: Colors.green,
          );

          // Refresh subscriptions list from API
          await _fetchSubscriptions();

          setState(() {
            // Clear selections
            selectedOriginSector = null;
            selectedOriginPort = null;
            selectedDestinationSector = null;
            selectedDestinationPort = null;
          });
        } else {
          showSnackBar(
            context,
            responseData['message'] ?? 'Failed to add subscription',
            backgroundColor: Colors.red,
          );
        }
      } else {
        showSnackBar(
          context,
          response.message ?? 'Failed to add subscription',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      showSnackBar(
        context,
        'Error: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        isSubmittingSubscription = false;
      });
    }
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    setState(() {
      deletingSubscriptionId = subscriptionId;
    });

    try {
      final token = AuthDataHelper.getToken();
      final response = await HttpClientHelper.deleteWithBearer(
        '${ApiConstants.baseUrl}/user/delete/route/subscription/$subscriptionId',
        token,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.data);

        if (responseData['success'] == true) {
          showSnackBar(
            context,
            responseData['message'] ?? 'Subscription deleted successfully',
            backgroundColor: Colors.green,
          );

          // Refresh subscriptions list
          await _fetchSubscriptions();
        } else {
          showSnackBar(
            context,
            responseData['message'] ?? 'Failed to delete subscription',
            backgroundColor: Colors.red,
          );
        }
      } else {
        showSnackBar(
          context,
          response.message ?? 'Failed to delete subscription',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      showSnackBar(
        context,
        'Error: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        deletingSubscriptionId = null;
      });
    }
  }

  List<PortModel> getFilteredPorts(String? sectorName) {
    if (sectorName == null || sectorName.isEmpty || sectorName == 'None') {
      return allPorts;
    }
    // Technical 'sector' field ki jagah 'sectorName' check karein
    return allPorts.where((p) => p.sectorName == sectorName).toList();
  }

  // Get filtered ports based on selected sector
  // List<PortModel> getFilteredPorts(String? sectorName) {
  //   if (sectorName == null || sectorName.isEmpty) {
  //     return allPorts; // Return all ports if no sector selected
  //   }
  //   return PortService.getPortsBySector(allPorts, sectorName);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(title: "Route Subscription", onActionPressed: () {}),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child:
              isLoading
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(50.0),
                      child: CircularProgressIndicator(color: AppColors.main),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔶 Search Route Box
                      Container(
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 218, 218, 218),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  child: buildSectorDropdown(
                                    "Select Sector",
                                    selectedOriginSector,
                                    (value) {
                                      setState(() {
                                        selectedOriginSector = value;
                                        selectedOriginPort =
                                            null; // Clear port selection when sector changes
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: buildPortDropdown(
                                    "Select Port",
                                    selectedOriginPort,
                                    getFilteredPorts(selectedOriginSector),
                                        (value) {

                                    },
                                    true, // Ye batata hai ki ye ORIGIN hai
                                  ),
                                ),                              ],
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
                                  child: buildSectorDropdown(
                                    "Select Sector",
                                    selectedDestinationSector,
                                    (value) {
                                      setState(() {
                                        selectedDestinationSector = value;
                                        selectedDestinationPort =
                                            null; // Clear port selection when sector changes
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: buildPortDropdown(
                                    "Select Port",
                                    selectedDestinationPort,
                                    getFilteredPorts(selectedDestinationSector),
                                        (value) {
                                    },
                                    false,
                                  ),
                                ),                              ],
                            ),

                            SizedBox(height: 20),

                            SizedBox(height: 25),
                            MainButton(
                              text:
                                  isSubmittingSubscription
                                      ? 'Adding...'
                                      : 'Add Subscription',
                              onPressed: () {
                                if (!isSubmittingSubscription) {
                                  addSubscription();
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 25),

                      // 🔽 Subscription List
                      Text(
                        "Subscription Route",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),

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
                                item["_id"]!,
                                item["origin"]!,
                                item["destination"]!,
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      SizedBox(height: 25),
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

  Widget buildSectorDropdown(
    String hint,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return SearchableDropdown(
      hint: hint,
      selectedValue: selectedValue,
      items: sectorNames,
      onChanged: onChanged,
      label: hint,
    );
  }

  Widget buildPortDropdown(
      String hint,
      String? selectedValue,
      List<PortModel> ports,
      ValueChanged<String?> onChanged,
      bool isOrigin, // Ek extra parameter identify karne ke liye
      ) {
    final portNames = ports.map((port) => port.name ?? '').toList();

    return SearchableDropdown(
      hint: hint,
      selectedValue: selectedValue,
      items: portNames,
      onChanged: (val) {
        if (val != null) {
          // 1. Port find karo allPorts list mein se
          try {
            final port = allPorts.firstWhere((p) => p.name == val);

            setState(() {
              // 2. State update karo
              if (isOrigin) {
                selectedOriginPort = val;
                // Agar sector match hota hai hamari list se toh select kar lo
                if (sectorNames.contains(port.sectorName)) {
                  selectedOriginSector = port.sectorName;
                }
              } else {
                selectedDestinationPort = val;
                if (sectorNames.contains(port.sectorName)) {
                  selectedDestinationSector = port.sectorName;
                }
              }
            });
          } catch (e) {
            print("Error finding sector for port: $e");
          }
        }
        onChanged(val);
      },
      label: hint,
    );
  }

/*
  Widget buildPortDropdown(
    String hint,
    String? selectedValue,
    List<PortModel> ports,
    ValueChanged<String?> onChanged,
  ) {
    final portNames = ports.map((port) => port.name ?? '').toList();

    return SearchableDropdown(
      hint: hint,
      selectedValue: selectedValue,
      items: portNames,
      onChanged: onChanged,
      label: hint,
    );
  }
*/

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

  Widget buildRouteRow(
    int index,
    String subscriptionId,
    String origin,
    String destination,
  ) {
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
                child:
                    deletingSubscriptionId == subscriptionId
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.main,
                          ),
                        )
                        : GestureDetector(
                          onTap: () {
                            deleteSubscription(subscriptionId);
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

  Widget buildRouteCard(Map<String, dynamic> route) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFB0C4DE), // Light blue-grey border
          width: 2,
        ),

      ),
      child: Column(
        children: [
          // Origin and Destination Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_boat,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    route["origin"],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(width: 80, height: 2, color: Colors.grey[400]),
              Row(
                children: [
                  Icon(
                    Icons.directions_boat,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    route["destination"],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 15),

          // Pricing Container
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: Color(0xFF3B5998), // Dark blue background
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route["price20"],
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      route["container20"],
                      style: TextStyle(color: AppColors.white, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      route["price40"],
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      route["container40"],
                      style: TextStyle(color: AppColors.white, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 15),

          // MLO Code and Proceed Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MLO Code - ${route["mloCode"]}",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GetQuoteScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B5998), // Dark blue
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "PROCEED",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
