import 'dart:convert';

import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/service/http_client_helper.dart';

class AuthMobileCheckResult {
  final bool exists;
  final String? message;
  final bool succeeded;

  const AuthMobileCheckResult._({
    required this.exists,
    this.message,
    required this.succeeded,
  });

  factory AuthMobileCheckResult.registered() =>
      const AuthMobileCheckResult._(exists: true, succeeded: true);

  factory AuthMobileCheckResult.notRegistered(String message) =>
      AuthMobileCheckResult._(
        exists: false,
        message: message,
        succeeded: true,
      );

  factory AuthMobileCheckResult.failed(String message) =>
      AuthMobileCheckResult._(
        exists: false,
        message: message,
        succeeded: false,
      );
}

/// Verifies that a mobile is registered before the login password step.
///
/// Uses `POST /auth/login` with a probe password. The API returns
/// "Mobile number does not exist" when the user is not registered (staging);
/// other errors (e.g. incorrect password) imply the mobile exists.
class AuthMobileCheckService {
  static const String _probePassword = '__MPRS_MOBILE_EXISTENCE_PROBE__';

  static Future<AuthMobileCheckResult> checkRegistered(String rawMobile) async {
    final mobile = _normalizeIndianMobile(rawMobile);
    if (mobile == null) {
      return AuthMobileCheckResult.failed('Invalid number. Please try again.');
    }

    try {
      final response = await HttpClientHelper.postWithApplicationJson(
        ApiConstants.login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mobile': mobile,
          'password': _probePassword,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthMobileCheckResult.registered();
      }

      final message = parseApiErrorMessage(
        response.data,
        fallback: response.message ?? 'Unable to verify mobile number',
      );

      if (_indicatesMobileNotRegistered(message, response.statusCode)) {
        return AuthMobileCheckResult.notRegistered(
          message.toLowerCase().contains('does not exist')
              ? message
              : 'No account found for this mobile number. Please sign up.',
        );
      }

      return AuthMobileCheckResult.registered();
    } catch (_) {
      return AuthMobileCheckResult.failed(
        'Unable to verify mobile number. Please try again.',
      );
    }
  }

  static String? _normalizeIndianMobile(String input) {
    var number = input.replaceAll(RegExp(r'\s+'), '');
    if (number.startsWith('+91')) {
      number = number.substring(3);
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(number)) return null;
    return number;
  }

  static bool _indicatesMobileNotRegistered(String message, int statusCode) {
    final lower = message.toLowerCase();
    if (statusCode == 404) return true;
    if (lower.contains('does not exist')) return true;
    if (lower.contains('not registered')) return true;
    if (lower.contains('no account')) return true;
    if (lower.contains('user not found')) return true;
    if (lower.contains('mobile number') && lower.contains('not found')) {
      return true;
    }
    return false;
  }
}
