import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/local/database_service.dart';
import '../services/remote/api_service.dart';

/// Generates a pseudo-random UUID v4 without external packages
String _generateUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Set version 4
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant bits
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int n, int len) =>
      n.toRadixString(16).padLeft(len * 2, '0').toLowerCase();

  return '${hex(bytes[0], 2)}${hex(bytes[1], 2)}${hex(bytes[2], 2)}${hex(bytes[3], 2)}'
      '-${hex(bytes[4], 2)}${hex(bytes[5], 2)}'
      '-${hex(bytes[6], 2)}${hex(bytes[7], 2)}'
      '-${hex(bytes[8], 2)}${hex(bytes[9], 2)}'
      '-${hex(bytes[10], 2)}${hex(bytes[11], 2)}${hex(bytes[12], 2)}${hex(bytes[13], 2)}${hex(bytes[14], 2)}${hex(bytes[15], 2)}';
}

class LocationTraceRepository {
  final DatabaseService _dbService;
  final ApiService _apiService;

  LocationTraceRepository({
    required DatabaseService dbService,
    required ApiService apiService,
  })  : _dbService = dbService,
        _apiService = apiService;

  /// Ensures a trace session exists for the period (generates UUID only once per period)
  Future<void> ensureTraceInfo(int periodId, String timezone) async {
    // generateUuid is only generated on first insert; subsequent calls preserve it
    final uuid = _generateUuid();
    await _dbService.saveLocationTraceInfo(periodId, timezone, uuid);
  }

  Future<void> saveLocationPoint(
    int periodId,
    double lat,
    double lon,
    bool read,
    String? nAbonado,
    String readAt,
  ) async {
    await _dbService.saveLocationPoint(periodId, lat, lon, read, nAbonado, readAt);
  }

  /// Syncs trace to the backend and clears local data on success.
  /// Returns true if successful or nothing to sync.
  Future<bool> syncTrace(int periodId) async {
    final traceData = await _dbService.getLocationTrace(periodId);
    if (traceData == null || (traceData['locations'] as List).isEmpty) {
      return true; // Nothing to sync
    }

    try {
      final res = await _apiService.postLocationTrace(traceData: traceData);
      if (res['status'] == 'OK') {
        // Successfully synced — clear local data immediately
        await _dbService.clearLocationTrace(periodId);
        return true;
      }
      return false;
    } catch (e) {
      // Failed — keep local data for next retry
      return false;
    }
  }

  Future<void> clearTrace(int periodId) async {
    await _dbService.clearLocationTrace(periodId);
  }
}
