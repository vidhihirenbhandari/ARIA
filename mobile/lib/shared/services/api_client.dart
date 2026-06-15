import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import 'local_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ApiClient(storage);
});

class ApiClient {
  late final Dio _dio;
  final LocalStorage _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      _LoggingInterceptor(),
      _RetryInterceptor(_dio),
    ]);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path,
          queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path,
          data: data,
          queryParameters: queryParameters,
          options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) =>
      _dio.delete<T>(path, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Stream<String> streamChat(String message, String conversationId) async* {
    final response = await _dio.post<ResponseBody>(
      '/chat/stream',
      data: {'message': message, 'conversation_id': conversationId},
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    await for (final chunk in stream) {
      final text = String.fromCharCodes(chunk);
      final lines = text.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data.isNotEmpty && data != '[DONE]') {
            yield data;
          }
        }
      }
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final LocalStorage _storage;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = _storage.getAuthToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try refresh token
      final refreshToken = _storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final dio = Dio();
          final response = await dio.post(
            '${AppConstants.baseUrl}/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          final newToken = response.data['access_token'] as String;
          await _storage.saveAuthToken(newToken);

          // Retry original request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final clonedRequest = await dio.fetch(opts);
          handler.resolve(clonedRequest);
          return;
        } catch (_) {
          await _storage.clearAll();
        }
      }
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // In production, use proper logging
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  int _retryCount = 0;

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_retryCount < AppConstants.maxRetries &&
        err.type == DioExceptionType.connectionTimeout) {
      _retryCount++;
      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        _retryCount = 0;
        return;
      } catch (e) {
        // Fall through to handler
      }
    }
    _retryCount = 0;
    handler.next(err);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}
