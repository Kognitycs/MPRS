class OrderDocumentModel {
  final String? fileType;
  final String? fileName;
  final String? internalUrl;
  final String? publicUrl;

  OrderDocumentModel({
    this.fileType,
    this.fileName,
    this.internalUrl,
    this.publicUrl,
  });

  factory OrderDocumentModel.fromDownloadUrl(
    String url, {
    String? fileName,
    String? fileType,
  }) {
    return OrderDocumentModel(
      fileType: fileType ?? 'PDF',
      fileName: fileName ?? 'Quote.pdf',
      publicUrl: url,
    );
  }

  /// Item from `GET /user/invoices/for/order` (`file_type`, `file_name`, URLs).
  factory OrderDocumentModel.fromOrderInvoice(Map<String, dynamic> json) {
    return OrderDocumentModel(
      fileType: _readString(
        json['file_type'] ??
            json['fileType'] ??
            json['File_Type__c'] ??
            json['type'],
      ),
      fileName: _readString(
        json['file_name'] ??
            json['fileName'] ??
            json['File_Name__c'] ??
            json['name'] ??
            json['title'],
      ),
      internalUrl: _readUrl(
        json['internal_url'] ??
            json['internalUrl'] ??
            json['Internal_Url__c'],
      ),
      publicUrl: _readUrl(
        json['public_url'] ??
            json['publicUrl'] ??
            json['Public_Url__c'] ??
            json['url'],
      ),
    );
  }

  factory OrderDocumentModel.fromJson(Map<String, dynamic> json) {
    final nested = json['document'] ?? json['invoice'] ?? json['file'];
    final source = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;

    return OrderDocumentModel(
      fileType: _readString(
        source['file_type'] ??
            source['fileType'] ??
            source['File_Type__c'] ??
            source['FileType'] ??
            source['type'] ??
            source['documentType'] ??
            source['Document_Type__c'],
      ),
      fileName: _readString(
        source['file_name'] ??
            source['fileName'] ??
            source['File_Name__c'] ??
            source['quoteName'] ??
            source['Name'] ??
            source['name'] ??
            source['title'],
      ),
      internalUrl: _readUrl(
        source['internal_url'] ??
            source['internalUrl'] ??
            source['Internal_Url__c'] ??
            source['internalURL'],
      ),
      publicUrl: _readUrl(
        source['pdfUrl'] ??
            source['pdf_url'] ??
            source['PDF_Url__c'] ??
            source['public_url'] ??
            source['publicUrl'] ??
            source['Public_Url__c'] ??
            source['publicURL'] ??
            source['url'] ??
            source['downloadUrl'] ??
            source['download_url'] ??
            source['fileUrl'] ??
            source['file_url'] ??
            source['DistributionPublicUrl'] ??
            source['VersionDataUrl'],
      ),
    );
  }

  /// pdfForQuote API item: `{ pdfUrl, quoteName, status, ... }`
  factory OrderDocumentModel.fromQuotePdfItem(Map<String, dynamic> json) {
    final quoteName = _readString(json['quoteName']);
    return OrderDocumentModel(
      fileType: _readString(
            json['file_type'] ??
                json['fileType'] ??
                json['documentType'] ??
                json['Document_Type__c'],
          ) ??
          'Quote',
      fileName: quoteName != null ? '$quoteName.pdf' : 'Quote.pdf',
      publicUrl: _readUrl(json['pdfUrl'] ?? json['pdf_url']),
    );
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _readUrl(dynamic value) {
    final text = _readString(value);
    if (text == null) return null;
    if (text.startsWith('http')) return text;
    if (text.startsWith('//')) return 'https:$text';
    // Salesforce sometimes returns a relative path — prefix with production domain.
    if (text.startsWith('/')) {
      return 'https://mprsrmsshippingandlogistics.file.force.com$text';
    }
    return null;
  }

  /// Title shown in UI — exact [file_type] from order invoice API.
  String get displayTitle {
    final type = fileType?.trim();
    if (type != null && type.isNotEmpty) return type;
    return 'Document';
  }

  /// Subtitle — file name below the title.
  String get displayFileName {
    if (fileName != null && fileName!.isNotEmpty) return fileName!;
    return '—';
  }

  String? get downloadUrl {
    final public = publicUrl;
    if (public != null && public.isNotEmpty) return public;
    return internalUrl;
  }

  bool get hasDownloadUrl =>
      downloadUrl != null && downloadUrl!.startsWith('http');

}
