import 'dart:convert';

import '../constants/app_strings.dart';

/// Single user-facing message for any service/API failure (never show raw errors).
String userFacingErrorMessage([Object? technical]) {
  return AppStrings.serviceNotFound;
}

/// Extracts a user-facing message from API JSON error bodies.
String parseApiErrorMessage(
  dynamic body, {
  String? fallback,
  bool allowSignupDetail = true,
}) {
  try {
    final Map<String, dynamic>? decoded = switch (body) {
      final String s when s.trim().isNotEmpty =>
        jsonDecode(s) as Map<String, dynamic>?,
      final Map<String, dynamic> m => m,
      _ => null,
    };

    if (decoded != null) {
      final rawMessage = decoded['message']?.toString().trim();
      if (allowSignupDetail &&
          rawMessage != null &&
          rawMessage.toLowerCase().contains('signup failed')) {
        return _signupFailureMessage(decoded, rawMessage);
      }

      final detailText = _firstDetailMessage(decoded);
      if (detailText != null && detailText.isNotEmpty) {
        return _cleanQuotes(detailText);
      }

      if (rawMessage != null && rawMessage.isNotEmpty) {
        return _cleanQuotes(rawMessage);
      }
    }

    return fallback ?? AppStrings.serviceNotFound;
  } catch (_) {
    return fallback ?? AppStrings.serviceNotFound;
  }
}

String? _firstDetailMessage(Map<String, dynamic> decoded) {
  final details = decoded['details'];
  if (details is Map) {
    final map = Map<String, dynamic>.from(details);
    for (final key in ['message', 'error', 'errorMessage']) {
      final t = map[key]?.toString().trim();
      if (t != null && t.isNotEmpty) return t;
    }
    final composite = map['compositeResponse'];
    if (composite is List) {
      for (final item in composite) {
        if (item is! Map) continue;
        final body = item['body'];
        if (body is List) {
          for (final entry in body) {
            if (entry is Map) {
              final msg = entry['message']?.toString().trim();
              if (msg != null && msg.isNotEmpty) return msg;
            }
          }
        }
      }
    }
  }
  final statusText = decoded['statusText']?.toString().trim();
  if (statusText != null && statusText.isNotEmpty) return statusText;
  return null;
}

String _signupFailureMessage(Map<String, dynamic> decoded, String rawMessage) {
  final details = decoded['details'];
  if (details is Map<String, dynamic>) {
    final composite = details['compositeResponse'];
    if (composite is List) {
      for (final item in composite) {
        if (item is! Map) continue;
        final body = item['body'];
        if (body is! List) continue;
        for (final entry in body) {
          if (entry is! Map) continue;
          final duplicate = entry['duplicateResult'];
          if (duplicate is Map) {
            final msg = duplicate['errorMessage']?.toString().trim();
            if (msg != null && msg.isNotEmpty) {
              return _cleanQuotes(msg);
            }
          }
          final msg = entry['message']?.toString().trim();
          if (msg != null &&
              msg.isNotEmpty &&
              entry['errorCode']?.toString() == 'DUPLICATES_DETECTED') {
            return _cleanQuotes(msg);
          }
        }
      }
    }
  }

  final statusText = decoded['statusText']?.toString().trim();
  if (statusText != null && statusText.isNotEmpty) {
    return 'Registration could not be completed. '
        'This company or GST may already be registered — try Sign In or contact MPRS support.';
  }

  return 'Registration could not be completed. '
      'This company name or GST number may already be registered. '
      'Try Sign In or contact MPRS support.';
}

String _cleanQuotes(String value) {
  var s = value.trim();
  if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
    s = s.substring(1, s.length - 1);
  }
  return s;
}