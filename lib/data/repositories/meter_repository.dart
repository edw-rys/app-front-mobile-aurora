import 'package:dio/dio.dart';
import '../../core/utils/helpers.dart';
import '../../core/exceptions/dio_exception_handler.dart';
import '../models/meter_model.dart';
import '../models/reading_model.dart';
import '../services/local/database_service.dart';
import '../services/local/preferences_service.dart';
import '../services/remote/api_service.dart';

/// Repository for meter and reading operations
/// Handles offline-first strategy: save locally → sync when online
class MeterRepository {
  final ApiService _apiService;
  final DatabaseService _dbService;
  final PreferencesService _prefsService;

  MeterRepository({
    required ApiService apiService,
    required DatabaseService dbService,
    required PreferencesService prefsService,
  })  : _apiService = apiService,
        _dbService = dbService,
        _prefsService = prefsService;

  // ─── Fetch All Meters ─────────────────────────────────────

  /// Download ALL pages of meters from API and save to SQLite
  /// Fetches page by page sequentially, saving each batch to avoid data loss
  /// Uses n_abonado as unique key per period_id to avoid duplicates
  /// Returns total count of meters downloaded
  Future<int> fetchAndSaveAllMeters({
    void Function(int current, int total)? onProgress,
  }) async {
    // First page to get pagination info + period data
    final firstPage = await _apiService.getMeters(1);
    final lastPage = firstPage.lastPage;
    final parentId = firstPage.parentId;

    // Save period info from aditionalParams
    final periodId = firstPage.periodId ?? parentId;
    if (periodId != null) {
      await _prefsService.saveParentId(periodId);
      await _prefsService.savePeriodId(periodId.toString());
    }

    // Save additional period metadata
    if (firstPage.aditionalParams != null) {
      await _prefsService.savePeriodInfo(firstPage.aditionalParams!);
    }

    final periodIdStr = periodId?.toString() ?? '0';

    // Group sectors from first page
    final List<SectorModel> allSectors = [];
    _extractSectors(firstPage.items, allSectors);

    // Save first page immediately
    await _dbService.saveMetersBatch(periodIdStr, firstPage.items);
    int totalSaved = firstPage.items.length;
    onProgress?.call(1, lastPage);

    // Fetch and save remaining pages one by one
    for (int page = 2; page <= lastPage; page++) {
      final pageResponse = await _apiService.getMeters(page);
      _extractSectors(pageResponse.items, allSectors);
      await _dbService.saveMetersBatch(periodIdStr, pageResponse.items);
      totalSaved += pageResponse.items.length;
      onProgress?.call(page, lastPage);
    }

    // Save all unique sectors
    await _saveUniqueSectors(periodIdStr, allSectors);

    // Mark work as started
    await _prefsService.setWorkStarted(true);

    return totalSaved;
  }

