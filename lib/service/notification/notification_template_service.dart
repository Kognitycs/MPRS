import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/model/template_list_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';

/// Loads notification templates for list + push-notification dropdowns.
class NotificationTemplateService {
  NotificationTemplateService._();

  /// Visible templates — hide only rows explicitly marked inactive.
  static bool _isVisibleTemplate(TemplateModel template) =>
      template.isActive != false;

  /// All templates for the Templates tab (matches older app behaviour).
  static Future<List<TemplateModel>> fetchAllTemplates() async {
    // Previous version loaded without isActive filter — try that first.
    var all = await _fetchAllPages(activeOnly: false);
    if (all.isEmpty) {
      all = await _fetchAllPages(activeOnly: true);
    }

    final visible = all.where(_isVisibleTemplate).toList();
    debugPrint('📋 All templates loaded: ${visible.length}');
    return _dedupeById(visible);
  }

  /// One page — used by infinite scroll in Templates tab.
  static Future<TemplatePageResult> fetchTemplatePage(int page) async {
    final unfiltered = await _fetchSinglePage(page: page, activeOnly: false);
    if (unfiltered.items.isNotEmpty) {
      return TemplatePageResult(
        items: unfiltered.items.where(_isVisibleTemplate).toList(),
        totalPages: unfiltered.totalPages,
        currentPage: unfiltered.currentPage,
      );
    }

    final filtered = await _fetchSinglePage(page: page, activeOnly: true);
    return TemplatePageResult(
      items: filtered.items.where(_isVisibleTemplate).toList(),
      totalPages: filtered.totalPages,
      currentPage: filtered.currentPage,
    );
  }

  /// Templates for Add Push Notification dropdown (all visible templates).
  static Future<List<TemplateModel>> fetchSelectableTemplates() async {
    return fetchAllTemplates();
  }

  /// Merge two template lists without duplicates.
  static List<TemplateModel> mergeTemplates(
    List<TemplateModel> primary,
    List<TemplateModel> secondary,
  ) {
    return _dedupeById([...primary, ...secondary]);
  }

  @Deprecated('Use fetchSelectableTemplates')
  static Future<List<TemplateModel>> fetchApprovedTemplates() =>
      fetchSelectableTemplates();

  static Future<List<TemplateModel>> _fetchAllPages({
    required bool activeOnly,
  }) async {
    final token = AuthDataHelper.getToken();
    if (token.isEmpty) return [];

    final all = <TemplateModel>[];
    var page = 1;
    var totalPages = 1;

    while (page <= totalPages && page <= 30) {
      final batch = await _fetchSinglePage(page: page, activeOnly: activeOnly);
      if (batch.items.isEmpty) break;
      all.addAll(batch.items);
      totalPages = batch.totalPages > 0 ? batch.totalPages : 1;
      page = batch.currentPage + 1;
    }

    return all;
  }

  static Future<TemplatePageResult> _fetchSinglePage({
    required int page,
    required bool activeOnly,
  }) async {
    final token = AuthDataHelper.getToken();
    if (token.isEmpty) {
      return TemplatePageResult(items: const [], totalPages: 1, currentPage: page);
    }

    final params = <String>['page=$page'];
    if (activeOnly) params.add('isActive=true');

    final url = '${ApiConstants.getAllNotificationTemplates}?${params.join('&')}';
    final response = await HttpClientHelper.getWithBearer(url, token);

    debugPrint('📋 Template fetch $url → ${response.statusCode}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      return TemplatePageResult(items: const [], totalPages: 1, currentPage: page);
    }

    final parsed = _parseResponse(response.data);
    debugPrint('📋 Template page $page parsed ${parsed.items.length} item(s)');
    return TemplatePageResult(
      items: parsed.items,
      totalPages: parsed.totalPages > 0 ? parsed.totalPages : 1,
      currentPage: parsed.currentPage,
    );
  }

  static List<TemplateModel> _dedupeById(List<TemplateModel> list) {
    final byKey = <String, TemplateModel>{};
    for (final item in list) {
      final key =
          (item.templateId ?? item.id ?? '').trim().isNotEmpty
              ? (item.templateId ?? item.id)!.trim()
              : '${item.templateName}_${item.templateHeader}';
      byKey[key] = item;
    }
    return byKey.values.toList();
  }

  static _TemplatePage _parseResponse(dynamic raw) {
    final response = TemplateListResponse.parse(raw);
    return _TemplatePage(
      items: response.data ?? const [],
      totalPages: _readInt(response.totalPages, fallback: 1),
      currentPage: _readInt(response.currentPage, fallback: 1),
    );
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class TemplatePageResult {
  final List<TemplateModel> items;
  final int totalPages;
  final int currentPage;

  const TemplatePageResult({
    required this.items,
    required this.totalPages,
    required this.currentPage,
  });
}

class _TemplatePage {
  final List<TemplateModel> items;
  final int totalPages;
  final int currentPage;

  const _TemplatePage({
    required this.items,
    required this.totalPages,
    required this.currentPage,
  });
}
