import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/di/injection.dart';
import '../../core/utils/helpers.dart';
import '../../core/exceptions/dio_exception_handler.dart';
import '../../data/models/meter_model.dart';
import '../../data/models/reading_model.dart';
import '../../data/repositories/meter_repository.dart';
import '../../data/services/local/preferences_service.dart';

/// Meters state
class MetersState {
  final bool isLoading;
  final bool isDownloading;
  final bool downloadComplete;
  final bool isWorkStarted;
  final List<MeterModel> meters;
  final List<SectorModel> sectors;
  final Map<String, ReadingModel> readings;
  final Map<String, int> stats;
  final String? error;
  final int downloadProgress;
  final int downloadTotal;
  final int downloadedCount;
  final bool isUpdating;
  final String? updateStatus;

  const MetersState({
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadComplete = false,
    this.isWorkStarted = false,
    this.meters = const [],
    this.sectors = const [],
    this.readings = const {},
    this.stats = const {},
    this.error,
    this.downloadProgress = 0,
    this.downloadTotal = 0,
    this.downloadedCount = 0,
    this.isUpdating = false,
    this.updateStatus,
  });

  MetersState copyWith({
    bool? isLoading,
    bool? isDownloading,
    bool? downloadComplete,
    bool? isWorkStarted,
    List<MeterModel>? meters,
    List<SectorModel>? sectors,
    Map<String, ReadingModel>? readings,
    Map<String, int>? stats,
    String? error,
    int? downloadProgress,
    int? downloadTotal,
    int? downloadedCount,
    bool? isUpdating,
    String? updateStatus,
  }) {
    return MetersState(
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadComplete: downloadComplete ?? this.downloadComplete,
      isWorkStarted: isWorkStarted ?? this.isWorkStarted,
      meters: meters ?? this.meters,
      sectors: sectors ?? this.sectors,
      readings: readings ?? this.readings,
      stats: stats ?? this.stats,
      error: error,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadTotal: downloadTotal ?? this.downloadTotal,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      isUpdating: isUpdating ?? this.isUpdating,
      updateStatus: updateStatus ?? this.updateStatus,
    );
  }

  /// Filtered meters by status
  List<MeterModel> get pendingMeters =>
      meters.where((m) => !readings.containsKey(m.nAbonado)).toList();

  List<MeterModel> get readMeters =>
      meters.where((m) => readings.containsKey(m.nAbonado)).toList();
      
  List<MeterModel> get metersWithErrors =>
      meters.where((m) => readings[m.nAbonado]?.syncError != null).toList();

  /// Progress percentage
  int get progressPercent {
    if (meters.isEmpty) return 0;
    return ((readMeters.length / meters.length) * 100).round();
  }

  /// Total counts from readings map
  int get totalRead => readMeters.length;
  int get totalPending => pendingMeters.length;
}

/// Validation result: split valid and invalid readings
class ReadingValidationResult {
  final List<ReadingModel> valid;
  final List<ReadingModel> invalid;

  const ReadingValidationResult({required this.valid, required this.invalid});

  int get validCount => valid.length;
  int get invalidCount => invalid.length;
  bool get hasErrors => invalid.isNotEmpty;
}

/// Meters state notifier
class MetersNotifier extends StateNotifier<MetersState> {
  final MeterRepository _meterRepo;
  final PreferencesService _prefsService;

  MetersNotifier({
    required MeterRepository meterRepo,
    required PreferencesService prefsService,
  })  : _meterRepo = meterRepo,
        _prefsService = prefsService,
        super(const MetersState());

  /// Load meters from local DB
  Future<void> loadMeters() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final meters = await _meterRepo.getLocalMeters();
      final currentReadings = await _meterRepo.getCurrentReadings();
      final readingMap = {for (final r in currentReadings) r.nAbonado: r};
      final stats = await _meterRepo.getReadingStats();
      final sectors = await _meterRepo.getLocalSectors();
      final isWorkStarted = await _prefsService.isWorkStarted();

      state = state.copyWith(
        isLoading: false,
        meters: meters,
        sectors: sectors,
        readings: readingMap,
        stats: stats,
        isWorkStarted: isWorkStarted,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Mark work as started locally (no API call)
  Future<void> startWork() async {
    await _prefsService.setWorkStarted(true);
    state = state.copyWith(isWorkStarted: true);
  }

  /// Restore data: clear all local DB data + reset prefs + reset in-memory state
  Future<void> resetAllData() async {
    await _meterRepo.clearAllLocalData();
    await _prefsService.setWorkStarted(false);
    // Fully reset in-memory state so home screen immediately reflects empty state
    state = const MetersState();
  }

  /// Download all meters from API with page-by-page progress
  Future<void> downloadMeters() async {
    state = state.copyWith(
      isDownloading: true,
      downloadComplete: false,
      downloadProgress: 0,
      downloadTotal: 0,
      error: null,
    );
    try {
      final count = await _meterRepo.fetchAndSaveAllMeters(
        onProgress: (current, total) {
          state = state.copyWith(
            downloadProgress: current,
            downloadTotal: total,
          );
        },
      );
      state = state.copyWith(
        isDownloading: false,
        downloadComplete: true,
        downloadedCount: count,
      );
      await _prefsService.setWorkStarted(false);
      await Future.delayed(const Duration(milliseconds: 1500));
      await loadMeters();
      state = state.copyWith(downloadComplete: false);
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        downloadComplete: false,
        error: DioExceptionHandler.mapToString(e),
      );
      rethrow;
    }
  }

