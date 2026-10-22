// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:mprs_android/core/auth_data_helper.dart';
// // import 'package:mprs_android/core/constants/api_constants.dart';
// // import 'package:mprs_android/service/http_client_helper.dart';
// // import 'package:mprs_android/service/port_service.dart';
// // import 'package:mprs_android/model/port_model.dart';
// // import 'package:mprs_android/model/pricebook_entry_model.dart';
// // import '../screens/home_screen/pricebook_results_screen.dart';
// // import '../screens/quote/get_quote_screen.dart';
// //
// // class SearchRouteController extends GetxController {
// //   var showGetQuoteButton = false.obs;
// //   var selectedOriginSector = RxnString();
// //   var selectedDestinationSector = RxnString();
// //   var selectedOriginPort = RxnString();
// //   var selectedDestinationPort = RxnString();
// //
// //   var isStandard = true.obs;
// //   var isHaz = false.obs;
// //   var isReefer = false.obs;
// //
// //   var isPortsLoading = false.obs;
// //   var isSearchingPricebook = false.obs;
// //
// //   List<PortModel> allPorts = [];
// //   var sectorNames = <String>[].obs;
// //
// //   @override
// //   void onInit() {
// //     super.onInit();
// //     fetchPorts();
// //   }
// //   void clearSelections() {
// //     selectedOriginSector.value = null;
// //     selectedOriginPort.value = null;
// //     selectedDestinationSector.value = null;
// //     selectedDestinationPort.value = null;
// //
// //     isStandard.value = true;
// //     isHaz.value = false;
// //     isReefer.value = false;
// //
// //     showGetQuoteButton.value = false;
// //   }
// //   Future<void> fetchPorts() async {
// //     isPortsLoading.value = true;
// //     try {
// //       final response = await PortService.getAllPorts();
// //       if (response != null && response.data != null) {
// //         allPorts = response.data!;
// //         sectorNames.value = PortService.getUniqueSectors(allPorts);
// //         print("DEBUG: All unique sectors loaded: $sectorNames");
// //       }
// //     } catch (e) {
// //       debugPrint('Error fetching ports: $e');
// //     } finally {
// //       isPortsLoading.value = false;
// //     }
// //   }
// //
// //   List<String> getFilteredPorts(String? sector) {
// //     if (sector == null || sector.isEmpty || sector == 'None' || sector.contains('[')) {
// //       return allPorts.map((e) => e.name ?? '').toList();
// //     }
// //     return PortService.getPortsBySector(allPorts, sector).map((e) => e.name ?? '').toList();
// //   }
// //
// //   void updateSectorFromPort(String portName, bool isOrigin) {
// //     try {
// //       final port = allPorts.firstWhere((p) => p.name == portName);
// //       String? detectedSector = port.sectorName;
// //
// //       if (detectedSector != null && detectedSector.isNotEmpty) {
// //
// //         if (sectorNames.contains(detectedSector)) {
// //           if (isOrigin) {
// //             selectedOriginSector.value = detectedSector;
// //           } else {
// //             selectedDestinationSector.value = detectedSector;
// //           }
// //           print("SUCCESS: Sector auto-updated to: $detectedSector");
// //         } else {
// //           print("FAILURE: Sector Name '$detectedSector' dropdown list mein nahi mila.");
// //         }
// //       }
// //     } catch (e) {
// //       debugPrint("Error updating sector from port: $e");
// //     }
// //   }
// //   Future<void> searchPricebook() async {
// //     if (selectedOriginPort.value == null || selectedDestinationPort.value == null) {
// //       Get.snackbar("Required", "Please select origin and destination ports",
// //           snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
// //       return;
// //     }
// //     showGetQuoteButton.value = false;
// //
// //
// //     isSearchingPricebook.value = true;
// //     try {
// //       String origin = Uri.encodeComponent(selectedOriginPort.value!);
// //       String destination = Uri.encodeComponent(selectedDestinationPort.value!);
// //
// //       String url = '${ApiConstants.baseUrl}/user/pricebook/for/ports?originPort=$origin&destinationPort=$destination';
// //
// //       List<String> types = [];
// //       if (isStandard.value) types.add('Standard');
// //       if (isHaz.value) types.add('Haz');
// //       if (isReefer.value) types.add('Reefer');
// //       if (types.isNotEmpty) url += '&containerType=${Uri.encodeComponent(types.first)}';
// //
// //       print("===== SEARCH API DEBUG =====");
// //       print("Request URL: $url");
// //
// //       final resp = await HttpClientHelper.getWithBearer(url, AuthDataHelper.getToken());
// //
// //       print("Response Status: ${resp.statusCode}");
// //       print("Response Body: ${resp.data}");
// //
// //       if (resp.statusCode == 200) {
// //         final body = jsonDecode(resp.data);
// //         final entries = body['data'] as List<dynamic>? ?? [];
// //         List<PricebookEntryModel> parsed = entries.map((e) => PricebookEntryModel.fromJson(e)).toList();
// //
// //         if (parsed.isNotEmpty) {
// //           Get.to(() => PricebookResultsScreen(
// //             entries: parsed,
// //             allPorts: allPorts,
// //             sectorNames: sectorNames.toList(),
// //
// //             selectedOriginPort: selectedOriginPort.value,
// //             selectedDestinationPort: selectedDestinationPort.value,
// //             selectedOriginSector: selectedOriginSector.value,
// //             selectedDestinationSector: selectedDestinationSector.value,
// //             containerType: isStandard.value
// //                 ? 'Standard'
// //                 : isHaz.value
// //                 ? 'Haz'
// //                 : 'Reefer',
// //           ));
// //           // Get.to(() => PricebookResultsScreen(
// //           //   entries: parsed,
// //           //   allPorts: allPorts,
// //           //   sectorNames: sectorNames.toList(),
// //           // ));
// //         } else {
// //           showGetQuoteButton.value = true;
// //           Get.snackbar("No Results", "No routes found.");
// //           // _showNoResultsSnackbar();
// //         }
// //       }
// //     } catch (e) {
// //       showGetQuoteButton.value = false;
// //       print("SEARCH ERROR: $e");
// //       Get.snackbar("Error", "Something went wrong");
// //     } finally {
// //       isSearchingPricebook.value = false;
// //     }
// //   }
// //
// //   void _showNoResultsSnackbar() {
// //     Get.snackbar(
// //       "No Results",
// //       "No routes found.",
// //       snackPosition: SnackPosition.BOTTOM,
// //       backgroundColor: Colors.black87,
// //       colorText: Colors.white,
// //       duration: const Duration(seconds: 5),
// //       mainButton: TextButton(
// //         onPressed: () {
// //           Get.to(() => const GetQuoteScreen(), arguments: {
// //             'origin': selectedOriginPort.value,
// //             'destination': selectedDestinationPort.value,
// //             'type': isStandard.value ? 'Standard' : isHaz.value ? 'Haz' : 'Reefer',
// //           });
// //         },
// //         child: const Text("Generate a Quote", style: TextStyle(color: AppColors.main)),
// //       ),
// //     );
// //   }
// // }
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:mprs_android/core/auth_data_helper.dart';
// import 'package:mprs_android/core/constants/api_constants.dart';
// import 'package:mprs_android/model/api_response.dart';
// import 'package:mprs_android/service/http_client_helper.dart';
// import 'package:mprs_android/service/port_service.dart';
// import 'package:mprs_android/model/port_model.dart';
// import 'package:mprs_android/model/pricebook_entry_model.dart';
// import '../screens/home_screen/pricebook_results_screen.dart';
// import '../screens/quote/get_quote_screen.dart';
//
// class SearchRouteController extends GetxController {
//   var showGetQuoteButton = false.obs;
//   var selectedOriginSector = RxnString();
//   var selectedDestinationSector = RxnString();
//   var selectedOriginPort = RxnString();
//   var selectedDestinationPort = RxnString();
//
//   var isStandard = true.obs;
//   var isHaz = false.obs;
//   var isReefer = false.obs;
//
//   var isPortsLoading = false.obs;
//   var isSearchingPricebook = false.obs;
//
//   List<PortModel> allPorts = [];
//   var sectorNames = <String>[].obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     fetchPorts();
//   }
//   void clearSelections() {
//     selectedOriginSector.value = null;
//     selectedOriginPort.value = null;
//     selectedDestinationSector.value = null;
//     selectedDestinationPort.value = null;
//
//     isStandard.value = true;
//     isHaz.value = false;
//     isReefer.value = false;
//
//     showGetQuoteButton.value = false;
//   }
//   Future<void> fetchPorts() async {
//     isPortsLoading.value = true;
//     try {
//       final response = await PortService.getAllPorts();
//       if (response != null && response.data != null) {
//         allPorts = response.data!;
//         sectorNames.value = PortService.getUniqueSectors(allPorts);
//         print("DEBUG: All unique sectors loaded: $sectorNames");
//       }
//     } catch (e) {
//       debugPrint('Error fetching ports: $e');
//     } finally {
//       isPortsLoading.value = false;
//     }
//   }
//
//   List<String> getFilteredPorts(String? sector) {
//     if (sector == null || sector.isEmpty || sector == 'None' || sector.contains('[')) {
//       return allPorts.map((e) => e.name ?? '').toList();
//     }
//     return PortService.getPortsBySector(allPorts, sector).map((e) => e.name ?? '').toList();
//   }
//   RxnString validFromDate = RxnString();
//   RxString selectedMode = "Ocean Freight".obs;
//
//   TextEditingController quantityCtrl = TextEditingController();
//   TextEditingController weightCtrl = TextEditingController();
//   TextEditingController packagesCtrl = TextEditingController();
//   TextEditingController commodityCtrl = TextEditingController();
//
//   Future<ApiResponse> createOpportunityApi() async {
//     final origin = allPorts.firstWhere((p) => p.name == selectedOriginPort.value);
//     final dest = allPorts.firstWhere((p) => p.name == selectedDestinationPort.value);
//
//     final body = {
//       "startLocation": origin.portId,
//       "endLocation": dest.portId,
//       "validFrom": validFromDate.value,
//
//       "containerType": isStandard.value
//           ? "Standard(Dry Container)"
//           : isHaz.value
//           ? "Haz"
//           : "Open Top",
//
//       "containerQuantity": quantityCtrl.text,
//       "weightPerContainer": weightCtrl.text,
//       "commodity": commodityCtrl.text,
//
//       "opp_from_rms_app": true,
//       "mode_of_shipment": selectedMode.value,
//       "number_of_packages": packagesCtrl.text,
//
//       "AccountId": AuthDataHelper.getAccountId()
//     };
//
//     print("🔥 OPPORTUNITY BODY: ${jsonEncode(body)}");
//
//     return await HttpClientHelper.postWithBearer(
//       "${ApiConstants.baseUrl}/user/create/opportunity",
//       AuthDataHelper.getToken(),
//       body: jsonEncode(body),
//       headers: {'Content-Type': 'application/json'},
//     );
//   }
//
//
//   void updateSectorFromPort(String portName, bool isOrigin) {
//     try {
//       final port = allPorts.firstWhere((p) => p.name == portName);
//       String? detectedSector = port.sectorName;
//
//       if (detectedSector != null && detectedSector.isNotEmpty) {
//
//         if (sectorNames.contains(detectedSector)) {
//           if (isOrigin) {
//             selectedOriginSector.value = detectedSector;
//           } else {
//             selectedDestinationSector.value = detectedSector;
//           }
//           print("SUCCESS: Sector auto-updated to: $detectedSector");
//         } else {
//           print("FAILURE: Sector Name '$detectedSector' dropdown list mein nahi mila.");
//         }
//       }
//     } catch (e) {
//       debugPrint("Error updating sector from port: $e");
//     }
//   }
//   Future<void> searchPricebook() async {
//     if (selectedOriginPort.value == null || selectedDestinationPort.value == null) {
//       Get.snackbar("Required", "Please select origin and destination ports",
//           snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
//       return;
//     }
//     showGetQuoteButton.value = false;
//
//
//     isSearchingPricebook.value = true;
//     try {
//       String origin = Uri.encodeComponent(selectedOriginPort.value!);
//       String destination = Uri.encodeComponent(selectedDestinationPort.value!);
//
//       String url = '${ApiConstants.baseUrl}/user/pricebook/for/ports?originPort=$origin&destinationPort=$destination';
//
//       List<String> types = [];
//       if (isStandard.value) types.add('Standard');
//       if (isHaz.value) types.add('Haz');
//       if (isReefer.value) types.add('Reefer');
//       if (types.isNotEmpty) url += '&containerType=${Uri.encodeComponent(types.first)}';
//
//       print("===== SEARCH API DEBUG =====");
//       print("Request URL: $url");
//
//       final resp = await HttpClientHelper.getWithBearer(url, AuthDataHelper.getToken());
//
//       print("Response Status: ${resp.statusCode}");
//       print("Response Body: ${resp.data}");
//
//       if (resp.statusCode == 200) {
//         final body = jsonDecode(resp.data);
//         final entries = body['data'] as List<dynamic>? ?? [];
//         List<PricebookEntryModel> parsed = entries.map((e) => PricebookEntryModel.fromJson(e)).toList();
//
//         if (parsed.isNotEmpty) {
//           Get.to(() => PricebookResultsScreen(
//             entries: parsed,
//             allPorts: allPorts,
//             sectorNames: sectorNames.toList(),
//           ));
//         } else {
//           showGetQuoteButton.value = true;
//           Get.snackbar("No Results", "No routes found.");
//           // _showNoResultsSnackbar();
//         }
//       }
//     } catch (e) {
//       showGetQuoteButton.value = false;
//       print("SEARCH ERROR: $e");
//       Get.snackbar("Error", "Something went wrong");
//     } finally {
//       isSearchingPricebook.value = false;
//     }
//   }
//
//   void _showNoResultsSnackbar() {
//     Get.snackbar(
//       "No Results",
//       "No routes found.",
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: Colors.black87,
//       colorText: Colors.white,
//       duration: const Duration(seconds: 5),
//       mainButton: TextButton(
//         onPressed: () {
//           Get.to(() => const GetQuoteScreen(), arguments: {
//             'origin': selectedOriginPort.value,
//             'destination': selectedDestinationPort.value,
//             'type': isStandard.value ? 'Standard' : isHaz.value ? 'Haz' : 'Reefer',
//           });
//         },
//         child: const Text("Generate a Quote", style: TextStyle(color: AppColors.main)),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/port_service.dart';
import 'package:mprs_android/model/port_model.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart';
import '../screens/home_screen/no_rates_available_screen.dart';
import '../screens/home_screen/pricebook_results_screen.dart';
import '../screens/main_screen.dart';
import '../service/most_used_ports_service.dart';

