import 'package:mprs_android/model/get_quote_detail_model.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';

class QuoteLineDetailsResult {
  final SavedQuotationsModel? quote;
  final List<GetQuoteDetailModel> lineItems;

  QuoteLineDetailsResult({
    this.quote,
    this.lineItems = const [],
  });
}
