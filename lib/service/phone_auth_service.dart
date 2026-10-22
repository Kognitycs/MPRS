import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';

class PhoneSendOtpResult {
  final String? autoVerifiedIdToken;

  const PhoneSendOtpResult({this.autoVerifiedIdToken});

  bool get isAutoVerified => autoVerifiedIdToken?.isNotEmpty == true;
}

/// Firebase Phone Auth (send/verify SMS) + backend [verify-phone] with idToken.
class PhoneAuthService {
  PhoneAuthService();

  static const Duration minSendInterval = Duration(seconds: 30);
  static const Duration firebaseRateLimitDuration = Duration(hours: 2);
  static const Duration firebaseDeviceBlockDuration = Duration(hours: 24);

  static const _firebaseBlockedUntilKey = 'phone_auth_firebase_blocked_until';
  static const _lastSendPrefix = 'phone_auth_last_send_';

  /// Firebase Console → Authentication → Phone → Phone numbers for testing.
  /// Add the same E.164 numbers here (e.g. `+919876543210`) so debug builds
  /// skip the local 24h device block and use test verification.
  static const Set<String> firebaseTestPhoneNumbers = {
    // Add your Firebase Console test numbers below (E.164 format):
    // '+919876543210',
  };

  /// Clears the local OTP cooldown saved after too-many-requests (debug/support).
  static Future<void> clearFirebaseDeviceBlock() async {
    await PreferenceUtils.remove(_firebaseBlockedUntilKey);
    debugPrint('PhoneAuth: local Firebase device block cleared');
  }

  static bool _isFirebaseConsoleTestNumber(String e164) =>
      kDebugMode && firebaseTestPhoneNumbers.contains(e164);

  static final Map<String, DateTime> _lastSendByPhone = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;

  void reset() {
    _verificationId = null;
    _resendToken = null;
  }

