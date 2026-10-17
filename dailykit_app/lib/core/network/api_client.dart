import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String tokenKey = 'dailykit_jwt_token';

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Attach Interceptor for Auth & Error Handling
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Log or transform network errors
          String errorMessage = 'A network error occurred. Please try again.';
          if (e.response != null && e.response?.data is Map) {
            final data = e.response?.data as Map;
            if (data.containsKey('message')) {
              errorMessage = data['message'];
            }
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Connection timed out. Please check your internet or server.';
          } else if (e.type == DioExceptionType.connectionError) {
            errorMessage = 'Unable to connect to server at ${ApiEndpoints.baseUrl}. Is the backend running?';
          }

          final customError = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: errorMessage,
            message: errorMessage,
          );
          return handler.next(customError);
        },
      ),
    );
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _storage.write(key: tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: tokenKey);
  }
}

