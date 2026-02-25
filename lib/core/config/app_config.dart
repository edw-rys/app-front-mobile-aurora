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

  // ─── Image compression ────────────────────────────────────
  static const int imageMaxWidth = int.fromEnvironment(
    'IMAGE_MAX_WIDTH',
    defaultValue: 1280,
  );

  static const int imageMaxHeight = int.fromEnvironment(
    'IMAGE_MAX_HEIGHT',
    defaultValue: 960,
  );

  static const int imageQuality = int.fromEnvironment(
    'IMAGE_QUALITY',
    defaultValue: 85,
  );

  /// Target format: 'webp' or 'jpeg'
  static const String imageFormat = String.fromEnvironment(
    'IMAGE_FORMAT',
    defaultValue: 'webp',
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
