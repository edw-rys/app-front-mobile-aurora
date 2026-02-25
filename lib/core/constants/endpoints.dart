import '../config/app_config.dart';

/// Centralized API endpoint paths
class Endpoints {
  Endpoints._();

  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Meters
  static const String metersAvailable = '/meters/available';
  static const String readingsBulk = '/meters/readings/bulk';
  static const String readingsImage = '/meters/readings/image';
  static const String finishPeriod = '/meters/readings/finish-period';
}
