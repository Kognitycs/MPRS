// import 'dart:developer';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:mprs_android/core/constants/db_helper.dart';
// import 'dart:convert';
//
// import 'package:mprs_android/model/api_response.dart';
//
// import '../core/auth_data_helper.dart';
// import '../core/constants/api_constants.dart';
// import '../model/common/user_data.dart';
//
// class HttpClientHelper {
//   static final _client = http.Client();
//
//   static Future<ApiResponse> getWithBearer(String url, String token) async {
//     return get(
//       url,
//       headers: {
//         'Authorization': 'Bearer $token',
//         'Accept': 'application/json',
//         'Content-Type': 'application/json',
//       },
//     );
//   }
//
//   static Future<ApiResponse> postWithBearer(
//     String url,
//     String token, {
//     Map<String, String>? headers,
//     Object? body,
//     Encoding? encoding,
//   }) async {
//     return _sendRequest(
//       () => _client.post(
//         Uri.parse(url),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Accept': 'application/json',
//         },
//         body: body,
//         encoding: encoding,
//       ),
//     );
//   }
//
//   static Future<ApiResponse> postWithBearerNew(
//     String url,
//     String token, {
//     Map<String, String>? headers,
//     Object? body,
//     Encoding? encoding,
//   }) async {
//     final mergedHeaders = {'Authorization': 'Bearer $token', ...?headers};
//
//     return _sendRequest(
//       () => _client.post(
//         Uri.parse(url),
//         headers: mergedHeaders,
//         body: body,
//         encoding: encoding,
//       ),
//     );
//   }
//
//   static Future<ApiResponse> patchWithMultipart(
//     String url,
//     String token, {
//     required Map<String, String> fields,
//     File? file,
//     String fileField = 'profile',
//   }) async {
//     try {
//       final request = http.MultipartRequest('PATCH', Uri.parse(url));
//
//       // Add headers
//       request.headers.addAll({
//         'Authorization': 'Bearer $token',
//         'Accept': 'application/json',
//       });
//
//       // Add text fields
//       request.fields.addAll(fields);
//
//       // Add file if available
//       if (file != null && file.existsSync()) {
//         // Debug log: file info
//         try {
//           print(
//             '📎 Attaching file for multipart: field=$fileField, path=${file.path}',
//           );
//         } catch (_) {}
//         // Try to guess mime type from file extension
//         final path = file.path.toLowerCase();
//         String mime = 'application/octet-stream';
//         if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
//           mime = 'image/jpeg';
//         if (path.endsWith('.png')) mime = 'image/png';
//         if (path.endsWith('.gif')) mime = 'image/gif';
//         final parts = mime.split('/');
//         try {
//           print('📎 Using contentType: $mime');
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               fileField,
//               file.path,
//               contentType: MediaType(parts[0], parts[1]),
//             ),
//           );
//         } catch (e) {
//           print('⚠️ Failed to set contentType on multipart file: $e');
//           request.files.add(
//             await http.MultipartFile.fromPath(fileField, file.path),
//           );
//         }
//       }
//
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);
//
//       // Decode response
//       Map<String, dynamic>? decoded;
//       try {
//         decoded = json.decode(response.body);
//       } catch (_) {
//         decoded = null;
//       }
//
//       String message = 'Something went wrong';
//       if (decoded != null && decoded['message'] != null) {
//         message = decoded['message'];
//       }
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       } else {
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       }
//     } on SocketException {
//       return ApiResponse(
//         statusCode: 0,
//         data: '',
//         message: 'No Internet connection',
//       );
//     } catch (e) {
//       return ApiResponse(
//         statusCode: 500,
//         data: '',
//         message: 'Unexpected error: $e',
//       );
//     }
//   }
//
//   static Future<ApiResponse> postWithMultipart(
//     String url, {
//     required Map<String, String> fields,
//     File? file,
//     String fileField = 'profile',
//   }) async {
//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(url));
//
//       // Add headers
//       request.headers.addAll({'Accept': 'application/json'});
//
//       // Add text fields
//       request.fields.addAll(fields);
//
//       // Add file if available
//       if (file != null && file.existsSync()) {
//         try {
//           print(
//             '📎 Attaching file for multipart (post): field=$fileField, path=${file.path}',
//           );
//         } catch (_) {}
//         final path = file.path.toLowerCase();
//         String mime = 'application/octet-stream';
//         if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
//           mime = 'image/jpeg';
//         if (path.endsWith('.png')) mime = 'image/png';
//         if (path.endsWith('.gif')) mime = 'image/gif';
//         final parts = mime.split('/');
//         try {
//           print('📎 Using contentType: $mime');
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               fileField,
//               file.path,
//               contentType: MediaType(parts[0], parts[1]),
//             ),
//           );
//         } catch (e) {
//           print('⚠️ Failed to set contentType on multipart file (post): $e');
//           request.files.add(
//             await http.MultipartFile.fromPath(fileField, file.path),
//           );
//         }
//       }
//
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);
//
//       // Decode response
//       Map<String, dynamic>? decoded;
//       try {
//         decoded = json.decode(response.body);
//       } catch (_) {
//         decoded = null;
//       }
//
//       String message = 'Something went wrong';
//       if (decoded != null && decoded['message'] != null) {
//         message = decoded['message'];
//       }
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       } else {
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       }
//     } on SocketException {
//       return ApiResponse(
//         statusCode: 0,
//         data: '',
//         message: 'No Internet connection',
//       );
//     } catch (e) {
//       return ApiResponse(
//         statusCode: 500,
//         data: '',
//         message: 'Unexpected error: $e',
//       );
//     }
//   }
//
//   static Future<ApiResponse> postWithBearerMultipart(
//     String url,
//     String token, {
//     required Map<String, String> fields,
//     File? file,
//     String fileField = 'profile',
//     bool isBanner = false,
//   }) async {
//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(url));
//
//       // Add headers
//       request.headers.addAll({
//         'Authorization': 'Bearer $token',
//         'Accept': 'application/json',
//       });
//
//       // Add text fields
//       request.fields.addAll(fields);
//
//       // Add file if available
//       if (file != null && file.existsSync()) {
//         try {
//           print('📎 Attaching file for bearer multipart:path=${file.path}');
//         } catch (_) {}
//         final path = file.path.toLowerCase();
//         String mime = 'application/octet-stream';
//         if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
//           mime = 'image/jpeg';
//         if (path.endsWith('.png')) mime = 'image/png';
//         if (path.endsWith('.gif')) mime = 'image/gif';
//         final parts = mime.split('/');
//         final fieldName = isBanner ? "bannerImage" : fileField;
//         try {
//           print('📎 Using contentType: $mime');
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               fieldName,
//               file.path,
//               contentType: MediaType(parts[0], parts[1]),
//             ),
//           );
//         } catch (e) {
//           print('⚠️ Failed to set contentType on multipart file (bearer): $e');
//           request.files.add(
//             await http.MultipartFile.fromPath(fieldName, file.path),
//           );
//         }
//       }
//
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);
//
//       // Decode response
//       Map<String, dynamic>? decoded;
//       try {
//         decoded = json.decode(response.body);
//       } catch (_) {
//         decoded = null;
//       }
//
//       String message = 'Something went wrong';
//       if (decoded != null && decoded['message'] != null) {
//         message = decoded['message'];
//       }
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       } else {
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       }
//     } on SocketException {
//       return ApiResponse(
//         statusCode: 0,
//         data: '',
//         message: 'No Internet connection',
//       );
//     } catch (e) {
//       return ApiResponse(
//         statusCode: 500,
//         data: '',
//         message: 'Unexpected error: $e',
//       );
//     }
//   }
//
//   Future<void> fetchUserProfile() async {
//     try {
//       final token = AuthDataHelper.getToken();
//
//       final response = await HttpClientHelper.getWithBearer(
//         ApiConstants.profile,
//         token,
//       );
//
//       if (response.statusCode == 200) {
//         final decodedData = jsonDecode(response.data);
//         final userDataJson = decodedData['user'];
//         final userData = UserData.fromJson(userDataJson);
//
//         DbHelper().saveUserModel(userData);
//         AuthDataHelper.saveUserData(userData);
//
//         print("✅ Profile fetched and saved successfully");
//       } else {
//         print(
//           "❌ Error fetching profile: ${response.statusCode} - ${response.message}",
//         );
//       }
//     } catch (e) {
//       print("⚠️ Unexpected error in fetchUserProfile: $e");
//     }
//   }
//
//   static Future<ApiResponse> postWithApplicationJson(
//     String url, {
//     Map<String, String>? headers,
//     Object? body,
//     Encoding? encoding,
//   }) async {
//     return _sendRequest(
//       () => _client.post(
//         Uri.parse(url),
//         headers: headers,
//         body: body,
//         encoding: encoding,
//       ),
//     );
//   }
//
//   static Future<ApiResponse> patchWithBearer(
//     String url,
//     String token, {
//     Map<String, String>? headers,
//     Object? body,
//     Encoding? encoding,
//   }) async {
//     return _sendRequest(
//       () => _client.patch(
//         Uri.parse(url),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Accept': 'application/json',
//           'Content-Type': 'application/json',
//           ...?headers,
//         },
//         body: body,
//         encoding: encoding,
//       ),
//     );
//   }
//
//   static Future<ApiResponse> deleteWithBearer(
//     String url,
//     String token, {
//     Map<String, String>? headers,
//   }) async {
//     return _sendRequest(
//       () => _client.delete(
//         Uri.parse(url),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Accept': 'application/json',
//           'Content-Type': 'application/json',
//           ...?headers,
//         },
//       ),
//     );
//   }
//
//   static Future<ApiResponse> get(
//     String url, {
//     Map<String, String>? headers,
//   }) async {
//     return _sendRequest(() => _client.get(Uri.parse(url), headers: headers));
//   }
//
//   static Future<ApiResponse> post(
//     String url, {
//     Map<String, String>? headers,
//     Object? body,
//     Encoding? encoding,
//   }) async {
//     return _sendRequest(
//       () => _client.post(
//         Uri.parse(url),
//         headers: headers,
//         body: body,
//         encoding: encoding,
//       ),
//     );
//   }
//
//   static Future<ApiResponse> _sendRequest(
//     Future<http.Response> Function() requestFn,
//   ) async {
//     try {
//       print("➡️ Sending HTTP request...");
//       final response = await requestFn();
//       print("✅ Received response:  fcm token  ${response.statusCode}");
//       log("📦 Response body: ${response.body}");
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         return _handleResponse(response);
//       } else {
//         String message = "Something went wrong";
//         try {
//           final decoded = json.decode(response.body);
//           if (decoded is Map<String, dynamic> && decoded['message'] != null) {
//             message = decoded['message'];
//           }
//         } catch (e) {
//           // Ignore JSON parse errors, use default message
//         }
//
//         return ApiResponse(
//           statusCode: response.statusCode,
//           data: response.body,
//           message: message,
//         );
//       }
//     } on SocketException {
//       return ApiResponse(
//         statusCode: 0,
//         data: "",
//         message: "No Internet connection",
//       );
//     } on HttpException {
//       return ApiResponse(statusCode: 500, data: "", message: "HTTP error");
//     } on FormatException {
//       return ApiResponse(
//         statusCode: 500,
//         data: "",
//         message: "Bad response format",
//       );
//     } catch (e) {
//       return ApiResponse(
//         statusCode: 500,
//         data: "",
//         message: "Unexpected error: $e",
//       );
//     }
//   }
//
//   static ApiResponse _handleResponse(http.Response response) {
//     return ApiResponse(statusCode: response.statusCode, data: response.body);
//   }
// }

