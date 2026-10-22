// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:dio/io.dart';
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart' as g;
// import 'package:get/route_manager.dart';
// import 'package:http_parser/http_parser.dart';
// import 'package:mime/mime.dart';
// import '../utils/progress_dialog.dart';
// import '../utils/snackbar_util.dart';
// import 'api_constants.dart';
// import 'db_helper.dart';
// import 'no_internet_page.dart';
//
// enum DioMethod { post, get, delete, put, patch }
//
// enum BodyType { formData, raw, json, multipart }
//
// class ApiRequest {
//   final String url;
//   final DioMethod method;
//   final Map<String, dynamic>? body;
//   final BodyType bodyType;
//   final Map<String, dynamic>? queryParameters;
//   // final CancelToken? cancelToken;
//
//   ApiRequest({
//     required this.url,
//     required this.method,
//     this.body,
//     this.bodyType = BodyType.formData,
//     this.queryParameters,
//     // this.cancelToken,
//   });
// }
//
// class BaseClient {
//   static final BaseClient _singleton = BaseClient._internal();
//   static late Dio _dio;
//
//   factory BaseClient() {
//     return _singleton;
//   }
//
//   BaseClient._internal() {
//     BaseOptions options = BaseOptions(
//       baseUrl: ApiConstants.baseUrl,
//       receiveTimeout: const Duration(seconds: 30),
//       connectTimeout: const Duration(seconds: 30),
//     );
//
//     _dio = Dio(options);
//
//     if (!kIsWeb) {
//       (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
//         final client = HttpClient(
//           context: SecurityContext(withTrustedRoots: false),
//         );
//         client.badCertificateCallback =
//             (X509Certificate cert, String host, int port) => true;
//         return client;
//       };
//     }
//
//     // Allow invalid SSL certificates (for dev/testing)
//     (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
//       final client = HttpClient(
//         context: SecurityContext(withTrustedRoots: false),
//       );
//       client.badCertificateCallback =
//           (X509Certificate cert, String host, int port) => true;
//       return client;
//     };
//
//     _dio.interceptors.clear();
//     _dio.interceptors.add(_LoggingInterceptor());
//   }
//
//   static Map<String, dynamic> _getHeaderToken() {
//     String? token = DbHelper().getUserToken();
//     Map<String, dynamic> headers = {
//       ...AppSecrets.apiKeyHeaders,
//     };
//     if ((token ?? "").isNotEmpty) {
//       headers['Authorization'] = 'Bearer $token';
//     }
//     return headers;
//   }
//
//   Future<dynamic> handleRequest(ApiRequest apiRequest) async {
//     bool isOnline = await hasNetwork();
//     if (!isOnline) {
//       g.Get.to(
//         () => NoInternetPage(
//           callBack: (apiRequest) {
//             handleRequest(apiRequest);
//           },
//           apiRequest: apiRequest,
//         ),
//       );
//       return;
//     }
//     Response response;
//     final (data, resolvedContentType) = _handlePostRequest(apiRequest);
//
//     Options options = Options(
//       contentType: resolvedContentType ?? Headers.multipartFormDataContentType,
//       headers: _getHeaderToken(),
//     );
//
//     switch (apiRequest.method) {
//       case DioMethod.post:
//         response = await _dio.post(
//           apiRequest.url,
//           data: data,
//           queryParameters: apiRequest.queryParameters,
//           options: options,
//           // cancelToken: apiRequest.cancelToken,
//         );
//         break;
//       case DioMethod.get:
//         response = await _dio.get(
//           apiRequest.url,
//           queryParameters: apiRequest.queryParameters ?? apiRequest.body,
//           options: options,
//           // cancelToken: apiRequest.cancelToken,
//         );
//         break;
//       case DioMethod.put:
//         response = await _dio.put(
//           apiRequest.url,
//           data: data,
//           queryParameters: apiRequest.queryParameters,
//           options: options,
//           // cancelToken: apiRequest.cancelToken,
//         );
//         break;
//       case DioMethod.delete:
//         response = await _dio.delete(
//           apiRequest.url,
//           data: data,
//           queryParameters: apiRequest.queryParameters,
//           options: options,
//           // cancelToken: apiRequest.cancelToken,
//         );
//         break;
//       case DioMethod.patch:
//         response = await _dio.patch(
//           apiRequest.url,
//           data: data,
//           queryParameters: apiRequest.queryParameters,
//           options: options,
//           // cancelToken: apiRequest.cancelToken,
//         );
//         break;
//     }
//
//     return response.data;
//   }
//
//   Future<MultipartFile> getMultipartImage({required String path}) async {
//     final mimeType = lookupMimeType(path);
//     return await MultipartFile.fromFile(
//       path,
//       filename: path.split('/').last,
//       contentType: MediaType(
//         mimeType?.split('/').first ?? '',
//         mimeType?.split('/').last ?? '',
//       ),
//     );
//   }
//
//   static (dynamic, String?) _handlePostRequest(ApiRequest apiRequest) {
//     dynamic data;
//     String? contentType;
//
//     switch (apiRequest.bodyType) {
//       case BodyType.raw:
//         data = apiRequest.body ?? {};
//         contentType = Headers.jsonContentType;
//         break;
//       case BodyType.json:
//         data = apiRequest.body ?? {};
//         contentType = Headers.jsonContentType;
//         break;
//       case BodyType.multipart:
//         data = apiRequest.body ?? {};
//         contentType = Headers.multipartFormDataContentType;
//         break;
//       case BodyType.formData:
//         data = FormData.fromMap(apiRequest.body ?? {});
//         contentType = Headers.multipartFormDataContentType;
//         // contentType = Headers.multipartFormDataContentType;
//         break;
//     }
//
//     return (data, contentType);
//   }
//
//   static Future<bool> hasNetwork() async {
//     try {
//       final result = await InternetAddress.lookup('google.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
// }
//
// class _LoggingInterceptor extends Interceptor {
//   String _printPrettyJson(Object object) {
//     try {
//       Map jsonMapped = json.decode(json.encode(object));
//       JsonEncoder encoder = const JsonEncoder.withIndent('  ');
//       return encoder.convert(jsonMapped);
//     } catch (_) {
//       return object.toString();
//     }
//   }
//
//   @override
//   void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
//     debugPrint(
//       "--> ${options.method.toUpperCase()} ${options.baseUrl}${options.path}",
//     );
//     debugPrint("Headers: ${options.headers}");
//     debugPrint("Query Parameters: ${options.queryParameters}");
//     if (options.data != null) {
//       if (options.data is FormData) {
//         final formData = options.data as FormData;
//         debugPrint("Form Data Fields: ${formData.fields}");
//         debugPrint("Form Data Files: ${formData.files}");
//       } else {
//         debugPrint("Body: ${_printPrettyJson(options.data)}");
//       }
//     }
//     return handler.next(options);
//   }
//
//   @override
//   void onResponse(Response response, ResponseInterceptorHandler handler) {
//     debugPrint(
//       "${response.statusCode} ${response.requestOptions.baseUrl}${response.requestOptions.path}",
//     );
//     log("Response: ${response.data}");
//     debugPrint("<-- END HTTP");
//     return handler.next(response);
//   }
//
//   @override
//   void onError(DioException err, ErrorInterceptorHandler handler) async {
//     debugPrint("❗️ Error => ${err.message}");
//
//     final response = err.response;
//     final requestOptions = err.requestOptions;
//
//     final url = "${requestOptions.baseUrl}${requestOptions.path}";
//     debugPrint("❗️ Request URL => ${url.isNotEmpty ? url : 'Unknown URL'}");
//
//     if (err.response == null) {
//       //  Utils.showErrorSnackBar("Something went wrong");
//       ProgressLoader.hide(Get.context!);
//       return;
//     }
//
//     // Hide any loading indicators
//     ProgressLoader.hide(Get.context!);
//
//     // Handle retry logic for null response, network error, timeout, etc.
//     if (response == null) {
//       debugPrint("🔁 Retrying request...");
//       return;
//     }
//
//     // Session expired or authorization issues
//     if (response.statusCode == 403 ||
//         (response.statusCode == 401 &&
//             "${response.data['message'] ?? ""}".contains("Unauthorized"))) {
//       // DbHelper.clearWithRememberMe();
//       // g.Get.offAllNamed(Routes.login);
//       showSnackBar(Get.context!, "Session Expired!");
//
//       return;
//     }
//
//     // Show appropriate messages for known error types
//     if (err.type == DioExceptionType.unknown) {
//       showSnackBar(Get.context!, "Something went wrong?");
//
//     } else if (err.type == DioExceptionType.connectionError) {
//       showSnackBar(Get.context!, "Connection Error");
//
//     } else if (err.type == DioExceptionType.receiveTimeout) {
//       showSnackBar(Get.context!, "Receive Time");
//
//     }
//
//     return handler.next(err);
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' as g;
import 'package:get/route_manager.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../utils/progress_dialog.dart';
import '../utils/snackbar_util.dart';
import 'api_constants.dart';
import 'db_helper.dart';
import 'no_internet_page.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/app_secrets.dart';
import 'package:mprs_android/core/auth_data_helper.dart';

