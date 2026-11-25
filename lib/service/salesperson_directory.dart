import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/core/utils/country_utils.dart';
import 'package:mprs_android/service/http_client_helper.dart';

class SalespersonOption {
  final String id;
  final String name;
  final String? state;
  final String? profileName;

  const SalespersonOption({
    required this.id,
    required this.name,
    this.state,
    this.profileName,
  });
}

/// GET /auth/salespersons?state=… (public; used at signup and admin add user).
class SalespersonDirectory {
  static Future<List<SalespersonOption>> loadByState(String state) async {
    final trimmed = state.trim();
    if (trimmed.isEmpty) return const [];

    final url = ApiConstants.salespersonsByState(trimmed);
    debugPrint('SalespersonDirectory: GET $url');

    try {
      final response = await HttpClientHelper.get(url);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'SalespersonDirectory: HTTP ${response.statusCode} '
          '${parseApiErrorMessage(response.data, fallback: response.message ?? '')}',
        );
        return const [];
      }

      final body = _decodeJson(response.data);
      if (body == null) return const [];

      final rows = _rowsOf(body);
      final out = <SalespersonOption>[];
      final seen = <String>{};

      for (final row in rows) {
        final option = _parseRow(row);
        if (option == null) continue;
        if (seen.add(option.id)) out.add(option);
      }

      out.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      debugPrint('SalespersonDirectory: loaded ${out.length} for $trimmed');
      return out;
    } catch (e, st) {
      debugPrint('SalespersonDirectory: $e\n$st');
      return const [];
    }
  }

  static dynamic _decodeJson(dynamic raw) {
    if (raw is Map || raw is List) return raw;
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _rowsOf(dynamic body) {
    if (body is List) return body;
    if (body is! Map) return const [];

    final map = Map<String, dynamic>.from(body);
    for (final key in ['data', 'records', 'salespersons', 'items', 'result']) {
      final value = map[key];
      if (value is List) return value;
    }
    return const [];
  }

  static SalespersonOption? _parseRow(dynamic row) {
    if (row is! Map) return null;
    final map = Map<String, dynamic>.from(row);

    final id = _firstNonEmpty(map, const ['id', 'Id', 'userId', 'salespersonId']);
    final name = _firstNonEmpty(map, const [
      'name',
      'Name',
      'fullName',
      'displayName',
    ]);

    if (id == null || name == null) return null;

    return SalespersonOption(
      id: id,
      name: name,
      state: _firstNonEmpty(map, const ['state', 'State']),
      profileName: _firstNonEmpty(map, const ['profileName', 'ProfileName']),
    );
  }

  static String? _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Name for a salesperson id, searching state lists when profile has no name.
  static Future<String?> findNameById(String salespersonId) async {
    final match = await _findInStateLists(salespersonId: salespersonId);
    final name = match?.option.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  /// When profile has no state, locate the salesperson in state-wise lists.
  static Future<String?> findIndianStateForSalesperson({
    String? salespersonId,
    String? salespersonName,
  }) async {
    final match = await _findInStateLists(
      salespersonId: salespersonId,
      salespersonName: salespersonName,
    );
    return match?.stateName;
  }

  static Future<({SalespersonOption option, String stateName})?>
  _findInStateLists({String? salespersonId, String? salespersonName}) async {
    final id = salespersonId?.trim() ?? '';
    final name = salespersonName?.trim().toLowerCase() ?? '';
    if (id.isEmpty && name.isEmpty) return null;

    final states = CountryUtils.getIndianStates();
    const batchSize = 6;
    for (var i = 0; i < states.length; i += batchSize) {
      final batch = states.skip(i).take(batchSize).toList();
      final results = await Future.wait(batch.map(loadByState));
      for (var j = 0; j < batch.length; j++) {
        final stateName = batch[j];
        for (final row in results[j]) {
          if (id.isNotEmpty && row.id == id) {
            return (option: row, stateName: stateName);
          }
          if (name.isNotEmpty && row.name.toLowerCase() == name) {
            return (option: row, stateName: stateName);
          }
        }
      }
    }
    return null;
  }
}