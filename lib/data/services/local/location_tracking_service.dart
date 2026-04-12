import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../repositories/location_trace_repository.dart';
import 'preferences_service.dart';

/// Professional background location tracking service using a Foreground Service.
/// 
/// This replaces the standard Dart Timer with a persistent service that 
/// survives app termination by the operating system.
class LocationTrackingService {
  final LocationTraceRepository _traceRepo;
  final PreferencesService _prefsService;

  LocationTrackingService({
    required LocationTraceRepository traceRepo,
    required PreferencesService prefsService,
  })  : _traceRepo = traceRepo,
        _prefsService = prefsService;

  // ─── Lifecycle (Foreground & Background) ──────────────────

  Future<void> startTracking() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (isRunning) return;

    final parentId = await _prefsService.getParentId();
    if (parentId == null) return;

    final timezone = await TimezoneUtils.getLocalTimezone();

    // Store state in SharedPreferences for the background isolate
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tracking_parent_id', parentId);
    await prefs.setString('tracking_timezone', timezone);
    await prefs.setInt('tracking_interval_minutes', AppConfig.locationTrackingIntervalMinutes);
    await prefs.setInt('last_location_tick', 0); // Force immediate capture

    // Start the persistent foreground service
    await service.startService();
  }

  Future<void> stopTracking() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_parent_id');
    
  }

  // ─── Direct Marking (Foreground only) ──────────────────────

  /// Mark a point immediately when saving a reading (runs in foreground).
  Future<void> forceMarkReading(String nAbonado) async {
    await _markLocationLocal(read: true, nAbonado: nAbonado);
  }

  // ─── Helper for immediate capture ──────────────────────────

  Future<void> _markLocationLocal({required bool read, String? nAbonado}) async {
    try {
      final parentId = await _prefsService.getParentId();
      if (parentId == null) return;

      final permission = await Permission.locationWhenInUse.status;
      if (!permission.isGranted) return;

      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final timezone = await TimezoneUtils.getLocalTimezone();
      final readAt = Helpers.formatDateTimeForApi(DateTime.now());

      await _traceRepo.ensureTraceInfo(parentId, timezone);
      await _traceRepo.saveLocationPoint(
        parentId,
        position.latitude,
        position.longitude,
        read,
        nAbonado,
        readAt,
      );

    } catch (e) {
      debugPrint('[LocationTrackingService] Error: $e');
    }
  }
}