class SearchRouteController extends GetxController {
  /// Navigator that opened Search Rates (home tab, root from Shipments, etc.).
  NavigatorState? _flowNavigator;

  void bindFlowNavigator(NavigatorState navigator) {
    _flowNavigator = navigator;
  }

  void clearFlowNavigator() {
    _flowNavigator = null;
  }

  NavigatorState? get _activeNavigator =>
      _flowNavigator ??
      Get.key.currentState ??
      MainScreen.homeTabNavigatorKey.currentState;

  Future<T?>? pushInSearchFlow<T>(Route<T> route) {
    return _activeNavigator?.push(route);
  }

  // UI STATE
  var showGetQuoteButton = false.obs;
  var isPortsLoading = false.obs;
  var isSearchingPricebook = false.obs;
  List<PricebookEntryModel> lastSearchEntries = [];
  List<PricebookEntryModel> lastSearchAllRecords = [];
  // SELECTIONS
  var selectedOriginSector = RxnString();
  var selectedDestinationSector = RxnString();
  Rxn<PortModel> selectedOriginPort = Rxn<PortModel>();
  Rxn<PortModel> selectedDestinationPort = Rxn<PortModel>();

  // CONTAINER TYPES
  var isStandard = true.obs;
  var isHaz = false.obs;
  var isReefer = false.obs;

