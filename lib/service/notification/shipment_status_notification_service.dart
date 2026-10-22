import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/base_client.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/core/database/notification_db.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart' as booking;
import 'package:mprs_android/model/get_shipment_model.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/service/notification/notification_inbox_store.dart';
import 'package:mprs_android/service/notification/notification_service.dart';

/// Notifies only when a timeline step **newly** completes — not on login/list refresh.
class ShipmentStatusNotificationService {
  ShipmentStatusNotificationService._();

  static const String _prefsPrefix = 'shipment_status_done_';
  static NotificationServices? _push;

  static NotificationServices get _notifier =>
      _push ??= NotificationServices();

  static const List<_ShipmentStep> _steps = [
    _ShipmentStep(
      key: 'booked',
      title: 'Booked',
      dateField: 'Booked_Date__c',
      shortLabel: 'booked',
    ),
    _ShipmentStep(
      key: 'picked_up',
      title: 'Container Picked Up',
      dateField: 'Picked_Up_Date__c',
      shortLabel: 'picked up',
    ),
    _ShipmentStep(
      key: 'gated_in',
      title: 'Container Gated In',
      dateField: 'Gated_In_Date__c',
      shortLabel: 'gated in',
    ),
    _ShipmentStep(
      key: 'on_board',
      title: 'Container Loaded On Board',
      dateField: 'On_Board_Date__c',
      shortLabel: 'onboarded',
    ),
    _ShipmentStep(
      key: 'vessel_sailed',
      title: 'Vessel Sailed',
      dateField: 'Vessel_Sailed_Date__c',
      shortLabel: 'sailed',
    ),
    _ShipmentStep(
      key: 'transshipment_discharge',
      title: 'Container Discharged at Trans-shipment Port',
      dateField: 'Transshipment_Discharge_Date__c',
      shortLabel: 'discharged at trans-shipment port',
    ),
    _ShipmentStep(
      key: 'transshipment_loaded',
      title: 'Container Loaded from Trans-shipment port',
      dateField: 'Transshipment_Loaded_Date__c',
      shortLabel: 'loaded from trans-shipment port',
    ),
    _ShipmentStep(
      key: 'discharged',
      title: 'Container Discharged at Destination',
      dateField: 'Discharged_Date__c',
      shortLabel: 'discharged at destination',
    ),
    _ShipmentStep(
      key: 'cleared',
      title: 'Cargo Cleared at Consignee',
      dateField: 'Cleared_Date__c',
      shortLabel: 'cleared at consignee',
    ),
    _ShipmentStep(
      key: 'returned',
      title: 'Empty Container Returned',
      dateField: 'Returned_Date__c',
      shortLabel: 'returned',
    ),
  ];

