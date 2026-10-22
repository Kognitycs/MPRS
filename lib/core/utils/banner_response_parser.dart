import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/model/banner_item.dart';

class BannerResponseParser {
  static BannerItem? parseBannerFromResponse(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      final candidates = [
        map['banner'],
        map['data'] is Map ? (map['data'] as Map)['banner'] : null,
        map['data'],
        map['result'] is Map ? (map['result'] as Map)['banner'] : null,
        map['updatedBanner'],
      ];

      for (final candidate in candidates) {
        if (candidate is Map) {
          return BannerItem.fromJson(Map<String, dynamic>.from(candidate));
        }
      }
    } catch (e) {
      debugPrint('BannerResponseParser error: $e');
    }
    return null;
  }
}