  // EXTRA FIELDS (NEW)
  RxnString validFromDate = RxnString();
  RxString selectedMode = "Ocean".obs;

  /// UI is fixed to Ocean; create-opportunity API expects freight labels.
  static String modeOfShipmentForApi(String? uiMode) {
    final mode = (uiMode ?? 'Ocean').trim().toLowerCase();
    if (mode == 'air' ||
        mode == 'air freight' ||
        mode.contains('air freight')) {
      return 'Air Freight';
    }
    return 'Ocean Freight';
  }

  /// Set when create-opportunity succeeds during pricebook search.
  String? lastOpportunityId;
  String? lastValidTill;

  static String? parseOpportunityIdFromBody(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);

    String? read(Map<String, dynamic> source) {
      for (final key in [
        'opportunityId',
        'OpportunityId',
        'opportunity_id',
        'Id',
        'id',
      ]) {
        final value = source[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return null;
    }

    final direct = read(map);
    if (direct != null) return direct;

    final data = map['data'];
    if (data is Map) {
      final fromData = read(Map<String, dynamic>.from(data));
      if (fromData != null) return fromData;
    }

    final opportunity = map['opportunity'];
    if (opportunity is Map) {
      final fromOpp = read(Map<String, dynamic>.from(opportunity));
      if (fromOpp != null) return fromOpp;
    }

    return null;
  }

  static String? parseValidTillFromBody(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);

    String? read(Map<String, dynamic> source) {
      for (final key in [
        'valid_till_c',
        'Valid_Till__c',
        'validTillC',
        'validTill',
        'valid_till',
        'validTo',
        'valid_to',
      ]) {
        final value = source[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return _formatDateValue(value);
        }
      }
      return null;
    }

    final direct = read(map);
    if (direct != null) return direct;

    final data = map['data'];
    if (data is Map) {
      final fromData = read(Map<String, dynamic>.from(data));
      if (fromData != null) return fromData;
    }

    final opportunity = map['opportunity'];
    if (opportunity is Map) {
      final fromOpp = read(Map<String, dynamic>.from(opportunity));
      if (fromOpp != null) return fromOpp;
    }

    return null;
  }