  /// Sends OTP via Firebase [verifyPhoneNumber] — same flow as Firebase sample app.
  Future<PhoneSendOtpResult> sendOtp(String phoneNumber) async {
    final e164 = _toE164(phoneNumber);
    if (e164 == null) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Please enter a valid mobile number with country code.',
      );
    }

    reset();

    if (kDebugMode) {
      await clearFirebaseDeviceBlock();
    }

    if (_isFirebaseConsoleTestNumber(e164)) {
      // Test numbers skip resend cooldown too.
    } else {
      _enforceClientSendCooldown(e164);
      await _enforceFirebaseDeviceBlock();
    }

    await _configureAppVerification(e164);

    debugPrint('PhoneAuth: sending OTP to $e164');

    final completer = Completer<PhoneSendOtpResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: e164,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          if (completer.isCompleted) return;
          debugPrint('PhoneAuth: auto-verified on device');
          final idToken = await _signInAndGetIdToken(credential);
          debugPrint('PhoneAuth: auto-verify idToken received');
          completer.complete(PhoneSendOtpResult(autoVerifiedIdToken: idToken));
        } catch (e, st) {
          debugPrint('PhoneAuth auto-verify failed: $e\n$st');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('PhoneAuth verification failed: ${e.code} ${e.message}');
        if (e.code == 'too-many-requests' || e.code == 'quota-exceeded') {
          if (!_isFirebaseConsoleTestNumber(e164)) {
            unawaited(_recordFirebaseBlock(e));
          }
        }
        if (!completer.isCompleted) {
          completer.completeError(_mapVerificationFailure(e));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        unawaited(_recordSuccessfulSend(e164));
        debugPrint('PhoneAuth: OTP sent, verificationId stored');
        unawaited(_sendOtpOnBackend(e164));
        if (!completer.isCompleted) {
          completer.complete(const PhoneSendOtpResult());
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        debugPrint('PhoneAuth: auto-retrieval timeout');
      },
    );

    return completer.future;
  }

  /// Verifies the 6-digit SMS code with Firebase and returns the idToken.
  Future<String> verifySmsCodeAndGetIdToken(String smsCode) async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Please request OTP again.',
      );
    }

    final code = smsCode.trim();
    if (code.length != 6) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Please enter the 6-digit OTP.',
      );
    }

    debugPrint('PhoneAuth: verifying SMS code');

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    final idToken = await _signInAndGetIdToken(credential);
    debugPrint('PhoneAuth: Firebase idToken received');
    return idToken;
  }

  Future<ApiResponse> verifyPhoneOnBackend(String idToken) async {
    debugPrint('PhoneAuth: POST ${ApiConstants.verifyPhone}');
    return HttpClientHelper.post(
      ApiConstants.verifyPhone,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'idToken': idToken}),
    );
  }

  Future<String> verifyPhoneWithBackend(String idToken) async {
    final response = await verifyPhoneOnBackend(idToken);
    debugPrint(
      'PhoneAuth: verify-phone status=${response.statusCode} '
      'body=${response.data}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(response.data);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
      } catch (_) {}
      return 'Mobile number verified successfully';
    }

    throw Exception(
      parseApiErrorMessage(
        response.data,
        fallback: response.message ?? 'Phone verification failed',
      ),
    );
  }

  /// Calls verify-phone when available; does not throw on failure.
  Future<String?> tryVerifyPhoneWithBackend(String idToken) async {
    try {
      return await verifyPhoneWithBackend(idToken);
    } catch (e, st) {
      debugPrint('PhoneAuth: verify-phone skipped/failed: $e\n$st');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    reset();
  }

  /// Clears Firebase session only — keeps verificationId for OTP retry.
  Future<void> clearFirebaseSession() async {
    await _auth.signOut();
  }

  Future<String> resetForgotPassword({
    required String mobile,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await HttpClientHelper.post(
      ApiConstants.forgotPassword,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'mobile': mobile.trim(),
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(response.data);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
      } catch (_) {}
      return 'Password updated successfully. Please log in.';
    }

    throw Exception(
      parseApiErrorMessage(
        response.data,
        fallback: response.message ?? 'Failed to reset password',
      ),
    );
  }

  Future<void> _configureAppVerification(String e164) async {
    final useTestMode = _isFirebaseConsoleTestNumber(e164);
    // Sideloaded debug/staging builds often fail Play Integrity (17028) even
    // when SHAs are in Firebase. Firebase allows disabling verification in debug.
    final disableVerification =
        useTestMode || (kDebugMode && AppConfig.isTestBuild);
    await _auth.setSettings(
      appVerificationDisabledForTesting: disableVerification,
    );
    if (disableVerification) {
      debugPrint(
        'PhoneAuth: appVerificationDisabledForTesting=true '
        '(staging/debug=${AppConfig.isTestBuild && kDebugMode}, testNumber=$useTestMode)',
      );
    }
  }

  FirebaseAuthException _mapVerificationFailure(FirebaseAuthException e) {
    if (e.code == 'missing-recaptcha-token' ||
        e.code == 'missing-app-identifier' ||
        e.code == 'app-not-authorized') {
      final packageName = AppConfig.isTestBuild
          ? 'com.mobile.mprs_android.test'
          : 'com.mobile.mprs_android';
      final detail = e.message?.trim();
      final playIntegrity = detail != null &&
          detail.toLowerCase().contains('play_integrity');
      return FirebaseAuthException(
        code: e.code,
        message:
            playIntegrity
                ? 'Play Integrity rejected this build (error 17028) for '
                    '$packageName.\n\n'
                    'Your staging APK is signed with debug cert '
                    '(SHA-1 E8:14:44:14:…). If those SHAs are already in Firebase, '
                    'check Google Cloud → Credentials for the Android API key: '
                    'remove Android '
                    'restrictions or include this package + both SHAs; allow '
                    'Identity Toolkit API.\n\n'
                    'For local staging debug, rebuild after pull (verification '
                    'is disabled in debug). For release OTP, add upload-keystore '
                    'SHA-1/SHA-256 to the same Firebase Android app.\n\n'
                    'Firebase: $detail'
                : 'App verification failed for $packageName. '
                    'Add SHA-1 and SHA-256 in Firebase, enable Play Integrity '
                    'API on project mprs-rms, re-download google-services.json, '
                    'then rebuild.\n\n${detail ?? e.code}',
      );
    }
    if (e.code == 'too-many-requests' || e.code == 'quota-exceeded') {
      final remaining = firebaseBlockSecondsRemaining();
      if (remaining > 0) {
        return FirebaseAuthException(
          code: e.code,
          message:
              'Firebase has temporarily blocked OTP on this device. '
              'Please wait ${_formatWaitDuration(remaining)} before trying again.',
        );
      }
      return FirebaseAuthException(
        code: e.code,
        message:
            'Too many OTP attempts. Firebase has temporarily blocked this device. '
            'Wait 24 hours, use a Firebase test phone number while developing, '
            'or try another device.',
      );
    }
    return e;
  }

  /// Seconds until Firebase device/rate block expires (0 = not blocked).
  static int firebaseBlockSecondsRemaining() {
    final blockedUntilMs = PreferenceUtils.getInt(_firebaseBlockedUntilKey);
    if (blockedUntilMs <= 0) return 0;

    final remainingMs = blockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      unawaited(PreferenceUtils.remove(_firebaseBlockedUntilKey));
      return 0;
    }
    return (remainingMs / 1000).ceil();
  }

  static Future<void> _enforceFirebaseDeviceBlock() async {
    if (kDebugMode) return;

    final remaining = firebaseBlockSecondsRemaining();
    if (remaining <= 0) return;

    throw FirebaseAuthException(
      code: 'too-many-requests',
      message:
          'Firebase has temporarily blocked OTP on this device. '
          'Please wait ${_formatWaitDuration(remaining)} before trying again.',
    );
  }

  static Future<void> _recordFirebaseBlock(FirebaseAuthException e) async {
    if (kDebugMode) return;

    final message = e.message?.toLowerCase() ?? '';
    final isDeviceBlock =
        message.contains('blocked all requests') ||
        message.contains('unusual activity');
    final duration =
        isDeviceBlock ? firebaseDeviceBlockDuration : firebaseRateLimitDuration;
    final blockedUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
    await PreferenceUtils.setInt(_firebaseBlockedUntilKey, blockedUntil);
    debugPrint(
      'PhoneAuth: Firebase block recorded until '
      '${DateTime.fromMillisecondsSinceEpoch(blockedUntil)}',
    );
  }

  static Future<void> _recordSuccessfulSend(String e164) async {
    final now = DateTime.now();
    _lastSendByPhone[e164] = now;
    await PreferenceUtils.setInt(
      '$_lastSendPrefix$e164',
      now.millisecondsSinceEpoch,
    );
  }

  static DateTime? _lastSendForPhone(String e164) {
    final inMemory = _lastSendByPhone[e164];
    if (inMemory != null) return inMemory;

    final storedMs = PreferenceUtils.getInt('$_lastSendPrefix$e164');
    if (storedMs <= 0) return null;

    final stored = DateTime.fromMillisecondsSinceEpoch(storedMs);
    _lastSendByPhone[e164] = stored;
    return stored;
  }

  static String _formatWaitDuration(int totalSeconds) {
    if (totalSeconds >= 3600) {
      final hours = (totalSeconds / 3600).ceil();
      return '$hours hour${hours == 1 ? '' : 's'}';
    }
    if (totalSeconds >= 60) {
      final minutes = (totalSeconds / 60).ceil();
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    }
    return '$totalSeconds seconds';
  }

  void _enforceClientSendCooldown(String e164) {
    final last = _lastSendForPhone(e164);
    if (last == null) return;

    final elapsed = DateTime.now().difference(last);
    if (elapsed >= minSendInterval) return;

    final waitSeconds = (minSendInterval - elapsed).inSeconds;
    throw FirebaseAuthException(
      code: 'too-many-requests',
      message:
          'Please wait $waitSeconds seconds before requesting another OTP.',
    );
  }

  /// Remaining seconds before the same number can request OTP again.
  static int secondsUntilResendAllowed(String phoneNumber) {
    final e164 = _toE164(phoneNumber);
    if (e164 == null) return 0;

    final firebaseBlock = firebaseBlockSecondsRemaining();
    if (firebaseBlock > 0) return firebaseBlock;

    final last = _lastSendForPhone(e164);
    if (last == null) return 0;

    final elapsed = DateTime.now().difference(last);
    if (elapsed >= minSendInterval) return 0;
    return (minSendInterval - elapsed).inSeconds;
  }

  Future<void> _sendOtpOnBackend(String e164Phone) async {
    final digits = e164Phone.replaceAll(RegExp(r'\D'), '');
    final mobile =
        digits.length > 10 ? digits.substring(digits.length - 10) : digits;

    try {
      final response = await HttpClientHelper.post(
        ApiConstants.sendOtp,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'mobile': mobile, 'phoneNumber': e164Phone}),
      );

      if (response.statusCode == 404) return;

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
          'Send OTP API warning: ${response.statusCode} ${response.data}',
        );
      }
    } catch (e) {
      debugPrint('Send OTP API call skipped: $e');
    }
  }

  Future<String> _signInAndGetIdToken(PhoneAuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    final token = await userCredential.user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Could not retrieve verification token.',
      );
    }
    return token;
  }

  /// Normalises input to E.164, e.g. `+916395242924`.
  static String? _toE164(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10) return null;
      return '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length > 10) return '+$digits';
    return null;
  }
}
