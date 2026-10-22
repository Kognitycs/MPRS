import 'package:mprs_android/core/utils/shared_preferences.dart';

/// Quote ids the signed-in user reserved with Reserve Your Space.
/// Kept until that quote shows up as an order.
class ReservedQuoteStore {
  ReservedQuoteStore._();

  static const _key = 'reserved_quote_ids';

  static Set<String> ids() {
    return PreferenceUtils.getStringList(
      _key,
    ).map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  static Future<void> add(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;
    final next = ids()..add(id);
    await PreferenceUtils.setStringList(_key, next.toList());
  }

  static Future<void> removeAll(Iterable<String> quoteIds) async {
    final drop =
        quoteIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (drop.isEmpty) return;
    final next = ids()..removeAll(drop);
    await PreferenceUtils.setStringList(_key, next.toList());
  }
}