  /// Update meters with fresh data from API
  Future<void> updateMeters() async {
    state = state.copyWith(
      isUpdating: true,
      updateStatus: 'Conectando...',
      downloadProgress: 0,
      downloadTotal: 0,
      error: null,
    );
    try {
      await _meterRepo.updateAndSyncMeters(
        onProgressDownload: (current, total) {
          state = state.copyWith(
            downloadProgress: current,
            downloadTotal: total,
            updateStatus: 'Descargando página $current de $total...',
          );
        },
        onVerifying: () {
          state = state.copyWith(
            updateStatus: 'Verificando datos...',
          );
        },
      );
      
      state = state.copyWith(
        isUpdating: false,
        updateStatus: null,
      );
      
      await loadMeters();
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        updateStatus: null,
        error: DioExceptionHandler.mapToString(e),
      );
      rethrow;
    }
  }

  /// Reset download state
  void resetDownload() {
    state = state.copyWith(
      isDownloading: false,
      downloadComplete: false,
    );
  }

  /// Save a reading locally. If autoSyncEnabled, immediately sends to API.
  /// Captures GPS if [meter]'s geo is null and permissions are granted.
  Future<void> saveReading(ReadingModel reading, {MeterModel? meter}) async {
    ReadingModel readingToSave = reading.copyWith(
      synced: false,
      syncError: null,
    );

    // Capture GPS if meter is provided (for audit/verification)
    if (meter != null) {
      try {
        final permission = await Permission.locationWhenInUse.status;
        if (permission.isGranted) {
          final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
          if (isLocationEnabled) {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            );
            readingToSave = readingToSave.copyWith(
              lat: position.latitude,
              lon: position.longitude,
            );
          }
        }
      } catch (e) {
        // Silently fail GPS capture
        debugPrint('Error capturing GPS: $e');
      }
    }

    await _meterRepo.saveReadingLocally(readingToSave);

    // Refresh readings map
    final updatedReadings = Map<String, ReadingModel>.from(state.readings);
    updatedReadings[reading.nAbonado] = readingToSave;
    final stats = await _meterRepo.getReadingStats();
    state = state.copyWith(readings: updatedReadings, stats: stats);

    // Auto-sync if enabled
    final autoSync = await _prefsService.getAutoSyncEnabled();
    if (autoSync) {
      try {
        await _autoSyncReading(readingToSave);
      } catch (_) {}
    }
  }

  /// Sends an individual reading to the API and marks it synced on success
  Future<void> _autoSyncReading(ReadingModel reading) async {
    final parentId = await _prefsService.getParentId();
    if (parentId == null) return;

    await _meterRepo.syncReadings(
      onProgress: null,
    );

    // If succeeded, refresh readings map with synced=true
    final synced = reading.copyWith(synced: true);
    final updatedReadings = Map<String, ReadingModel>.from(state.readings);
    updatedReadings[reading.nAbonado] = synced;
    state = state.copyWith(readings: updatedReadings);
  }

  /// Validate readings to distinguish valid from invalid ones
  ReadingValidationResult validateReadings() {
    final valid = <ReadingModel>[];
    final invalid = <ReadingModel>[];

    for (final reading in state.readings.values) {
      if (reading.isValid) {
        valid.add(reading);
      } else {
        invalid.add(reading);
      }
    }

    return ReadingValidationResult(valid: valid, invalid: invalid);
  }

  /// Finish work: send readings to API in batches of 500 and mark synced
  Future<SyncResult> finishWork({
    required List<ReadingModel> readingsToSend,
    void Function(int current, int total)? onProgress,
  }) async {
    final parentId = await _prefsService.getParentId();
    if (parentId == null) return const SyncResult(synced: 0, errors: 0, errorMessages: []);

    final date = Helpers.formatDateForApi(DateTime.now());
    final total = readingsToSend.length;
    const batchSize = 500;

    int totalSynced = 0;
    int totalErrors = 0;
    List<String> allErrors = [];
    String? finalGlobalError;
    List<String> finalGlobalErrorDetails = [];

    int sent = 0;
    for (int start = 0; start < total; start += batchSize) {
      final end = (start + batchSize).clamp(0, total);
      final batch = readingsToSend.sublist(start, end);

      final result = await _meterRepo.submitBatchToApi(
        readings: batch,
        parentId: parentId,
        date: date,
      );

      totalSynced += result.synced;
      totalErrors += result.errors;
      allErrors.addAll(result.errorMessages);
      if (result.globalError != null) {
        finalGlobalError = result.globalError;
        finalGlobalErrorDetails.addAll(result.globalErrorDetails);
      }

      // Only mark successful as synced in our local state map (DB handles it, but we update state without full reload yet to avoid lag)
      for (final r in batch) {
        if (!result.errorMessages.any((msg) => msg.startsWith('${r.nAbonado}:'))) {
          // This will be overwritten by loadMeters anyway, but just in case
        }
      }

      sent += batch.length;
      onProgress?.call(sent, total);
    }

    // Si todo salió bien, cerramos el periodo de trabajo
    if (totalErrors == 0 && finalGlobalError == null) {
      await _prefsService.setWorkStarted(false);
    }

    // Reload to reflect updated sync state (either synced or errored)
    await loadMeters();

    return SyncResult(
      synced: totalSynced,
      errors: totalErrors,
      errorMessages: allErrors,
      globalError: finalGlobalError,
      globalErrorDetails: finalGlobalErrorDetails,
    );
  }

  /// Refresh stats
  Future<void> refreshStats() async {
    final stats = await _meterRepo.getReadingStats();
    state = state.copyWith(stats: stats);
  }

  /// Search meters
  List<MeterModel> searchMeters(String query) {
    if (query.isEmpty) return state.meters;
    final q = query.toLowerCase();
    return state.meters.where((m) {
      return m.clientName.toLowerCase().contains(q) ||
          m.nAbonado.toLowerCase().contains(q) ||
          (m.number?.toLowerCase().contains(q) ?? false) ||
          m.address.toLowerCase().contains(q);
    }).toList();
  }

  /// Finalize the period on the server and clear local db
  Future<String> finishPeriod() async {
    final message = await _meterRepo.finishPeriod();
    await resetAllData();
    return message;
  }
}

