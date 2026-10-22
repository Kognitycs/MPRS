import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/model/port_model.dart';

class PortService {
  // In-memory cache valid for app lifetime. Use `forceRefresh` to bypass.
  static List<PortModel>? _cachedPorts;

  static Future<PortListResponse?> getAllPorts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPorts != null) {
      return PortListResponse(count: _cachedPorts!.length, data: _cachedPorts);
    }
    try {
      final token = await AuthDataHelper.getToken();

      if (token == null || token.isEmpty) {
        print('❌ No auth token found');
        return null;
      }

      final response = await http.get(
        Uri.parse(ApiConstants.allPorts),
        headers: AppConfig.mergeApiHeaders({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      print('📡 Port API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        log(" Port API Response Status====================$jsonData");
        final resp = PortListResponse.fromJson(jsonData);
        // Cache the ports for subsequent use
        _cachedPorts = resp.data ?? [];
        return resp;
      } else {
        print('❌ Failed to fetch ports: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching ports: $e');
      return null;
    }
  }

  /// Clear cached ports (call on logout or when you need fresh data)
  static void clearCache() {
    _cachedPorts = null;
  }

  // Extract unique sector names from ports
  static List<String> getUniqueSectors(List<PortModel>? ports) {
    if (ports == null || ports.isEmpty) {
      return [];
    }

    final Set<String> uniqueSectors = {};
    for (var port in ports) {
      if (port.sectorName != null && port.sectorName!.isNotEmpty) {
        uniqueSectors.add(port.sectorName!);
      }
    }

    final sortedSectors = uniqueSectors.toList()..sort();
    return sortedSectors;
  }

  // Get ports by sector name
  static List<PortModel> getPortsBySector(
    List<PortModel>? ports,
    String? sectorName,
  ) {
    if (ports == null || ports.isEmpty || sectorName == null) {
      return [];
    }

    return ports.where((port) => port.sectorName == sectorName).toList();
  }
}