import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'dart:convert';

import 'package:mprs_android/model/api_response.dart';

import '../core/app_config.dart';
import '../core/app_secrets.dart';
import '../core/auth_data_helper.dart';
import '../core/utils/api_error_utils.dart';
import '../model/common/user_data.dart';

class HttpClientHelper {
  static final _client = http.Client();

  static Map<String, String> bearerAppHeaders(String token) => {
        ...AppConfig.apiHeaders,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...AppSecrets.apiKeyHeaders,
      };

  /// Headers with only service API keys — no JWT. Used when we want to
  /// bypass JWT role restrictions (e.g. External user querying admin endpoints).
  static Map<String, String> apiKeysOnlyHeaders() => {
        ...AppConfig.apiHeaders,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...AppSecrets.apiKeyHeaders,
      };

  /// GET with only API-key headers — no Bearer token.
  static Future<ApiResponse> getWithApiKeysOnly(String url) async {
    return _sendRequest(
      () => _client.get(Uri.parse(url), headers: apiKeysOnlyHeaders()),
    );
  }

  /// PATCH with only API-key headers — no Bearer token.
  static Future<ApiResponse> patchWithApiKeysOnly(
    String url, {
    Object? body,
  }) async {
    return _sendRequest(
      () => _client.patch(
        Uri.parse(url),
        headers: apiKeysOnlyHeaders(),
        body: body,
      ),
    );
  }