/// Meters provider
final metersProvider = StateNotifierProvider<MetersNotifier, MetersState>((ref) {
  return MetersNotifier(
    meterRepo: getIt<MeterRepository>(),
    prefsService: getIt<PreferencesService>(),
  );
});

/// ─── Filter State ──────────────────────────────────────────

class MeterFilters {
  final String query;
  final String status; // 'all', 'pending', 'read', 'errors'
  final SectorModel? sector;

  const MeterFilters({
    this.query = '',
    this.status = 'all',
    this.sector,
  });

  MeterFilters copyWith({
    String? query,
    String? status,
    SectorModel? sector,
    bool clearSector = false,
  }) {
    return MeterFilters(
      query: query ?? this.query,
      status: status ?? this.status,
      sector: clearSector ? null : (sector ?? this.sector),
    );
  }
}

class MeterFiltersNotifier extends StateNotifier<MeterFilters> {
  MeterFiltersNotifier() : super(const MeterFilters());

  void setQuery(String q) => state = state.copyWith(query: q);
  void setStatus(String s) => state = state.copyWith(status: s);
  void setSector(SectorModel? s) => state = state.copyWith(sector: s, clearSector: s == null);
  void clear() => state = const MeterFilters();
}

/// Provider for active filters
final meterFiltersProvider = StateNotifierProvider<MeterFiltersNotifier, MeterFilters>((ref) {
  return MeterFiltersNotifier();
});

/// Provider for the filtered meters list, shared across screens
final filteredMetersProvider = Provider<List<MeterModel>>((ref) {
  final filters = ref.watch(meterFiltersProvider);
  final ms = ref.watch(metersProvider);
  
  var list = ms.meters;
  
  // Search
  if (filters.query.isNotEmpty) {
    final q = filters.query.toLowerCase();
    list = list.where((m) =>
        m.clientName.toLowerCase().contains(q) ||
        m.nAbonado.toLowerCase().contains(q) ||
        (m.number?.toLowerCase().contains(q) ?? false) ||
        m.address.toLowerCase().contains(q)).toList();
  }
  
  // Status
  switch (filters.status) {
    case 'pending':
      list = list.where((m) => !ms.readings.containsKey(m.nAbonado)).toList();
      break;
    case 'read':
      list = list.where((m) => ms.readings.containsKey(m.nAbonado)).toList();
      break;
    case 'errors':
      list = list.where((m) {
        final r = ms.readings[m.nAbonado];
        return r != null && (!r.isValid || r.syncError != null);
      }).toList();
      break;
  }
  
  // Sector
  if (filters.sector != null) {
    final sectorName = filters.sector!.name;
    list = list.where((m) => m.sector?.name == sectorName).toList();
  }
  
  return list;
});
