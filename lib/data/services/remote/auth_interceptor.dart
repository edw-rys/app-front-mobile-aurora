import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/endpoints.dart';
import '../local/preferences_service.dart';

/// Dio interceptor for automatic token management
/// - Adds Bearer token to all requests
/// - Auto-refreshes on 401
/// - Clears auth data (but keeps readings) on refresh failure
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final PreferencesService _prefsService;
  final VoidCallback? onAuthFailure;
  bool _isRefreshing = false;

  AuthInterceptor({
    required Dio dio,
    required PreferencesService prefsService,
    this.onAuthFailure,
  })  : _dio = dio,
        _prefsService = prefsService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip adding token for login and refresh endpoints
    if (options.path == Endpoints.login || options.path == Endpoints.refresh) {
      return handler.next(options);
    }

    final token = await _prefsService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final responseData = err.response?.data;
    final String? message = responseData is Map ? responseData['message'] : null;

    final bool isUnauthenticated = err.response?.statusCode == 401 ||
        message == 'Unauthenticated.' ||
        message == 'Tu sesión ha expirado. Por favor ingrese nuevamente';

    if (isUnauthenticated &&
        err.requestOptions.path != Endpoints.login &&
        err.requestOptions.path != Endpoints.refresh &&
        !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _prefsService.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          await _forceLogout();
          onAuthFailure?.call();
          return handler.next(err);
        }

        // Create a new Dio instance for refresh with logging
        final refreshDio = Dio(BaseOptions(
          baseUrl: _dio.options.baseUrl,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $refreshToken',
          },
        ));

        if (AppConfig.isDebug) {
          refreshDio.interceptors.add(LogInterceptor(
            requestBody: true,
            responseBody: true,
          ));
        }

        final response = await refreshDio.post(Endpoints.refresh);
        final payload = response.data['payload'] as Map<String, dynamic>;

        final newAccessToken = payload['access_token'] as String;
        final newRefreshToken = payload['refresh_token'] as String;

        // Save new tokens
        await _prefsService.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        // Retry the original request with new token
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(err.requestOptions);
        _isRefreshing = false;
        return handler.resolve(retryResponse);
      } catch (refreshErr) {
        _isRefreshing = false;
        // Refresh failed → clear auth but KEEP readings
        await _forceLogout();
        onAuthFailure?.call();
        return handler.next(err);
      }
    }
    handler.next(err);
  }

  /// Clear auth data only - readings persist in SQLite
  Future<void> _forceLogout() async {
    await _prefsService.clearAuthData();
  }
}