  static Future<ApiResponse> getWithBearer(
    String url,
    String token, {
    Map<String, String>? headers,
  }) async {
    final baseHeaders = bearerAppHeaders(token);
    final mergedHeaders =
        headers == null ? baseHeaders : {...baseHeaders, ...headers};
    return _sendRequest(
      () => _client.get(Uri.parse(url), headers: mergedHeaders),
      retryWithToken: (newToken) => _client.get(
        Uri.parse(url),
        headers: {...bearerAppHeaders(newToken), ...?headers},
      ),
    );
  }

  static Future<ApiResponse> postWithBearer(
      String url,
      String token, {   // ← token is 2nd param, body is named
        Map<String, String>? headers,
        Object? body,
      }) async {
    return _sendRequest(
          () => _client.post(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        }),
        body: body,
      ),
    );
  }

  static Future<ApiResponse> postWithBearerNew(
      String url,
      String token, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
      }) async {
    final mergedHeaders = AppConfig.mergeApiHeaders({
      'Authorization': 'Bearer $token',
      ...?headers,
    });

    return _sendRequest(
          () => _client.post(
        Uri.parse(url),
        headers: mergedHeaders,
        body: body,
        encoding: encoding,
      ),
    );
  }

  static Future<ApiResponse> patchWithMultipart(
      String url,
      String token, {
        required Map<String, String> fields,
        File? file,
        String fileField = 'profile',
      }) async {
    try {
      final request = http.MultipartRequest('PATCH', Uri.parse(url));

      // Add headers
      request.headers.addAll(AppConfig.mergeApiHeaders({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }));

      // Add text fields
      request.fields.addAll(fields);

      // Add file if available
      if (file != null && file.existsSync()) {
        // Debug log: file info
        try {
          print(
            '📎 Attaching file for multipart: field=$fileField, path=${file.path}',
          );
        } catch (_) {}
        // Try to guess mime type from file extension
        final path = file.path.toLowerCase();
        String mime = 'application/octet-stream';
        if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
          mime = 'image/jpeg';
        if (path.endsWith('.png')) mime = 'image/png';
        if (path.endsWith('.gif')) mime = 'image/gif';
        final parts = mime.split('/');
        try {
          print('📎 Using contentType: $mime');
          request.files.add(
            await http.MultipartFile.fromPath(
              fileField,
              file.path,
              contentType: MediaType(parts[0], parts[1]),
            ),
          );
        } catch (e) {
          print('⚠️ Failed to set contentType on multipart file: $e');
          request.files.add(
            await http.MultipartFile.fromPath(fileField, file.path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Decode response
      Map<String, dynamic>? decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      String message = 'Something went wrong';
      if (decoded != null && decoded['message'] != null) {
        message = decoded['message'];
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      }
    } on SocketException {
      return ApiResponse(
        statusCode: 0,
        data: '',
        message: 'No Internet connection',
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: '',
        message: 'Unexpected error: $e',
      );
    }
  }

  static Future<ApiResponse> postWithMultipart(
      String url, {
        required Map<String, String> fields,
        File? file,
        String fileField = 'profile',
      }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers (same app keys as BaseClient / bearer requests)
      request.headers.addAll(AppConfig.mergeApiHeaders({
        'Accept': 'application/json',
        ...AppSecrets.apiKeyHeaders,
      }));

      // Add text fields
      request.fields.addAll(fields);

      // Add file if available
      if (file != null && file.existsSync()) {
        try {
          print(
            '📎 Attaching file for multipart (post): field=$fileField, path=${file.path}',
          );
        } catch (_) {}
        final path = file.path.toLowerCase();
        String mime = 'application/octet-stream';
        if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
          mime = 'image/jpeg';
        if (path.endsWith('.png')) mime = 'image/png';
        if (path.endsWith('.gif')) mime = 'image/gif';
        final parts = mime.split('/');
        try {
          print('📎 Using contentType: $mime');
          request.files.add(
            await http.MultipartFile.fromPath(
              fileField,
              file.path,
              contentType: MediaType(parts[0], parts[1]),
            ),
          );
        } catch (e) {
          print('⚠️ Failed to set contentType on multipart file (post): $e');
          request.files.add(
            await http.MultipartFile.fromPath(fileField, file.path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Decode response
      Map<String, dynamic>? decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      final message = parseApiErrorMessage(
        decoded ?? response.body,
        fallback: 'Something went wrong',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      }
    } on SocketException {
      return ApiResponse(
        statusCode: 0,
        data: '',
        message: 'No Internet connection',
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: '',
        message: 'Unexpected error: $e',
      );
    }
  }

  static Future<ApiResponse> postWithBearerMultipart(
      String url,
      String token, {
        required Map<String, String> fields,
        File? file,
        String fileField = 'profile',
        bool isBanner = false,
      }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers
      request.headers.addAll(AppConfig.mergeApiHeaders({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }));

      // Add text fields
      request.fields.addAll(fields);

      // Add file if available
      if (file != null && file.existsSync()) {
        try {
          print('📎 Attaching file for bearer multipart:path=${file.path}');
        } catch (_) {}
        final path = file.path.toLowerCase();
        String mime = 'application/octet-stream';
        if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
          mime = 'image/jpeg';
        if (path.endsWith('.png')) mime = 'image/png';
        if (path.endsWith('.gif')) mime = 'image/gif';
        final parts = mime.split('/');
        final fieldName = isBanner ? "bannerImage" : fileField;
        try {
          print('📎 Using contentType: $mime');
          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              file.path,
              contentType: MediaType(parts[0], parts[1]),
            ),
          );
        } catch (e) {
          print('⚠️ Failed to set contentType on multipart file (bearer): $e');
          request.files.add(
            await http.MultipartFile.fromPath(fieldName, file.path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Decode response
      Map<String, dynamic>? decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      String message = 'Something went wrong';
      if (decoded != null && decoded['message'] != null) {
        message = decoded['message'];
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      }
    } on SocketException {
      return ApiResponse(
        statusCode: 0,
        data: '',
        message: 'No Internet connection',
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        data: '',
        message: 'Unexpected error: $e',
      );
    }
  }

  Future<void> fetchUserProfile() async {
    try {
      final token = AuthDataHelper.getToken();

      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.profile,
        token,
      );

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.data);
        final userDataJson = decodedData['user'];
        final userData = UserData.fromJson(userDataJson);

        DbHelper().saveUserModel(userData);
        AuthDataHelper.saveUserData(userData);

        print("✅ Profile fetched and saved successfully");
      } else {
        print(
          "❌ Error fetching profile: ${response.statusCode} - ${response.message}",
        );
      }
    } catch (e) {
      print("⚠️ Unexpected error in fetchUserProfile: $e");
    }
  }

  static Future<ApiResponse> postWithApplicationJson(
      String url, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
      }) async {
    return _sendRequest(
          () => _client.post(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders(headers),
        body: body,
        encoding: encoding,
      ),
    );
  }

  static Future<ApiResponse> patchWithBearer(
      String url,
      String token, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
      }) async {
    return _sendRequest(
          () => _client.patch(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        }),
        body: body,
        encoding: encoding,
      ),
    );
  }

  static Future<ApiResponse> deleteWithBearer(
      String url,
      String token, {
        Map<String, String>? headers,
      }) async {
    return _sendRequest(
          () => _client.delete(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        }),
      ),
    );
  }

  static Future<ApiResponse> get(
      String url, {
        Map<String, String>? headers,
      }) async {
    return _sendRequest(
      () => _client.get(Uri.parse(url), headers: AppConfig.mergeApiHeaders(headers)),
    );
  }

  static Future<ApiResponse> post(
      String url, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
      }) async {
    return _sendRequest(
          () => _client.post(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders(headers),
        body: body,
        encoding: encoding,
      ),
    );
  }

  static Future<ApiResponse> _sendRequest(
      Future<http.Response> Function() requestFn, {
        Future<http.Response> Function(String newToken)? retryWithToken,
      }) async {
    try {
      final response = await requestFn();
      final code = response.statusCode;
      if (code == 200 || code == 201) {
        print("✅ HTTP $code");
      } else {
        print("❌ HTTP $code ${Uri.tryParse(response.request?.url.toString() ?? '')?.path ?? ''}");
      }
      log("📦 Response body: ${response.body}");

      // ── TOKEN_EXPIRED: try refresh then retry once ──────────────────────
      if (response.statusCode == 401) {
        try {
          final decoded = json.decode(response.body);
          if (decoded['message'] == 'TOKEN_EXPIRED' && retryWithToken != null) {
            print("🔄 TOKEN_EXPIRED — refreshing via HttpClientHelper...");
            final newToken = await _refreshToken();
            if (newToken != null) {
              print("✅ Token refreshed — retrying original request...");
              final retryResponse = await retryWithToken(newToken);
              log("📦 Retry response body: ${retryResponse.body}");
              return _handleResponse(retryResponse);
            } else {
              print("🔴 Refresh failed — cannot retry");
            }
          }
        } catch (_) {}
      }
      // ────────────────────────────────────────────────────────────────────

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _handleResponse(response);
      } else {
        String message = "Something went wrong";
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic> && decoded['message'] != null) {
            message = decoded['message'];
          }
        } catch (e) {}

        return ApiResponse(
          statusCode: response.statusCode,
          data: response.body,
          message: message,
        );
      }
    } on SocketException {
      return ApiResponse(statusCode: 0, data: "", message: "No Internet connection");
    } on HttpException {
      return ApiResponse(statusCode: 500, data: "", message: "HTTP error");
    } on FormatException {
      return ApiResponse(statusCode: 500, data: "", message: "Bad response format");
    } catch (e) {
      return ApiResponse(statusCode: 500, data: "", message: "Unexpected error: $e");
    }
  }

  /// Calls GET /api/user/token with the expired token → returns new token string
  static Future<String?> _refreshToken() async {
    try {
      final expiredToken = DbHelper().getUserToken() ?? '';
      if (expiredToken.isEmpty) return null;

      final response = await _client.get(
        Uri.parse(ApiConstants.refreshToken),
        headers: AppConfig.mergeApiHeaders({
          'Authorization': 'Bearer $expiredToken',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['token'] ?? data['accessToken'] ?? data['data']?['token'];
        if (newToken != null && newToken.toString().isNotEmpty) {
          DbHelper().saveUserToken(newToken.toString());
          AuthDataHelper.saveUserToken(newToken.toString());
          print("💾 HttpClientHelper: new token saved");
          return newToken.toString();
        }
      }
    } catch (e) {
      print("⚠️ HttpClientHelper _refreshToken error: $e");
    }
    return null;
  }

  static ApiResponse _handleResponse(http.Response response) {
    return ApiResponse(statusCode: response.statusCode, data: response.body);
  }
}