import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/injection.dart';
import '../../data/repositories/meter_repository.dart';

/// Sync state
class SyncState {
  final bool isSyncing;
  final int currentProgress;
  final int totalReadings;
  final int syncedCount;
  final int errorCount;
  final String? statusMessage;
  final bool isComplete;

  const SyncState({
    this.isSyncing = false,
    this.currentProgress = 0,
    this.totalReadings = 0,
    this.syncedCount = 0,
    this.errorCount = 0,
    this.statusMessage,
    this.isComplete = false,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? currentProgress,
    int? totalReadings,
    int? syncedCount,
    int? errorCount,
    String? statusMessage,
    bool? isComplete,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      currentProgress: currentProgress ?? this.currentProgress,
      totalReadings: totalReadings ?? this.totalReadings,
      syncedCount: syncedCount ?? this.syncedCount,
      errorCount: errorCount ?? this.errorCount,
      statusMessage: statusMessage ?? this.statusMessage,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Readings/Sync notifier
class ReadingsNotifier extends StateNotifier<SyncState> {
  final MeterRepository _meterRepo;

  ReadingsNotifier({required MeterRepository meterRepo})
      : _meterRepo = meterRepo,
        super(const SyncState());

  /// Sync all pending readings
  Future<SyncResult> syncReadings() async {
    state = state.copyWith(
      isSyncing: true,
      isComplete: false,
      statusMessage: 'Preparando sincronización...',
    );

    try {
      final result = await _meterRepo.syncReadings(
        onProgress: (current, total) {
          state = state.copyWith(
            currentProgress: current,
            totalReadings: total,
            statusMessage: 'Enviando lectura $current de $total',
          );
        },
      );

      state = state.copyWith(
        isSyncing: false,
        isComplete: true,
        syncedCount: result.synced,
        errorCount: result.errors,
        statusMessage: result.hasErrors
            ? 'Sincronización completada con ${result.errors} errores'
            : 'Sincronización completada exitosamente',
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        statusMessage: 'Error: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Export CSV
  Future<List<List<String>>> exportCSV() async {
    return _meterRepo.exportCSV();
  }

  /// Reset sync state
  void reset() {
    state = const SyncState();
  }
}

/// Readings/sync provider
final readingsProvider = StateNotifierProvider<ReadingsNotifier, SyncState>((ref) {
  return ReadingsNotifier(meterRepo: getIt<MeterRepository>());
});