  /// Update existing meters and remove orphans using fresh data from API
  Future<int> updateAndSyncMeters({
    void Function(int current, int total)? onProgressDownload,
    void Function()? onVerifying,
  }) async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) throw Exception('No hay periodo activo.');

    // 1. Download all meters (Sequential)
    final firstPage = await _apiService.getMeters(1);
    final totalPages = firstPage.lastPage;
    
    final List<MeterModel> allApiMeters = [];
    final List<SectorModel> allSectorsFromApi = [];
    
    allApiMeters.addAll(firstPage.items);
    _extractSectors(firstPage.items, allSectorsFromApi);
    onProgressDownload?.call(1, totalPages);

    for (int page = 2; page <= totalPages; page++) {
      final pageResponse = await _apiService.getMeters(page);
      allApiMeters.addAll(pageResponse.items);
      _extractSectors(pageResponse.items, allSectorsFromApi);
      onProgressDownload?.call(page, totalPages);
    }

    // 2. Verifying and matching data
    onVerifying?.call();
    
    // Selective update
    await _dbService.updateMetersSelective(periodId, allApiMeters);
    
    // Cleanup orphans
    final apiAbonados = allApiMeters.map((m) => m.nAbonado).toSet();
    await _dbService.removeOrphanMeters(periodId, apiAbonados);
    
    // Update sectors
    await _saveUniqueSectors(periodId, allSectorsFromApi);

    return allApiMeters.length;
  }

  Future<void> _saveUniqueSectors(String periodId, List<SectorModel> allSectors) async {
    if (allSectors.isNotEmpty) {
      final uniqueSectors = <String, SectorModel>{};
      for (var s in allSectors) {
        if (!uniqueSectors.containsKey(s.name)) {
          uniqueSectors[s.name] = s;
        }
      }
      await _dbService.saveSectorsBatch(periodId, uniqueSectors.values.toList());
    }
  }

  void _extractSectors(List<MeterModel> items, List<SectorModel> target) {
    for (var m in items) {
      if (m.sector != null) {
        target.add(m.sector!);
      }
    }
  }

  // ─── Local Meters ─────────────────────────────────────────

  /// Get meters from local SQLite
  Future<List<MeterModel>> getLocalMeters() async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) return [];
    return _dbService.getMetersByPeriod(periodId);
  }

  /// Check if meters exist locally
  Future<bool> hasLocalMeters() async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) return false;
    return _dbService.hasMetersForPeriod(periodId);
  }

  /// Get sectors from local SQLite
  Future<List<SectorModel>> getLocalSectors() async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) return [];
    return _dbService.getSectorsByPeriod(periodId);
  }

  // ─── Readings (Local First) ───────────────────────────────

  /// Save a reading locally (offline-first)
  Future<void> saveReadingLocally(ReadingModel reading) async {
    final periodId = await _prefsService.getPeriodId() ?? '0';
    await _dbService.upsertReading(reading, periodId);
  }

  /// Get a reading by n_abonado
  Future<ReadingModel?> getReading(String nAbonado) async {
    return _dbService.getReading(nAbonado);
  }

  /// Get all readings for current period
  Future<List<ReadingModel>> getCurrentReadings() async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) return [];
    return _dbService.getReadingsByPeriod(periodId);
  }

  /// Get reading stats
  Future<Map<String, int>> getReadingStats() async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) {
      return {'total': 0, 'read': 0, 'pending': 0, 'unsynced': 0};
    }
    return _dbService.getReadingStats(periodId);
  }

  // ─── Sync (Sequential, 1-by-1, blocks of 500) ────────────

  /// Sync pending readings to server
  /// Sends readings 1-by-1 using the bulk endpoint (list with 1 item)
  /// Processes in blocks of 500
  /// Returns count of successfully synced readings and errors
  Future<SyncResult> syncReadings({
    void Function(int current, int total)? onProgress,
  }) async {
    final parentId = await _prefsService.getParentId();
    if (parentId == null) {
      return SyncResult(synced: 0, errors: 0, errorMessages: []);
    }

    final pendingReadings = await _dbService.getPendingReadings();
    if (pendingReadings.isEmpty) {
      return SyncResult(synced: 0, errors: 0, errorMessages: []);
    }

    final totalCount = pendingReadings.length;
    int syncedCount = 0;
    int errorCount = 0;
    final errorMessages = <String>[];

    // Process in blocks of 500
    const blockSize = 500;
    for (int blockStart = 0; blockStart < totalCount; blockStart += blockSize) {
      final blockEnd = (blockStart + blockSize).clamp(0, totalCount);
      final block = pendingReadings.sublist(blockStart, blockEnd);

      // Send each reading in the block 1-by-1
      for (int i = 0; i < block.length; i++) {
        final reading = block[i];
        final overallIndex = blockStart + i;
        onProgress?.call(overallIndex + 1, totalCount);

        try {
          final response = await _apiService.postReadingBulk(
            date: Helpers.formatDateForApi(DateTime.now()),
            readingPeriodId: parentId,
            readingItem: reading.toApiBulkItem(),
          );

          final payload = response['payload'] as Map<String, dynamic>?;
          final errorsList = payload?['errors'] as List<dynamic>? ?? [];

          if (errorsList.isNotEmpty) {
             final err = errorsList.first['error']?.toString() ?? 'Error desconocido';
             await _dbService.markAsError(reading.nAbonado, err);
             errorCount++;
             errorMessages.add('${reading.nAbonado}: $err');
          } else {
             // Mark as synced in SQLite
             await _dbService.markAsSynced(reading.nAbonado);
             syncedCount++;
          }
        } catch (e) {
          errorCount++;
          errorMessages.add(
            '${reading.nAbonado}: ${e.toString()}',
          );
          // Continue with next reading on error
        }
      }
    }

    return SyncResult(
      synced: syncedCount,
      errors: errorCount,
      errorMessages: errorMessages,
    );
  }
  // ─── CSV Export ────────────────────────────────────────────

  /// Get CSV data for export
  Future<List<List<String>>> exportCSV() async {
    final periodId = await _prefsService.getPeriodId();
    if (periodId == null) return [];
    return _dbService.exportCSVData(periodId);
  }
  Future<SyncResult> submitBatchToApi({
    required List<ReadingModel> readings,
    required int parentId,
    required String date,
  }) async {
    try {
      final response = await _apiService.postReadingsBulk(
        date: date,
        readingPeriodId: parentId,
        readings: readings.map((r) => r.toApiBulkItem()).toList(),
      );

      int syncedCount = 0;
      int errorCount = 0;
      
      final payload = response['payload'] as Map<String, dynamic>?;
      final errorsList = payload?['errors'] as List<dynamic>? ?? [];

      final errorNotes = <String, String>{};
      for (var e in errorsList) {
        if (e is Map<String, dynamic>) {
          final abn = e['n_abonado']?.toString();
          final err = e['error']?.toString() ?? 'Error desconocido';
          if (abn != null) {
            errorNotes[abn] = err;
          }
        }
      }

      final successAbonados = <String>[];
      for (var r in readings) {
        if (errorNotes.containsKey(r.nAbonado)) {
          await _dbService.markAsError(r.nAbonado, errorNotes[r.nAbonado]!);
          errorCount++;
        } else {
          successAbonados.add(r.nAbonado);
          syncedCount++;
        }
      }

      if (successAbonados.isNotEmpty) {
        await _dbService.markBatchAsSynced(successAbonados);
      }

      return SyncResult(
        synced: syncedCount,
        errors: errorCount,
        errorMessages: errorNotes.values.toList(),
      );
    } on DioException catch (e) {
      List<String> details = [];

      final data = e.response?.data;
      if (data != null && data is Map<String, dynamic>) {
        final apiErrors = data['errors'];
        if (apiErrors is Map<String, dynamic>) {
          for (final value in apiErrors.values) {
            if (value is List) {
              details.addAll(value.map((e) => e.toString()));
            } else {
              details.add(value.toString());
            }
          }
        } else if (apiErrors is String) {
          details.add(apiErrors);
        }
      }

      return SyncResult(
        synced: 0,
        errors: readings.length,
        errorMessages: [],
        globalError: DioExceptionHandler.mapToString(e),
        globalErrorDetails: details,
      );
    }
  }


  /// Clear ALL local data (readings + meters) — delegated to DB
  Future<void> clearAllLocalData() async {
    await _dbService.clearAllData();
  }

  /// Finish reading period
  Future<String> finishPeriod() async {
    final parentId = await _prefsService.getParentId();
    if (parentId == null) throw Exception('No hay periodo activo.');

    try {
      final response = await _apiService.finishPeriod(parentId);
      final status = response['status'];
      final message = response['message']?.toString() ?? 'Operación finalizada';

      if (status != 'OK') {
        throw Exception(message);
      }
      return message;
    } catch (e) {
      throw Exception(DioExceptionHandler.mapToString(e));
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final int synced;
  final int errors;
  final List<String> errorMessages;
  final String? globalError;
  final List<String> globalErrorDetails;

  const SyncResult({
    required this.synced,
    required this.errors,
    required this.errorMessages,
    this.globalError,
    this.globalErrorDetails = const [],
  });

  bool get hasErrors => errors > 0 || globalError != null;
  int get total => synced + errors;
}
