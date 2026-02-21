import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/endpoints.dart';
import '../../models/meter_model.dart';
import '../../models/user_model.dart';
import 'auth_interceptor.dart';
import '../local/preferences_service.dart';

/// Dio-based API service for remote data operations
class ApiService {
  late final Dio _dio;
  final PreferencesService _prefsService;
  final _authErrorController = StreamController<void>.broadcast();

  ApiService({required PreferencesService prefsService})
      : _prefsService = prefsService {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(AuthInterceptor(
      dio: _dio,
      prefsService: _prefsService,
      onAuthFailure: () => _authErrorController.add(null),
    ));

    if (AppConfig.isDebug) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Dio get dio => _dio;
  Stream<void> get authErrors => _authErrorController.stream;

  void dispose() {
    _authErrorController.close();
  }

  // ─── Auth ─────────────────────────────────────────────────

  /// Login and return tokens + user
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      Endpoints.login,
      data: {'email': email, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _dio.post(Endpoints.logout);
    } catch (_) {
      // Ignore logout errors - just clear local data
    }
  }

  /// Refresh token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      Endpoints.refresh,
      options: Options(
        headers: {'Authorization': 'Bearer $refreshToken'},
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get current user profile
  Future<UserModel> getProfile() async {
    final response = await _dio.post(Endpoints.me);
    final payload = response.data['payload'] as Map<String, dynamic>;
    return UserModel.fromJson(payload);
  }

  // ─── Meters ───────────────────────────────────────────────

  /// Get meters for a page
  /// Returns parsed response with items, count, pagination info
  Future<MetersResponse> getMeters(int page) async {
    final response = await _dio.get(
      Endpoints.metersAvailable,
      queryParameters: {'page': page},
    );
    return MetersResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Readings ─────────────────────────────────────────────

  /// Post a single reading via bulk endpoint (list with 1 item)
  Future<Map<String, dynamic>> postReadingBulk({
    required String date,
    required int readingPeriodId,
    required Map<String, dynamic> readingItem,
  }) async {
    final response = await _dio.post(
      Endpoints.readingsBulk,
      data: {
        'date': date,
        'reading_period_id': readingPeriodId,
        'list': [readingItem],
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Post multiple readings via bulk endpoint
  Future<Map<String, dynamic>> postReadingsBulk({
    required String date,
    required int readingPeriodId,
    required List<Map<String, dynamic>> readings,
  }) async {
    final response = await _dio.post(
      Endpoints.readingsBulk,
      data: {
        'date': date,
        'reading_period_id': readingPeriodId,
        'list': readings,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Finish reading period
  Future<Map<String, dynamic>> finishPeriod(int readingPeriodId) async {
    final response = await _dio.post(
      Endpoints.finishPeriod,
      data: {
        'reading_period_id': readingPeriodId,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

/// Parsed response from GET /meters/available
class MetersResponse {
  final int? parentId;
  final List<MeterModel> items;
  final int countItems;
  final int currentPage;
  final int lastPage;
  final int? numberPaginate;
  final Map<String, dynamic>? aditionalParams;

  const MetersResponse({
    this.parentId,
    required this.items,
    required this.countItems,
    required this.currentPage,
    required this.lastPage,
    this.numberPaginate,
    this.aditionalParams,
  });

  factory MetersResponse.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>;
    final itemsList = (payload['items'] as List<dynamic>?) ?? [];

    return MetersResponse(
      parentId: payload['parent_id'] as int?,
      items: itemsList
          .map((e) => MeterModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      countItems: payload['count_items'] as int? ?? 0,
      currentPage: payload['current_page'] as int? ?? 1,
      lastPage: payload['last_page'] as int? ?? 1,
      numberPaginate: payload['number_paginate'] as int?,
      aditionalParams: payload['aditionalParams'] as Map<String, dynamic>?,
    );
  }

  /// Convenience getters for period info
  int? get periodId => aditionalParams?['period_id'] as int?;
  String? get startDate => aditionalParams?['start_date'] as String?;
  String? get endDate => aditionalParams?['end_date'] as String?;
  String? get period => aditionalParams?['period'] as String?;
  String? get status => aditionalParams?['status'] as String?;
}
