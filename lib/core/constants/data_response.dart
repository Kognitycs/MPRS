class DataResponse<TModel> {
  dynamic success;
  String? message;
  TModel? body;
  int? code;

  DataResponse({this.message, this.body, this.code, this.success});

  factory DataResponse.fromJson(
      Map<String, dynamic> json, TModel Function(dynamic json) fromJsonT) {
    return DataResponse<TModel>(
      success: json['status'],
      code: json['status'] as int?,
      message: json['message'] as String?,
      body: fromJsonT(json.containsKey('body') ? json['body'] : json),
    );
  }
}