enum DioMethod { post, get, delete, put, patch }

enum BodyType { formData, raw, json, multipart }

class ApiRequest {
  final String url;
  final DioMethod method;
  final Map<String, dynamic>? body;
  final BodyType bodyType;
  final Map<String, dynamic>? queryParameters;

  /// When true, 404/403 on this request are not logged as errors (inbox fallbacks).
  final bool silent;
  // final CancelToken? cancelToken;

  ApiRequest({
    required this.url,
    required this.method,
    this.body,
    this.bodyType = BodyType.formData,
    this.queryParameters,
    this.silent = false,
    // this.cancelToken,
  });
}

class BaseClient {
  static final BaseClient _singleton = BaseClient._internal();
  static late Dio _dio;

  factory BaseClient() {
    return _singleton;
  }

  BaseClient._internal() {
    BaseOptions options = BaseOptions(
      //baseUrl: ApiConstants.baseUrl,
      receiveTimeout: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 30),
    );

    _dio = Dio(options);

    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient(
          context: SecurityContext(withTrustedRoots: false),
        );
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }

    // Allow invalid SSL certificates (for dev/testing)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient(
        context: SecurityContext(withTrustedRoots: false),
      );
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };

    _dio.interceptors.clear();
    _dio.interceptors.add(_TokenRefreshInterceptor(_dio));
    _dio.interceptors.add(_LoggingInterceptor());
  }

  static Map<String, dynamic> _getHeaderToken() {
    String? token = DbHelper().getUserToken();
    Map<String, dynamic> headers = {
      ...AppConfig.apiHeaders,
      ...AppSecrets.apiKeyHeaders,
    };
    if ((token ?? "").isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> handleRequest(ApiRequest apiRequest) async {
    bool isOnline = await hasNetwork();
    if (!isOnline) {
      g.Get.to(
        () => NoInternetPage(
          callBack: (apiRequest) {
            handleRequest(apiRequest);
          },
          apiRequest: apiRequest,
        ),
      );
      return;
    }
    Response response;
    final (data, resolvedContentType) = _handlePostRequest(apiRequest);

    Options options = Options(
      contentType: resolvedContentType ?? Headers.multipartFormDataContentType,
      headers: _getHeaderToken(),
      extra: {if (apiRequest.silent) 'silent': true},
    );

    switch (apiRequest.method) {
      case DioMethod.post:
        response = await _dio.post(
          apiRequest.url,
          data: data,
          queryParameters: apiRequest.queryParameters,
          options: options,
          // cancelToken: apiRequest.cancelToken,
        );
        break;
      case DioMethod.get:
        response = await _dio.get(
          apiRequest.url,
          queryParameters: apiRequest.queryParameters ?? apiRequest.body,
          options: options,
          // cancelToken: apiRequest.cancelToken,
        );
        break;
      case DioMethod.put:
        response = await _dio.put(
          apiRequest.url,
          data: data,
          queryParameters: apiRequest.queryParameters,
          options: options,
          // cancelToken: apiRequest.cancelToken,
        );
        break;
      case DioMethod.delete:
        response = await _dio.delete(
          apiRequest.url,
          data: data,
          queryParameters: apiRequest.queryParameters,
          options: options,
          // cancelToken: apiRequest.cancelToken,
        );
        break;
      case DioMethod.patch:
        response = await _dio.patch(
          apiRequest.url,
          data: data,
          queryParameters: apiRequest.queryParameters,
          options: options,
          // cancelToken: apiRequest.cancelToken,
        );
        break;
    }

    return response.data;
  }

  Future<MultipartFile> getMultipartImage({required String path}) async {
    final mimeType = lookupMimeType(path);
    return await MultipartFile.fromFile(
      path,
      filename: path.split('/').last,
      contentType: MediaType(
        mimeType?.split('/').first ?? '',
        mimeType?.split('/').last ?? '',
      ),
    );
  }

  static (dynamic, String?) _handlePostRequest(ApiRequest apiRequest) {
    dynamic data;
    String? contentType;

    switch (apiRequest.bodyType) {
      case BodyType.raw:
        data = apiRequest.body ?? {};
        contentType = Headers.jsonContentType;
        break;
      case BodyType.json:
        data = apiRequest.body ?? {};
        contentType = Headers.jsonContentType;
        break;
      case BodyType.multipart:
        data = apiRequest.body ?? {};
        contentType = Headers.multipartFormDataContentType;
        break;
      case BodyType.formData:
        data = FormData.fromMap(apiRequest.body ?? {});
        contentType = Headers.multipartFormDataContentType;
        // contentType = Headers.multipartFormDataContentType;
        break;
    }

    return (data, contentType);
  }

  static Future<bool> hasNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}

class _LoggingInterceptor extends Interceptor {
  String _printPrettyJson(Object object) {
    try {
      Map jsonMapped = json.decode(json.encode(object));
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      return encoder.convert(jsonMapped);
    } catch (_) {
      return object.toString();
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
      "--> ${options.method.toUpperCase()} ${options.baseUrl}${options.path}",
    );
    debugPrint("Headers: ${options.headers}");
    debugPrint("Query Parameters: ${options.queryParameters}");
    if (options.data != null) {
      if (options.data is FormData) {
        final formData = options.data as FormData;
        debugPrint("Form Data Fields: ${formData.fields}");
        debugPrint("Form Data Files: ${formData.files}");
      } else {
        debugPrint("Body: ${_printPrettyJson(options.data)}");
      }
    }
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      "${response.statusCode} ${response.requestOptions.baseUrl}${response.requestOptions.path}",
    );
    log("Response: ${response.data}");
    debugPrint("<-- END HTTP");
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final silent = err.requestOptions.extra['silent'] == true;
    if (!silent) {
      debugPrint("❗️ Error => ${err.message}");

      final requestOptions = err.requestOptions;
      final url = "${requestOptions.baseUrl}${requestOptions.path}";
      debugPrint("❗️ Request URL => ${url.isNotEmpty ? url : 'Unknown URL'}");
    }

    final response = err.response;

    if (err.response == null) {
      ProgressLoader.hide(Get.context!);
      return;
    }

    ProgressLoader.hide(Get.context!);

    if (response == null) return;

    // TOKEN_EXPIRED is handled by _TokenRefreshInterceptor above — skip here
    String message = "";

    if (response.data is Map<String, dynamic>) {
      message = response.data['message']?.toString() ?? "";
    } else {
      message = response.data?.toString() ?? "";
    }

    if (response.statusCode == 401 && message == 'TOKEN_EXPIRED') {
      return handler.next(err);
    }

    if (!silent &&
        (response.statusCode == 403 ||
            (response.statusCode == 401 && message.contains("Unauthorized")))) {
      showSnackBar(Get.context!, "Session Expired!");
      return;
    }

    if (!silent) {
      if (err.type == DioExceptionType.unknown) {
        showSnackBar(Get.context!, "Something went wrong");
      } else if (err.type == DioExceptionType.connectionError) {
        showSnackBar(Get.context!, "Connection Error");
      } else if (err.type == DioExceptionType.receiveTimeout) {
        showSnackBar(Get.context!, "Request timed out");
      }
    }

    return handler.next(err);
  }
}

