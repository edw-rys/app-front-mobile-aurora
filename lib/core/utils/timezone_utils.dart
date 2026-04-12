import 'package:flutter/services.dart';

/// Utility class to get the device timezone using a native MethodChannel.
/// 
/// This replaces the `flutter_timezone` package which was causing build errors.
class TimezoneUtils {
  static const MethodChannel _channel = MethodChannel('com.edinky.smartframedev.aurora/timezone');

  /// Fetches the IANA timezone ID from the device (e.g., "America/Guayaquil").
  static Future<String> getLocalTimezone() async {
    try {
      final String? timezone = await _channel.invokeMethod('getLocalTimezone');
      return timezone ?? 'UTC';
    } on PlatformException catch (_) {
      return 'UTC';
    }
  }
}
