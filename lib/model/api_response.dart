class ApiResponse {
  final int statusCode;
  final String data;
  final String? message;

  ApiResponse({required this.statusCode, required this.data, this.message});
}