  /// Load bookings for this account and save any missing status cards to SQLite.
  static Future<void> syncInboxFromBookings() async {
    if (AuthDataHelper.isInternalUser()) return;

    final accountId =
        DbHelper().getUserModel()?.accountId?.trim() ??
        AuthDataHelper.getAccountId().trim();
    if (accountId.isEmpty) return;

    try {
      final response = await BaseClient().handleRequest(
        ApiRequest(
          url:
              ApiConstants.userBookingsList(accountId),
          method: DioMethod.get,
        ),
      );

      if (response == null || response['status'] != 200) return;

      final bookings = <booking.Records>[];
      for (final item in response['bookings'] as List<dynamic>? ?? []) {
        if (item is Map) {
          bookings.add(
            booking.Records.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }

      if (bookings.isNotEmpty) {
        await processBookingRecords(bookings);
        for (final record in bookings) {
          final quoteId = record.quoteId?.toString().trim() ?? '';
          final orderId = record.id?.toString().trim() ?? '';
          if (quoteId.isEmpty || orderId.isEmpty) continue;
          await _syncOrderFromDetailApi(accountId, quoteId, orderId);
        }
      }
    } catch (e) {
      debugPrint('⚠️ syncInboxFromBookings: $e');
    }
  }

  /// Detailed booking API has full timeline dates (all completed statuses).
  static Future<void> _syncOrderFromDetailApi(
    String accountId,
    String quoteId,
    String orderId,
  ) async {
    try {
      final response = await BaseClient().handleRequest(
        ApiRequest(
          url:
              ApiConstants.detailedBooking(accountId, quoteId),
          method: DioMethod.get,
        ),
      );

      if (response == null || response['status'] != 200) return;

      for (final item in response['bookings'] as List<dynamic>? ?? []) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if (map['Id']?.toString().trim() == orderId) {
          await processOrderMap(map);
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ detail sync order $orderId: $e');
    }
  }

  static Future<void> processBookingRecords(
    List<booking.Records> records,
  ) async {
    for (final record in records) {
      await processOrderMap(record.toJson());
    }
  }

  static Future<void> processRecords(List<Records> records) async {
    for (final record in records) {
      await processOrderMap(record.toJson());
    }
  }

  static Future<void> processOrderMap(Map<String, dynamic> order) async {
    if (AuthDataHelper.isInternalUser()) return;

    final orderId = order['Id']?.toString().trim() ?? '';
    if (orderId.isEmpty) return;

    final currentlyDone = <String>{};
    for (final step in _steps) {
      if (_hasDate(order[step.dateField])) {
        currentlyDone.add(step.key);
      }
    }

    if (currentlyDone.isEmpty) return;

    final previouslyKnown = await _knownDoneSteps(orderId);
    final newlyDone = currentlyDone.difference(previouslyKnown);
    final msl = _resolveMsl(order);
    final vessel = order['Vessel_Name__c']?.toString().trim() ?? '';
    final loadingPort = order['Port_of_Loading__c']?.toString().trim() ?? '';
    final destinationPort =
        order['Port_of_Destination__c']?.toString().trim() ?? '';
    final departureDate = order['Departure_Date__c'];

    // Always save missing cards (fixes prefs-only baseline with empty inbox).
    for (final step in _steps) {
      if (!currentlyDone.contains(step.key)) continue;

      final notificationId = 'shipment_${orderId}_${step.key}';
      final statusChangedAt = _parseStatusInstant(order[step.dateField]);
      final alreadySaved =
          await NotificationDB.instance.existsById(notificationId);

      if (alreadySaved) {
        await _repairCardStatusTime(
          notificationId: notificationId,
          orderId: orderId,
          step: step,
          msl: msl,
          statusChangedAt: statusChangedAt,
          order: order,
          vessel: vessel,
          loadingPort: loadingPort,
          destinationPort: destinationPort,
          departureDate: departureDate,
        );
        continue;
      }

      final showPush =
          previouslyKnown.isNotEmpty && newlyDone.contains(step.key);

      await _deliver(
        orderId: orderId,
        stepKey: step.key,
        stepTitle: step.title,
        header: 'Your Shipment $msl is ${step.shortLabel}.',
        body: _buildBody(
          msl: msl,
          step: step,
          statusDate: order[step.dateField],
          vessel: vessel,
          loadingPort: loadingPort,
          destinationPort: destinationPort,
          departureDate: departureDate,
        ),
        statusChangedAt: statusChangedAt,
        showPush: showPush,
      );
    }

    await _saveKnownDone(orderId, currentlyDone);
  }

  /// Prefs + inbox rows (survives logout when cards are already saved).
  static Future<Set<String>> _knownDoneSteps(String orderId) async {
    final fromPrefs = _loadKnownDonePrefs(orderId);
    if (fromPrefs.isNotEmpty) return fromPrefs;

    final fromInbox =
        await NotificationDB.instance.getShipmentStepKeysForOrder(orderId);
    if (fromInbox.isNotEmpty) return fromInbox;

    return {};
  }

  static String _prefsKey(String orderId) {
    final accountId =
        DbHelper().getUserModel()?.accountId?.trim() ??
        AuthDataHelper.getAccountId().trim();
    if (accountId.isEmpty) return '$_prefsPrefix$orderId';
    return '${_prefsPrefix}${accountId}_$orderId';
  }

  static String _resolveMsl(Map<String, dynamic> order) {
    final opp = order['Opportunity'];
    if (opp is Map && opp['Name'] != null) {
      final name = opp['Name'].toString().trim();
      if (name.isNotEmpty) return name;
    }
    final ref = order['OrderReferenceNumber']?.toString().trim() ?? '';
    if (ref.isNotEmpty) return ref;
    final orderNo = order['OrderNumber']?.toString().trim() ?? '';
    if (orderNo.isNotEmpty) return orderNo;
    return 'Shipment';
  }

  static bool _hasDate(dynamic value) {
    if (value == null) return false;
    final text = value.toString().trim();
    return text.isNotEmpty && text != '-';
  }

  static DateTime _parseStatusInstant(dynamic raw) {
    if (!_hasDate(raw)) return DateTime.now();
    try {
      final text = raw.toString().trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
        return DateTime.parse('${text}T12:00:00');
      }
      return DateTime.parse(text);
    } catch (_) {
      return DateTime.now();
    }
  }

  static Future<void> _repairCardStatusTime({
    required String notificationId,
    required String orderId,
    required _ShipmentStep step,
    required String msl,
    required DateTime statusChangedAt,
    required Map<String, dynamic> order,
    required String vessel,
    required String loadingPort,
    required String destinationPort,
    required dynamic departureDate,
  }) async {
    final existing = await NotificationDB.instance.getById(notificationId);
    if (existing == null) return;

    final accountId =
        DbHelper().getUserModel()?.accountId?.trim() ??
        AuthDataHelper.getAccountId().trim();

    final item = NotificationItem(
      id: notificationId,
      notificationId: notificationId,
      notificationTempId: '',
      messageHeader: 'Your Shipment $msl is ${step.shortLabel}.',
      messageBody: _buildBody(
        msl: msl,
        step: step,
        statusDate: order[step.dateField],
        vessel: vessel,
        loadingPort: loadingPort,
        destinationPort: destinationPort,
        departureDate: departureDate,
      ),
      link: jsonEncode({
        'type': 'shipmentStatus',
        'orderId': orderId,
        'statusKey': step.key,
        'statusTitle': step.title,
        'statusUpdatedAt': statusChangedAt.toIso8601String(),
        if (accountId.isNotEmpty) 'accountId': accountId,
      }),
      scheduledDate: statusChangedAt,
      scheduledTime: statusChangedAt,
      targetUsers: existing.targetUsers,
      isActive: true,
      isApproved: true,
      status: 'received',
      createdBy: null,
      lastUpdatedBy: '',
      createdAt: statusChangedAt,
      updatedAt: statusChangedAt,
      ownerAccountId: accountId.isNotEmpty ? accountId : existing.ownerAccountId,
    );

    await NotificationDB.instance.insert(item);
  }

  static String _buildBody({
    required String msl,
    required _ShipmentStep step,
    required dynamic statusDate,
    required String vessel,
    required String loadingPort,
    required String destinationPort,
    required dynamic departureDate,
  }) {
    final dateText = _formatDisplayDate(statusDate);
    final sailText = _formatDisplayDate(departureDate);

    switch (step.key) {
      case 'booked':
        return 'Your shipment $msl has been successfully booked'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}. '
            'Track your shipment anytime in the app.';
      case 'picked_up':
        return 'Your shipment $msl was picked up'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'gated_in':
        final terminal = loadingPort.isNotEmpty ? loadingPort : 'the terminal';
        return 'Your shipment $msl is handed over to the $terminal terminal'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'on_board':
        if (vessel.isNotEmpty && sailText.isNotEmpty) {
          return 'Your shipment $msl is onboarded on vessel $vessel '
              'and is expected to sail on $sailText.';
        }
        if (vessel.isNotEmpty) {
          return 'Your shipment $msl is onboarded on vessel $vessel'
              '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
        }
        return 'Your shipment $msl is onboarded'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'vessel_sailed':
        return 'Your shipment $msl has sailed'
            '${vessel.isNotEmpty ? ' on vessel $vessel' : ''}'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'transshipment_discharge':
        return 'Your shipment $msl was discharged at the trans-shipment port'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'transshipment_loaded':
        return 'Your shipment $msl was loaded from the trans-shipment port'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'discharged':
        final port =
            destinationPort.isNotEmpty ? destinationPort : 'destination';
        return 'Your shipment $msl was discharged at $port'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'cleared':
        return 'Cargo for shipment $msl was cleared at consignee'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      case 'returned':
        return 'Empty container for shipment $msl was returned'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
      default:
        return 'Your shipment $msl status updated: ${step.title}'
            '${dateText.isNotEmpty ? ' on $dateText' : ''}.';
    }
  }

  static String _formatDisplayDate(dynamic raw) {
    if (!_hasDate(raw)) return '';
    try {
      final parsed = DateTime.parse(raw.toString());
      return DateFormat('d\'${_daySuffix(parsed.day)}\' MMM yyyy').format(parsed);
    } catch (_) {
      return raw.toString().trim();
    }
  }

  static String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static Set<String> _loadKnownDonePrefs(String orderId) {
    final raw = PreferenceUtils.getString(_prefsKey(orderId), '');
    if (raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveKnownDone(String orderId, Set<String> keys) async {
    await PreferenceUtils.setString(
      _prefsKey(orderId),
      jsonEncode(keys.toList()),
    );
  }

  static Future<bool> _deliver({
    required String orderId,
    required String stepKey,
    required String stepTitle,
    required String header,
    required String body,
    required DateTime statusChangedAt,
    required bool showPush,
  }) async {
    final userType = AuthDataHelper.getUserType().trim();
    final accountId =
        DbHelper().getUserModel()?.accountId?.trim() ??
        AuthDataHelper.getAccountId().trim();
    final id = 'shipment_${orderId}_$stepKey';

    final item = NotificationItem(
      id: id,
      notificationId: id,
      notificationTempId: '',
      messageHeader: header,
      messageBody: body,
      link: jsonEncode({
        'type': 'shipmentStatus',
        'orderId': orderId,
        'statusKey': stepKey,
        'statusTitle': stepTitle,
        'statusUpdatedAt': statusChangedAt.toIso8601String(),
        if (accountId.isNotEmpty) 'accountId': accountId,
      }),
      scheduledDate: statusChangedAt,
      scheduledTime: statusChangedAt,
      targetUsers: userType.isNotEmpty ? [userType] : null,
      isActive: true,
      isApproved: true,
      status: 'received',
      createdBy: null,
      lastUpdatedBy: '',
      createdAt: statusChangedAt,
      updatedAt: statusChangedAt,
      ownerAccountId: accountId.isNotEmpty ? accountId : null,
    );

    try {
      final saved = await NotificationDB.instance.insertIfAbsent(item);
      if (!saved) return false;
    } catch (e) {
      debugPrint('⚠️ Shipment notification DB save: $e');
      return false;
    }

    NotificationInboxStore.instance.addNew(item);

    if (showPush) {
      try {
        await _notifier.showLocalNotification(
          title: header,
          body: body,
          payload: item.link,
        );
      } catch (e) {
        debugPrint('⚠️ Shipment push display: $e');
      }
    }

    debugPrint('🔔 Shipment inbox: $header @ $statusChangedAt');
    return true;
  }
}

class _ShipmentStep {
  final String key;
  final String title;
  final String dateField;
  final String shortLabel;

  const _ShipmentStep({
    required this.key,
    required this.title,
    required this.dateField,
    required this.shortLabel,
  });
}
