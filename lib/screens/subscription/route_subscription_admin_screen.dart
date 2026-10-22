import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart' show showSnackBar;
import 'package:mprs_android/model/port_model.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/port_service.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';
import 'package:mprs_android/widget/searchable_dropdown.dart';

/// Admin/Internal User Route Subscription Screen
/// This screen is specifically designed for Admin and Internal users
/// with different features compared to External/VIP/VVIP users
class RouteSubscriptionAdminScreen extends StatefulWidget {
  @override
  _RouteSubscriptionAdminScreenState createState() =>
      _RouteSubscriptionAdminScreenState();
}

class _RouteSubscriptionAdminScreenState
    extends State<RouteSubscriptionAdminScreen> {
  // Dropdown selections
  String? selectedOriginSector;
  String? selectedOriginPort;
  String? selectedDestinationSector;
  String? selectedDestinationPort;

  // Port data
  List<PortModel> allPorts = [];
  List<String> sectorNames = [];
  bool isLoading = true;
  bool isSubmittingSubscription = false;
  String? deletingSubscriptionId;

  List<Map<String, String>> subscriptions = [];

  // Filter variables
  String? filterPort;
  String? filterUser;
  List<String> uniquePorts = [];
  List<String> uniqueUsers = [];

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

      print('🔵 Subscription Response Status Code: ${response.statusCode}');
      print('🔵 Subscription Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.data);

        print('🔵 Decoded Response Data:');
        print(jsonEncode(responseData));

        if (responseData['data'] != null) {
          print(
            '🔵 Total Subscriptions: ${(responseData['data'] as List).length}',
          );
          print('🔵 All Subscription Items:');
          for (var i = 0; i < (responseData['data'] as List).length; i++) {
            print('   Subscription $i: ${jsonEncode(responseData['data'][i])}');
          }
        }

        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            subscriptions =
                (responseData['data'] as List)
                    .map(
                      (item) => {
                        "_id": item['_id'].toString(),
                        "origin": item['origin'].toString(),
                        "destination": item['destination'].toString(),
                        "user":
                            item['createdBy']?['firstName'] != null &&
                                    item['createdBy']?['lastName'] != null
                                ? "${item['createdBy']['firstName']} ${item['createdBy']['lastName']}"
                                : item['createdBy']?['email']?.toString() ??
                                    "N/A",
                      },
                    )
                    .toList();

            // Extract unique ports (origins and destinations)
            Set<String> portsSet = {};
            for (var sub in subscriptions) {
              portsSet.add(sub['origin']!);
              portsSet.add(sub['destination']!);
            }
            uniquePorts = portsSet.toList()..sort();

            // Extract unique users
            Set<String> usersSet = {};
            for (var sub in subscriptions) {
              if (sub['user'] != 'N/A') {
                usersSet.add(sub['user']!);
              }
            }
            uniqueUsers = usersSet.toList()..sort();
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
        final responseData = jsonDecode(response.data);

        if (responseData['success'] == true &&
            responseData['routeSubscription'] != null) {
          showSnackBar(
            context,
            responseData['message'] ?? 'Route subscription added successfully!',
            backgroundColor: Colors.green,
          );

          await _fetchSubscriptions();

          setState(() {
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
    if (sectorName == null || sectorName.isEmpty) {
      return allPorts;
    }
    return PortService.getPortsBySector(allPorts, sectorName);
  }

  List<Map<String, String>> getFilteredSubscriptions() {
    List<Map<String, String>> filtered = subscriptions;

    // Filter by port (checks both origin and destination)
    if (filterPort != null && filterPort!.isNotEmpty) {
      filtered =
          filtered.where((sub) {
            return sub['origin'] == filterPort ||
                sub['destination'] == filterPort;
          }).toList();
    }

    // Filter by user
    if (filterUser != null && filterUser!.isNotEmpty) {
      filtered =
          filtered.where((sub) {
            return sub['user'] == filterUser;
          }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final userType = AuthDataHelper.getUserType();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Route Subscription (Admin/Internal)",
        onActionPressed: () {},
      ),
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
                      // rrSubscription List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Active Subscriptions",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.main,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${getFilteredSubscriptions().length}",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Filter Section
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 18,
                                  color: AppColors.main,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Filters",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Spacer(),
                                if (filterPort != null || filterUser != null)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        filterPort = null;
                                        filterUser = null;
                                      });
                                    },
                                    child: Text(
                                      "Clear All",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: buildFilterDropdown(
                                    "Filter by Port",
                                    filterPort,
                                    uniquePorts,
                                    (value) {
                                      setState(() {
                                        filterPort = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: buildFilterDropdown(
                                    "Filter by User",
                                    filterUser,
                                    uniqueUsers,
                                    (value) {
                                      setState(() {
                                        filterUser = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Subscription List Table
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
                            if (getFilteredSubscriptions().isEmpty)
                              Padding(
                                padding: EdgeInsets.all(30),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.route_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      subscriptions.isEmpty
                                          ? "No subscriptions yet"
                                          : "No matching subscriptions",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...getFilteredSubscriptions().asMap().entries.map(
                                (entry) {
                                  int index = entry.key;
                                  var item = entry.value;
                                  return buildRouteRow(
                                    index,
                                    item["_id"]!,
                                    item["origin"]!,
                                    item["destination"]!,
                                    item["user"]!,
                                  );
                                },
                              ).toList(),
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

  Widget buildTableHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "Origin",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Destination",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "User",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
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
    String user,
  ) {
    return Column(
      children: [
        Container(
          color: index % 2 == 0 ? Colors.grey[50] : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.main, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(origin, style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.main, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(destination, style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey[600], size: 16),
                    SizedBox(width: 6),
                    Flexible(child: Text(user, style: TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 0),
      ],
    );
  }

  Widget buildFilterDropdown(
    String hint,
    String? selectedValue,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        filled: true,
        fillColor: AppColors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.main, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      hint: Text(hint, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      icon: Icon(Icons.arrow_drop_down, color: AppColors.main, size: 18),
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 200,
      style: TextStyle(color: Colors.black87, fontSize: 12),
      dropdownColor: Colors.white,
      items:
          items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }
}