  static String _formatDateValue(dynamic raw) {
    final text = raw.toString().trim();
    if (text.isEmpty) return text;
    try {
      final dt = DateTime.parse(text.split('T').first);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return text;
    }
  }

  TextEditingController quantityCtrl = TextEditingController();
  TextEditingController weightCtrl = TextEditingController();
  TextEditingController packagesCtrl = TextEditingController();
  TextEditingController commodityCtrl = TextEditingController();
  RxString commodityDisplay = ''.obs;
  TextEditingController cargoValueCtrl = TextEditingController();

  var quantityError = RxnString();
  var weightError = RxnString();
  var commodityError = RxnString();

  // DATA
  List<PortModel> allPorts = [];
  var sectorNames = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchPorts();

    // Optional: default date
    validFromDate.value = DateTime.now().toString().split(' ')[0];
  }

  // ─────────────────────────────────────────────
  void clearSelections() {
    selectedOriginSector.value = null;
    selectedOriginPort.value = null;
    selectedDestinationSector.value = null;
    selectedDestinationPort.value = null;
    isStandard.value = true;
    isHaz.value = false;
    isReefer.value = false;
    validFromDate.value = null;
    selectedMode.value = "Ocean";

    quantityCtrl.clear();
    weightCtrl.clear();
    packagesCtrl.clear();
    commodityCtrl.clear();
    commodityDisplay.value = '';
    cargoValueCtrl.clear();
    quantityError.value = null;
    weightError.value = null;
    commodityError.value = null;

    showGetQuoteButton.value = false;
    lastSearchEntries = [];
    lastSearchAllRecords = [];
  }

  bool _validateMandatoryFields() {
    quantityError.value = null;
    weightError.value = null;
    commodityError.value = null;

    final quantityText = quantityCtrl.text.trim();
    if (quantityText.isEmpty) {
      quantityError.value = 'Please enter number of containers';
    } else {
      final quantity = int.tryParse(quantityText);
      if (quantity == null || quantity <= 0) {
        quantityError.value = 'Please enter a valid number of containers';
      }
    }

    final weightText = weightCtrl.text.trim();
    if (weightText.isEmpty) {
      weightError.value = 'Please enter weight per container';
    } else {
      final weight = double.tryParse(weightText);
      if (weight == null || weight <= 0) {
        weightError.value = 'Please enter a valid weight';
      }
    }

    if (commodityCtrl.text.trim().isEmpty) {
      commodityError.value = 'Please select a commodity';
    }

    return quantityError.value == null &&
        weightError.value == null &&
        commodityError.value == null;
  }

  // ─────────────────────────────────────────────
  Future<void> fetchPorts() async {
    isPortsLoading.value = true;
    try {
      final response = await PortService.getAllPorts();
      if (response?.data != null) {
        allPorts = response!.data!;
        sectorNames.value = PortService.getUniqueSectors(allPorts);
      }
    } catch (e) {
      debugPrint('Error fetching ports: $e');
    } finally {
      isPortsLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  List<String> getFilteredPorts(String? sector) {
    if (sector == null || sector == 'None') {
      return allPorts.map((e) => e.name ?? '').toList();
    }
    return PortService.getPortsBySector(
      allPorts,
      sector,
    ).map((e) => e.name ?? '').toList();
  }

  // ─────────────────────────────────────────────
  /// Fills the first search step with a route from Most search rates.
  Future<void> prefillRoute({
    required String originName,
    required String destinationName,
  }) async {
    if (allPorts.isEmpty) {
      await fetchPorts();
    }
    final origin = _getPortByName(originName);
    final destination = _getPortByName(destinationName);
    selectedOriginPort.value = origin ?? PortModel(name: originName);
    selectedDestinationPort.value =
        destination ?? PortModel(name: destinationName);
    selectedOriginSector.value = origin?.sectorName;
    selectedDestinationSector.value = destination?.sectorName;
    final now = DateTime.now();
    validFromDate.value =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  PortModel? _getPortByName(String? name) {
    if (name == null) return null;

    try {
      return allPorts.firstWhere(
        (p) => p.name?.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  void updateSectorFromPort(String portName, bool isOrigin) {
    try {
      final port = _getPortByName(portName);
      if (isOrigin) {
        selectedOriginSector.value = port?.sectorName;
      } else {
        selectedDestinationSector.value = port?.sectorName;
      }
    } catch (e) {
      debugPrint("Error updating sector: $e");
    }
  }

  // ─────────────────────────────────────────────
  String get containerType {
    if (isHaz.value) return "Haz";
    if (isReefer.value) return "Open Top";
    return "Standard(Dry Container)";
  }

  // ─────────────────────────────────────────────
  Future<ApiResponse> createOpportunityApi() async {
    final origin = selectedOriginPort.value;
    final dest = selectedDestinationPort.value;

    if (origin?.portId == null || dest?.portId == null) {
      Get.snackbar("Error", "Invalid port selection");
      throw Exception("Invalid port mapping");
    }

    final userid = AuthDataHelper.getAccountId();

    /// GET STORED VALUES
    final companyName = AuthDataHelper.getCompanyName();
    final activeRmsUser = AuthDataHelper.getActiveRmsUser();

    final body = {
      "Name": companyName,

      "startLocation": origin!.portId,
      "endLocation": dest!.portId,

      "validFrom": validFromDate.value,

      "containerType": containerType,

      "containerQuantity": quantityCtrl.text.trim(),

      "weightPerContainer": weightCtrl.text.trim(),

      "commodity": commodityCtrl.text,

      "opp_from_rms_app": activeRmsUser,

      "mode_of_shipment": modeOfShipmentForApi(selectedMode.value),

      "number_of_packages": packagesCtrl.text.isEmpty ? "1" : packagesCtrl.text,

      "AccountId": userid,
    };

    print("🔥 FINAL BODY: ${jsonEncode(body)}");

    final response = await HttpClientHelper.postWithBearer(
      "${ApiConstants.baseUrl}/user/create/opportunity",
      AuthDataHelper.getToken(),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

    print("✅ STATUS CODE: ${response.statusCode}");
    print("✅ RESPONSE: ${response.data}");

    return response;
  }

  static const String _defaultCaseFromRmsContainerSize = "20'";

  Future<void> createCaseFromRmsApi({
    String? opportunityId,
    String? containerSize,
  }) async {
    try {
      final origin = selectedOriginPort.value;
      final dest = selectedDestinationPort.value;
      final commodity = commodityCtrl.text.trim();
      final resolvedContainerSize =
          (containerSize != null && containerSize.trim().isNotEmpty)
              ? containerSize.trim()
              : _defaultCaseFromRmsContainerSize;

      final body = <String, dynamic>{
        if (opportunityId != null && opportunityId.trim().isNotEmpty)
          'opportunityId': opportunityId.trim(),
        'containerType': containerType,
        'containerSize': resolvedContainerSize,
        'commodity': commodity.isEmpty ? 'General Cargo' : commodity,
        if (origin?.portId != null) 'originPortId': origin!.portId,
        if (dest?.portId != null) 'destinationPortId': dest!.portId,
      };

      debugPrint('📋 caseFromRMS payload: ${jsonEncode(body)}');

      final response = await HttpClientHelper.postWithBearer(
        ApiConstants.createCaseFromRms,
        AuthDataHelper.getToken(),
        body: jsonEncode(body),
        headers: const {'Content-Type': 'application/json'},
      );

      debugPrint('📋 caseFromRMS status: ${response.statusCode}');
      debugPrint('📋 caseFromRMS response: ${response.data}');
    } catch (e) {
      debugPrint('⚠️ caseFromRMS error: $e');
    }
  }

  // ─────────────────────────────────────────────
  Future<bool> searchPricebook({
    String? mloCode,
    String? containerSize,
    bool presentResults = true,
  }) async {
    // VALIDATION
    if (selectedOriginPort.value == null ||
        selectedDestinationPort.value == null) {
      Get.snackbar("Required", "Please select origin & destination");
      return false;
    }

    if (validFromDate.value == null) {
      Get.snackbar("Error", "Please select date");
      return false;
    }

    if (!_validateMandatoryFields()) {
      return false;
    }

    isSearchingPricebook.value = true;

    try {
      String origin = Uri.encodeComponent(selectedOriginPort.value!.name ?? "");
      String destination = Uri.encodeComponent(
        selectedDestinationPort.value!.name ?? "",
      );

      String url =
          '${ApiConstants.baseUrl}/'
          'user/pricebook/for/ports'
          '?originPort=$origin'
          '&destinationPort=$destination';

      /// SECOND CALL
      if (mloCode != null && mloCode.isNotEmpty) {
        url += '&mloCode=$mloCode';
      }

      /// THIRD CALL
      if (containerSize != null && containerSize.isNotEmpty) {
        url += '&containerSize=${Uri.encodeComponent(containerSize)}';
      }
      List<String> types = [];
      if (isStandard.value) types.add('Standard(Dry Container)');
      if (isHaz.value) types.add('Haz');
      if (isReefer.value) types.add('Reefer');

      if (types.isNotEmpty) {
        url += '&containerType=${Uri.encodeComponent(types.first)}';
      }
      // url+='&containerType=Standard(Dry Container)';

      print("🌐 URL: $url");

      // 🔥 PARALLEL API CALLS
      final results = await Future.wait([
        HttpClientHelper.getWithBearer(url, AuthDataHelper.getToken()),
        createOpportunityApi(),
      ]);

      final pricebookResp = results[0] as ApiResponse;
      final oppResp = results[1] as ApiResponse;

      print("📦 Pricebook: ${pricebookResp.data}");
      print("📦 Opportunity: ${oppResp.data}");

      // Extract opportunityId + valid till from create-opportunity response
      String? opportunityId;
      String? validTill;
      if (oppResp.statusCode == 200 || oppResp.statusCode == 201) {
        final oppBody = jsonDecode(oppResp.data);
        if (oppBody is Map && oppBody['success'] == true) {
          opportunityId = SearchRouteController.parseOpportunityIdFromBody(
            oppBody,
          );
          validTill = SearchRouteController.parseValidTillFromBody(oppBody);
          lastOpportunityId = opportunityId;
          lastValidTill = validTill;
          print("✅ Opportunity ID: $opportunityId");
          print("✅ Valid Till: $validTill");
        } else {
          print(
            "⚠️ Opportunity creation failed: ${oppBody is Map ? oppBody['message'] : oppBody}",
          );
        }
      } else {
        print("⚠️ Opportunity API error: ${oppResp.statusCode}");
      }

      if (pricebookResp.statusCode == 200) {
        final body = jsonDecode(pricebookResp.data);
        // /user/getData returns "records"; /user/pricebook/for/ports returns "data"
        final entries =
            body['records'] as List<dynamic>? ??
            body['data'] as List<dynamic>? ??
            [];

        final List<PricebookEntryModel> parsed =
            entries.map((e) => PricebookEntryModel.fromJson(e)).toList();

        // Deduplicate: if two records share the same mloCode + containerSize,
        // keep the one whose Name is "OCEAN FREIGHT"; otherwise keep the first seen.
        final Map<String, PricebookEntryModel> seen = {};
        for (final e in parsed) {
          final key = '${e.mloCode}_${e.containerSize}';
          if (!seen.containsKey(key)) {
            seen[key] = e;
          } else if (e.productName.toUpperCase() == 'OCEAN FREIGHT') {
            // Replace the existing entry only when this one is the OCEAN FREIGHT record
            seen[key] = e;
          }
        }
        final List<PricebookEntryModel> deduped =
            seen.values.toList()
              ..sort((a, b) => a.mloCode.compareTo(b.mloCode));

        debugPrint('📦 Raw: ${parsed.length}  After dedup: ${deduped.length}');

        if (deduped.isNotEmpty) {
          lastSearchEntries = deduped;
          lastSearchAllRecords = parsed;
          await MostUsedPortsService.recordPortUsage(
            portOfLoading: selectedOriginPort.value?.name,
            portOfDischarge: selectedDestinationPort.value?.name,
          );
          if (presentResults) {
            pushInSearchFlow(
              MaterialPageRoute(
                builder:
                    (_) => PricebookResultsScreen(
                      entries: deduped,
                      allRecords: parsed,
                      allPorts: allPorts,
                      sectorNames: sectorNames.toList(),
                      initialOriginSector: selectedOriginSector.value,
                      initialOriginPort: selectedOriginPort.value?.name,
                      initialDestinationSector: selectedDestinationSector.value,
                      initialDestinationPort:
                          selectedDestinationPort.value?.name,
                      opportunityId: opportunityId,
                      validTill: validTill,
                      initialShipmentMode: selectedMode.value,
                      initialContainerType:
                          isStandard.value
                              ? "Standard(Dry Container)"
                              : isHaz.value
                              ? "Haz"
                              : "Open Top",
                      initialContainerQuantity: quantityCtrl.text.trim(),
                      weightPerContainer: weightCtrl.text.trim(),
                      cargoValue: cargoValueCtrl.text.trim(),
                      commodity: commodityCtrl.text,
                      validFrom: validFromDate.value,
                    ),
              ),
            );
          }
          return true;
        } else {
          lastSearchEntries = [];
          lastSearchAllRecords = [];
          await createCaseFromRmsApi(opportunityId: opportunityId);
          pushInSearchFlow(
            MaterialPageRoute(
              builder:
                  (_) => NoRatesAvailableScreen(
                    originPort: selectedOriginPort.value?.name,
                    destinationPort: selectedDestinationPort.value?.name,
                  ),
            ),
          );
          return false;
        }
      } else {
        final errorBody = jsonDecode(pricebookResp.data);
        Get.snackbar(
          "Error",
          errorBody['message'] ?? "Failed to fetch pricebook",
        );
        return false;
      }
    } catch (e) {
      print("❌ ERROR: $e");
      Get.snackbar("Error", "Something went wrong");
      return false;
    } finally {
      isSearchingPricebook.value = false;
    }
  }
}