/// -------------------------------------------------------
/// Auto Token Refresh Interceptor
/// Catches 401 TOKEN_EXPIRED → calls GET /api/user/token
/// with the old expired token → saves new token → retries
/// -------------------------------------------------------
class _TokenRefreshInterceptor extends Interceptor {
  final Dio dio;
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
  _queue = [];

  _TokenRefreshInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;

    // Only handle 401 TOKEN_EXPIRED
    String message = "";

    if (response?.data is Map<String, dynamic>) {
      message = response?.data['message']?.toString() ?? "";
    } else {
      message = response?.data?.toString() ?? "";
    }
    if (response?.statusCode != 401 || message != 'TOKEN_EXPIRED') {
      return handler.next(err);
    }

    // Don't intercept the refresh call itself
    if (err.requestOptions.extra['isRefresh'] == true) {
      debugPrint("🔴 Refresh call also got 401 — forcing logout");
      _forceLogout();
      return handler.reject(err);
    }

    // Queue up concurrent requests while refresh is in progress
    if (_isRefreshing) {
      debugPrint(
        "⏳ Already refreshing — queuing request: ${err.requestOptions.path}",
      );
      _queue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;
    debugPrint("🔄 TOKEN_EXPIRED — attempting refresh...");

    final newToken = await _refreshToken();

    if (newToken != null) {
      debugPrint("✅ Token refreshed successfully");

      // Retry queued requests with new token
      for (final pending in _queue) {
        pending.options.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retryResponse = await dio.fetch(pending.options);
          pending.handler.resolve(retryResponse);
        } catch (e) {
          pending.handler.next(err);
        }
      }
      _queue.clear();

      // Retry the original failed request
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      try {
        final retryResponse = await dio.fetch(err.requestOptions);
        _isRefreshing = false;
        return handler.resolve(retryResponse);
      } catch (e) {
        _isRefreshing = false;
        return handler.next(err);
      }
    } else {
      debugPrint("🔴 Token refresh failed — logging out");
      _queue.clear();
      _isRefreshing = false;
      _forceLogout();
      return handler.reject(err);
    }
  }

  /// Calls GET /api/user/token with the expired token
  /// Server returns a fresh token
  Future<String?> _refreshToken() async {
    try {
      final expiredToken = DbHelper().getUserToken() ?? '';
      if (expiredToken.isEmpty) return null;

      final response = await dio.get(
        ApiConstants.refreshToken,
        options: Options(
          headers: {'Authorization': 'Bearer $expiredToken'},
          extra: {'isRefresh': true}, // prevents infinite loop
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // Extract token — adjust key if your API returns a different field name
        final newToken =
            data['token'] ?? data['accessToken'] ?? data['data']?['token'];

        if (newToken != null && newToken.toString().isNotEmpty) {
          // Save to both storage systems
          DbHelper().saveUserToken(newToken.toString());
          AuthDataHelper.saveUserToken(newToken.toString());
          debugPrint("💾 New token saved");
          return newToken.toString();
        }
      }
    } catch (e) {
      debugPrint("⚠️ _refreshToken error: $e");
    }
    return null;
  }

  void _forceLogout() {
    DbHelper().clearAll();
    AuthDataHelper.clearAllData();
    showSnackBar(Get.context!, "Session expired. Please login again.");
    Get.offAllNamed('/login'); // update if your login route name is different
  }
}
