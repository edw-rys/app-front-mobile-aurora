import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/local/database_service.dart';
import '../../core/utils/helpers.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Initialize Database once
  try {
    final dbService = DatabaseService();

    Timer.periodic(const Duration(seconds: 15), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      
      final parentId = prefs.getInt('tracking_parent_id');
      final intervalMinutes = prefs.getInt('tracking_interval_minutes') ?? 3;
      final timezone = prefs.getString('tracking_timezone') ?? 'UTC';

      if (parentId == null) {
        service.stopSelf();
        return;
      }

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Aurora",
            content: "Trabajando en la ruta asignada",
          );
        }
      }

      final lastTick = prefs.getInt('last_location_tick') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - lastTick >= (intervalMinutes * 60 * 1000)) {
        await _captureAndSave(dbService, parentId, timezone);
        await prefs.setInt('last_location_tick', now);
      }
    });
  } catch (_) {
    // Fail silently in background
  }
}

Future<void> _captureAndSave(DatabaseService dbService, int parentId, String timezone) async {
  try {
    final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );

    final readAt = Helpers.formatDateTimeForApi(DateTime.now());
    
    await dbService.saveLocationTraceInfo(parentId, timezone, 'bg-session-v2');
    await dbService.saveLocationPoint(
      parentId,
      position.latitude,
      position.longitude,
      false,
      null,
      readAt,
    );
  } catch (_) {
    // Fail silently in background
  }
}

/// Professional background service utilities.
class BackgroundTrackingUtils {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking',
        initialNotificationTitle: 'Aurora Tracking',
        initialNotificationContent: 'Seguimiento de ruta activo',
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}
