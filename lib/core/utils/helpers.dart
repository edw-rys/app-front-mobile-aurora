import 'dart:math';
import 'package:intl/intl.dart';

/// General utility helpers
class Helpers {
  Helpers._();

  /// Format meter number for display
  static String formatMeterNumber(String? nAbonado) {
    if (nAbonado == null || nAbonado.isEmpty) return 'N/A';
    return nAbonado;
  }

  /// Format date string to readable format
  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      if (dateStr.contains('-') && dateStr.length == 7) {
        // Format: "2025-10" → "Octubre 2025"
        final parts = dateStr.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final date = DateTime(year, month);
        return DateFormat('MMMM yyyy', 'es').format(date);
      }
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy', 'es').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Format a DateTime to API format
  static String formatDateTimeForApi(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  /// Format a DateTime to date-only API format
  static String formatDateForApi(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  /// Calculate consumption
  static int calculateConsumption(int? currentReading, int? previousReading) {
    return (currentReading ?? 0) - (previousReading ?? 0);
  }

  /// Get initials from name
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Retry mechanism with exponential backoff
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await apiCall();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  /// Calculate simple distance between two lat/lon points (Haversine)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Format percentage
  static String formatPercentage(int current, int total) {
    if (total == 0) return '0';
    return ((current / total) * 100).round().toString();
  }

  /// Get progress ratio
  static double getProgressRatio(int current, int total) {
    if (total == 0) return 0;
    return (current / total).clamp(0.0, 1.0);
  }
}
