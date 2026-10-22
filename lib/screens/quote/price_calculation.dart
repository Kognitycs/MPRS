import 'package:mprs_android/model/pricebook_entry_model.dart';

/// Implements the pricing rules from the spec:
///
/// ┌──────────┬───────────┬──────────────────────────────────────────────────┐
/// │ UserType │ Buy Price │ Sell Price                                       │
/// ├──────────┼───────────┼──────────────────────────────────────────────────┤
/// │ VVIP     │ unitPrice │ unitPrice + suggestedMargin + accountMarginValue │
/// │ VIP      │ unitPrice │ unitPrice + accountMarginValue                   │
/// │ External │ unitPrice │ Override=Yes → unitPrice + suggestedMargin       │
/// │          │           │ Override=No  → unitPrice + min(sm, acctMargin)   │
/// └──────────┴───────────┴──────────────────────────────────────────────────┘
///
/// When account margin (from account API) and suggested margin (on the entry)
/// are both blank, External users get a fixed default margin by container size:
///   20' → +25,  40' → +50
/// VIP, VVIP, Admin, Internal, and every other user type do not get this
/// default. Their sell price follows the user-type rules below.
///
/// Override on the entry does not affect this External default path — only
/// suggested margin or account margin having a value switches to the
/// user-type rules below.
///
/// accountMarginValue = unitPrice × (accountMarginPct / 100)
///
/// This logic applies ONLY to "Ocean Freight" and "THC" products.
/// All other products: buy = sell = unitPrice.

class PricingCalculator {
  PricingCalculator._();

  /// Calculate buy/sell prices for a single [entry].
  ///
  /// [userType]         : "VVIP" | "VIP" | "External"  (case-insensitive)
  /// [accountMarginPct] : e.g. 10.0  →  10%; null when not configured
  /// [forceMargin]      : bypass the isMarginProduct name-check and always
  ///                      apply pricing rules (use in PricebookResultsScreen
  ///                      where every entry is an ocean-freight rate even if
  ///                      its product name does not contain "ocean freight").
  static PricingResult calculate({
    required PricebookEntryModel entry,
    required String userType,
    double? accountMarginPct,
    bool forceMargin = false,
  }) {
    final unitPrice = entry.unitPrice;

    // Non-margin products: no markup applied
    if (!forceMargin && !entry.isMarginProduct) {
      return PricingResult(
        buyPrice: unitPrice,
        sellPrice: unitPrice,
        accountMarginValue: 0,
        appliedSuggestedMargin: 0,
      );
    }

    final normalizedUserType = userType.trim().toUpperCase();
    if (normalizedUserType == 'EXTERNAL' &&
        _useDefaultMargin(entry, accountMarginPct)) {
      final defaultMargin = _defaultMarginForSize(entry.containerSize);
      return PricingResult(
        buyPrice: unitPrice,
        sellPrice: unitPrice + defaultMargin,
        accountMarginValue: 0,
        appliedSuggestedMargin: defaultMargin,
      );
    }

    final marginPct = accountMarginPct ?? 0.0;
    final accountMarginValue = unitPrice * (marginPct / 100.0);
    final sm = entry.suggestedMarginC ?? 0.0;
    double sellPrice;

    switch (normalizedUserType) {
      case 'VVIP':
        sellPrice = unitPrice + sm + accountMarginValue;
        break;

      case 'VIP':
        sellPrice = unitPrice + accountMarginValue;
        break;

      case 'EXTERNAL':
      default:
        if (entry.overrideAccountMarginC == true) {
          sellPrice = unitPrice + sm;
        } else {
          final lowerMargin = sm < accountMarginValue ? sm : accountMarginValue;
          sellPrice = unitPrice + lowerMargin;
        }
        break;
    }

    return PricingResult(
      buyPrice: unitPrice,
      sellPrice: sellPrice,
      accountMarginValue: accountMarginValue,
      appliedSuggestedMargin: sm,
    );
  }

  /// Convenience: compute results for a whole list of entries.
  static List<PricingResult> calculateAll({
    required List<PricebookEntryModel> entries,
    required String userType,
    double? accountMarginPct,
  }) =>
      entries
          .map(
            (e) => calculate(
              entry: e,
              userType: userType,
              accountMarginPct: accountMarginPct,
            ),
          )
          .toList();

  /// External-only default. Applies when both suggested margin and account
  /// margin are blank. Override (true/false/null) is ignored for this decision.
  static bool _useDefaultMargin(
    PricebookEntryModel entry,
    double? accountMarginPct,
  ) =>
      !_hasSuggestedMargin(entry.suggestedMarginC) &&
      !_hasAccountMarginPct(accountMarginPct);

  static bool _hasSuggestedMargin(double? value) =>
      value != null && value != 0;

  static bool _hasAccountMarginPct(double? pct) => pct != null && pct != 0;

  static double _defaultMarginForSize(String containerSize) {
    final size = containerSize.toUpperCase();
    if (size.contains('20')) return 25.0;
    if (size.contains('40')) return 50.0;
    return 0.0;
  }
}

class PricingResult {
  final double buyPrice;
  final double sellPrice;
  final double accountMarginValue;
  final double appliedSuggestedMargin;

  const PricingResult({
    required this.buyPrice,
    required this.sellPrice,
    required this.accountMarginValue,
    required this.appliedSuggestedMargin,
  });

  double get margin => sellPrice - buyPrice;

  @override
  String toString() =>
      'PricingResult(buy: $buyPrice, sell: $sellPrice, '
      'margin: $margin, acctMarginVal: $accountMarginValue, '
      'suggestedMargin: $appliedSuggestedMargin)';
}
