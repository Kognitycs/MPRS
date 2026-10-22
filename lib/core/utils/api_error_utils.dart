import 'dart:convert';

/// Extracts a user-facing message from API JSON error bodies.
String parseApiErrorMessage(
  dynamic body, {
  String fallback = 'Something went wrong',
}) {
  try {
    final Map<String, dynamic>? decoded = switch (body) {
      final String s when s.trim().isNotEmpty =>
        jsonDecode(s) as Map<String, dynamic>?,
      final Map<String, dynamic> m => m,
      _ => null,
    };
    if (decoded == null) return fallback;

    final rawMessage = decoded['message']?.toString().trim();
    if (rawMessage != null &&
        rawMessage.toLowerCase().contains('signup failed')) {
      return _signupFailureMessage(decoded, rawMessage);
    }

    if (rawMessage != null && rawMessage.isNotEmpty) {
      final detailLine = _firstValidationDetail(decoded['details']);
      if (detailLine != null) {
        return '$rawMessage ($detailLine)';
      }
      return rawMessage;
    }

    final detailLine = _firstValidationDetail(decoded['details']);
    if (detailLine != null) return detailLine;

    return fallback;
  } catch (_) {
    return fallback;
  }
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
    return 'Registration could not be completed ($statusText). '
        'This company or GST may already be registered — try Sign In or contact MPRS support.';
  }

  return 'Registration could not be completed. '
      'This company name or GST number may already be registered. '
      'Try Sign In or contact MPRS support.';
}

String? _firstValidationDetail(dynamic details) {
  if (details is! List || details.isEmpty) return null;
  final first = details.first;
  if (first is Map) {
    final msg = first['message']?.toString().trim();
    if (msg != null && msg.isNotEmpty) return msg;
  }
  return null;
}

String _cleanQuotes(String value) {
  var s = value.trim();
  if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
    s = s.substring(1, s.length - 1);
  }
  return s;
}
