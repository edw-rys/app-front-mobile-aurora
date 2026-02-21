/// App configuration from --dart-define-from-file
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const int notificationInterval = int.fromEnvironment(
    'NOTIFICATION_INTERVAL',
    defaultValue: 120,
  );

  static const bool isDebug = bool.fromEnvironment(
    'DEBUG',
    defaultValue: false,
  );

  static void validate() {
    if (apiBaseUrl.isEmpty) {
      throw Exception(
        'API_BASE_URL is required! '
        'Run with: flutter run --dart-define-from-file=env/dev.json',
      );
    }
  }
}
