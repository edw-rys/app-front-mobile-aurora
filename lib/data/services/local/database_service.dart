import 'dart:convert';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';
import '../../models/meter_model.dart';
import '../../models/reading_model.dart';

/// SQLite database service for offline-first storage
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'aurora_blue_e_dinky.db';
  static const int _dbVersion = 6;

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id TEXT NOT NULL,
        n_abonado TEXT NOT NULL,
        meter_data TEXT NOT NULL,
        UNIQUE(period_id, n_abonado)
      )
    ''');

    await db.execute('''
      CREATE TABLE sectors (
        name TEXT NOT NULL,
        period_id TEXT NOT NULL,
        point1_lat REAL,
        point1_lon REAL,
        point2_lat REAL,
        point2_lon REAL,
        point3_lat REAL,
        point3_lon REAL,
        point4_lat REAL,
        point4_lon REAL,
        PRIMARY KEY (name, period_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE readings (
        n_abonado TEXT PRIMARY KEY,
        period_id TEXT NOT NULL,
        current_reading INTEGER,
        notes TEXT,
        incidents TEXT,
        is_damaged INTEGER DEFAULT 0,
        is_inaccessible INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0,
        sync_error TEXT,
        local_timestamp TEXT,
        date_read TEXT,
        lat REAL,
        lon REAL,
        local_image_path TEXT,
        image_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_meters_period ON meters(period_id)',
    );
    await db.execute(
      'CREATE INDEX idx_readings_synced ON readings(synced)',
    );
    await db.execute(
      'CREATE INDEX idx_readings_period ON readings(period_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sectors_period ON sectors(period_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE readings ADD COLUMN period_id TEXT DEFAULT ""',
      );
      await db.execute('ALTER TABLE readings ADD COLUMN lat REAL');
      await db.execute('ALTER TABLE readings ADD COLUMN lon REAL');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE readings ADD COLUMN is_damaged INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE readings ADD COLUMN is_inaccessible INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE readings ADD COLUMN date_read TEXT',
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sectors (
          name TEXT NOT NULL,
          period_id TEXT NOT NULL,
          point1_lat REAL,
          point1_lon REAL,
          point2_lat REAL,
          point2_lon REAL,
          point3_lat REAL,
          point3_lon REAL,
          point4_lat REAL,
          point4_lon REAL,
          PRIMARY KEY (name, period_id)
        )
      ''');
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE readings ADD COLUMN local_image_path TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE readings ADD COLUMN image_synced INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }
  }

  // ─── Meters ───────────────────────────────────────────────

  /// Save a batch of meters for a period
  Future<void> saveMetersBatch(
    String periodId,
    List<MeterModel> meters,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final meter in meters) {
      batch.insert(
        'meters',
        {
          'period_id': periodId,
          'n_abonado': meter.nAbonado,
          'meter_data': jsonEncode(meter.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Selectively update meter data while preserving user readings
  Future<void> updateMetersSelective(
    String periodId,
    List<MeterModel> newMeters,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final newMeter in newMeters) {
        final existing = await txn.query(
          'meters',
          where: 'period_id = ? AND n_abonado = ?',
          whereArgs: [periodId, newMeter.nAbonado],
        );

        if (existing.isNotEmpty) {
          final oldData = jsonDecode(existing.first['meter_data'] as String) as Map<String, dynamic>;
          final oldMeter = MeterModel.fromJson(oldData);

          // Update only allowed fields
          final updatedMeter = oldMeter.copyWith(
            clientName: newMeter.clientName,
            identificationNumber: newMeter.identificationNumber,
            number: newMeter.number,
            address: newMeter.address,
            sector: newMeter.sector,
            geo: newMeter.geo,
            reading: oldMeter.reading.copyWith(
              previousReading: newMeter.reading.previousReading,
              date: newMeter.reading.date,
            ),
          );

          await txn.update(
            'meters',
            {'meter_data': jsonEncode(updatedMeter.toJson())},
            where: 'period_id = ? AND n_abonado = ?',
            whereArgs: [periodId, newMeter.nAbonado],
          );
        } else {
          // New meter
          await txn.insert(
            'meters',
            {
              'period_id': periodId,
              'n_abonado': newMeter.nAbonado,
              'meter_data': jsonEncode(newMeter.toJson()),
            },
          );
        }
      }
    });
  }

  /// Remove meters not present in a given list of n_abonados
  Future<void> removeOrphanMeters(String periodId, Set<String> apiAbonados) async {
    final db = await database;
    final localMeters = await db.query(
      'meters',
      columns: ['n_abonado'],
      where: 'period_id = ?',
      whereArgs: [periodId],
    );

    final localAbonados = localMeters.map((m) => m['n_abonado'] as String).toList();
    final orphans = localAbonados.where((a) => !apiAbonados.contains(a)).toList();

    if (orphans.isNotEmpty) {
      final batch = db.batch();
      for (final orphan in orphans) {
        batch.delete(
          'meters',
          where: 'period_id = ? AND n_abonado = ?',
          whereArgs: [periodId, orphan],
        );
        // Delete associated reading if any (critical for Home stats)
        batch.delete(
          'readings',
          where: 'period_id = ? AND n_abonado = ?',
          whereArgs: [periodId, orphan],
        );
      }
      await batch.commit(noResult: true);
    }
  }

  /// Get all meters for a period
  Future<List<MeterModel>> getMetersByPeriod(String periodId) async {
    final db = await database;
    final results = await db.query(
      'meters',
      where: 'period_id = ?',
      whereArgs: [periodId],
    );
    return results.map((row) {
      final data = jsonDecode(row['meter_data'] as String) as Map<String, dynamic>;
      return MeterModel.fromJson(data);
    }).toList();
  }

  /// Get count of meters for a period
  Future<int> getMeterCount(String periodId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM meters WHERE period_id = ?',
      [periodId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if meters are already downloaded for a period
  Future<bool> hasMetersForPeriod(String periodId) async {
    final count = await getMeterCount(periodId);
    return count > 0;
  }

  // ─── Sectors ──────────────────────────────────────────────

  /// Save a batch of sectors for a period
  Future<void> saveSectorsBatch(
    String periodId,
    List<SectorModel> sectors,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final sector in sectors) {
      batch.insert(
        'sectors',
        {
          'period_id': periodId,
          'name': sector.name,
          'point1_lat': sector.point1Lat,
          'point1_lon': sector.point1Lon,
          'point2_lat': sector.point2Lat,
          'point2_lon': sector.point2Lon,
          'point3_lat': sector.point3Lat,
          'point3_lon': sector.point3Lon,
          'point4_lat': sector.point4Lat,
          'point4_lon': sector.point4Lon,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get all sectors for a period
  Future<List<SectorModel>> getSectorsByPeriod(String periodId) async {
    final db = await database;
    final results = await db.query(
      'sectors',
      where: 'period_id = ?',
      whereArgs: [periodId],
    );
    return results.map((row) {
      return SectorModel(
        name: row['name'] as String,
        point1Lat: row['point1_lat'] as double?,
        point1Lon: row['point1_lon'] as double?,
        point2Lat: row['point2_lat'] as double?,
        point2Lon: row['point2_lon'] as double?,
        point3Lat: row['point3_lat'] as double?,
        point3Lon: row['point3_lon'] as double?,
        point4Lat: row['point4_lat'] as double?,
        point4Lon: row['point4_lon'] as double?,
      );
    }).toList();
  }

  // ─── Readings ─────────────────────────────────────────────

  /// Save or update a reading (local first).
  /// On update, image_synced and local_image_path are NOT overwritten
  /// to prevent re-uploading images that were already synced.
  Future<void> upsertReading(ReadingModel reading, String periodId) async {
    final db = await database;

    final existing = await db.query(
      'readings',
      columns: ['n_abonado', 'image_synced', 'local_image_path'],
      where: 'n_abonado = ?',
      whereArgs: [reading.nAbonado],
      limit: 1,
    );

    if (existing.isEmpty) {
      // First time: full insert including image fields
      await db.insert(
        'readings',
        {
          'n_abonado': reading.nAbonado,
          'period_id': periodId,
          'current_reading': reading.currentReading,
          'notes': reading.notes,
          'incidents': reading.incidents != null
              ? jsonEncode(reading.incidents)
              : null,
          'is_damaged': reading.isDamaged ? 1 : 0,
          'is_inaccessible': reading.isInaccessible ? 1 : 0,
          'synced': reading.synced ? 1 : 0,
          'sync_error': reading.syncError,
          'local_timestamp': reading.localTimestamp,
          'date_read': reading.dateRead,
          'lat': reading.lat,
          'lon': reading.lon,
          'local_image_path': reading.localImagePath,
          'image_synced': reading.imageSynced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // Update: preserve image_synced and local_image_path from DB
      // Only overwrite local_image_path if the incoming value is not null
      // (user took a new photo), and reset image_synced only in that case.
      final existingImageSynced = (existing.first['image_synced'] as int?) ?? 0;
      final existingImagePath = existing.first['local_image_path'] as String?;

      final bool newPhoto = reading.localImagePath != null &&
          reading.localImagePath != existingImagePath;

      await db.update(
        'readings',
        {
          'period_id': periodId,
          'current_reading': reading.currentReading,
          'notes': reading.notes,
          'incidents': reading.incidents != null
              ? jsonEncode(reading.incidents)
              : null,
          'is_damaged': reading.isDamaged ? 1 : 0,
          'is_inaccessible': reading.isInaccessible ? 1 : 0,
          'synced': reading.synced ? 1 : 0,
          'sync_error': reading.syncError,
          'local_timestamp': reading.localTimestamp,
          'date_read': reading.dateRead,
          'lat': reading.lat,
          'lon': reading.lon,
          // Only update image fields if a brand-new photo has been captured
          'local_image_path': newPhoto ? reading.localImagePath : existingImagePath,
          'image_synced': newPhoto ? 0 : existingImageSynced,
        },
        where: 'n_abonado = ?',
        whereArgs: [reading.nAbonado],
      );
    }
  }

  /// Get readings that have a local image not yet uploaded
  Future<List<ReadingModel>> getReadingsWithPendingImages() async {
    final db = await database;
    final results = await db.query(
      'readings',
      where: 'local_image_path IS NOT NULL AND image_synced = 0',
    );
    return results.map(_readingFromRow).toList();
  }

  /// Mark image as uploaded for a given n_abonado
  Future<void> markImageAsSynced(String nAbonado) async {
    final db = await database;
    await db.update(
      'readings',
      {'image_synced': 1},
      where: 'n_abonado = ?',
      whereArgs: [nAbonado],
    );
  }

  /// Get a reading by n_abonado
  Future<ReadingModel?> getReading(String nAbonado) async {
    final db = await database;
    final results = await db.query(
      'readings',
      where: 'n_abonado = ?',
      whereArgs: [nAbonado],
    );
    if (results.isEmpty) return null;
    return _readingFromRow(results.first);
  }

  /// Get all readings for a period
  Future<List<ReadingModel>> getReadingsByPeriod(String periodId) async {
    final db = await database;
    final results = await db.query(
      'readings',
      where: 'period_id = ?',
      whereArgs: [periodId],
    );
    return results.map(_readingFromRow).toList();
  }

  /// Get unsynced readings
  Future<List<ReadingModel>> getPendingReadings() async {
    final db = await database;
    final results = await db.query(
      'readings',
      where: 'synced = 0 AND (current_reading IS NOT NULL OR is_inaccessible = 1 OR is_damaged = 1)',
    );
    return results.map(_readingFromRow).toList();
  }

  /// Get reading stats for a period
  Future<Map<String, int>> getReadingStats(String periodId) async {
    final db = await database;
    final totalMeters = await getMeterCount(periodId);

    // Use subqueries to ensure we only count readings for meters that still exist in the route
    // This prevents counting stale readings after "Actualizar datos" removes meters.

    final readResult = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM readings 
         WHERE period_id = ? 
         AND current_reading IS NOT NULL
         AND n_abonado IN (SELECT n_abonado FROM meters WHERE period_id = ?)''',
      [periodId, periodId],
    );
    final readCount = Sqflite.firstIntValue(readResult) ?? 0;

    final unsyncedResult = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM readings 
         WHERE period_id = ? 
         AND synced = 0 
         AND sync_error IS NULL 
         AND (current_reading IS NOT NULL OR is_inaccessible = 1 OR is_damaged = 1)
         AND n_abonado IN (SELECT n_abonado FROM meters WHERE period_id = ?)''',
      [periodId, periodId],
    );
    final unsyncedCount = Sqflite.firstIntValue(unsyncedResult) ?? 0;

    final errorsResult = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM readings 
         WHERE period_id = ? 
         AND sync_error IS NOT NULL
         AND n_abonado IN (SELECT n_abonado FROM meters WHERE period_id = ?)''',
      [periodId, periodId],
    );
    final errorsCount = Sqflite.firstIntValue(errorsResult) ?? 0;

    return {
      'total': totalMeters,
      'read': readCount,
      'pending': totalMeters - readCount,
      'unsynced': unsyncedCount,
      'errors': errorsCount,
    };
  }

  /// Mark a reading as synced
  Future<void> markAsSynced(String nAbonado) async {
    final db = await database;
    await db.update(
      'readings',
      {'synced': 1, 'sync_error': null},
      where: 'n_abonado = ?',
      whereArgs: [nAbonado],
    );
  }

  /// Mark a reading as having a sync error
  Future<void> markAsError(String nAbonado, String errorMsg) async {
    final db = await database;
    await db.update(
      'readings',
      {'synced': 0, 'sync_error': errorMsg},
      where: 'n_abonado = ?',
      whereArgs: [nAbonado],
    );
  }

  /// Mark multiple readings as synced
  Future<void> markBatchAsSynced(List<String> nAbonados) async {
    final db = await database;
    final batch = db.batch();
    for (final nAbonado in nAbonados) {
      batch.update(
        'readings',
        {'synced': 1, 'sync_error': null},
        where: 'n_abonado = ?',
        whereArgs: [nAbonado],
      );
    }
    await batch.commit(noResult: true);
  }

  // ─── CSV Export ────────────────────────────────────────────

  /// Generate CSV data for export
  /// Format: CLAVE,L. ACTUAL,LEIDA,CONSUMO,MEDIDOR
  Future<List<List<String>>> exportCSVData(String periodId) async {
    await database;
    final meters = await getMetersByPeriod(periodId);
    final readings = await getReadingsByPeriod(periodId);

    final readingMap = {
      for (final r in readings) r.nAbonado: r,
    };

    final csvRows = <List<String>>[
      ['CLAVE', 'L. ACTUAL', 'LEIDA', 'CONSUMO', 'MEDIDOR'],
    ];

    for (final meter in meters) {
    final reading = readingMap[meter.nAbonado];
    final previousReading = meter.reading.previousReading ?? 0;
    
    String currentReadingStr = '';
    String consumptionStr = '';
    
    if (reading != null && (reading.currentReading != null || reading.isDamaged || reading.isInaccessible)) {
      final currentReading = reading.currentReading ?? 0;
      currentReadingStr = currentReading.toString();
      consumptionStr = (currentReading - previousReading).toString();
    }

    csvRows.add([
      meter.nAbonado,
      previousReading.toString(),
      currentReadingStr,
      consumptionStr,
      meter.number ?? '',
    ]);
  }

    return csvRows;
  }

  // ─── Cleanup ──────────────────────────────────────────────

  /// Clear readings (optional - on explicit user request)
  Future<void> clearReadings() async {
    final db = await database;
    await db.delete('readings');
  }

  /// Clear ALL local data — readings AND meters (used by Restore)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('readings');
      await txn.delete('meters');
      await txn.delete('sectors');
    });
  }

  /// Clear meters for a period
  Future<void> clearMetersForPeriod(String periodId) async {
    final db = await database;
    await db.delete('meters', where: 'period_id = ?', whereArgs: [periodId]);
  }

  /// Delete readings whose n_abonado is not in [validAbonados].
  /// Returns the local_image_path of every deleted reading so the caller
  /// can delete the files from disk.
  Future<List<String>> deleteOrphanReadings(
    String periodId,
    Set<String> validAbonados,
  ) async {
    final db = await database;

    // Find orphan readings with a local image
    final orphans = await db.query(
      'readings',
      columns: ['n_abonado', 'local_image_path'],
      where: 'period_id = ? AND n_abonado NOT IN (${validAbonados.map((_) => '?').join(',')})',
      whereArgs: [periodId, ...validAbonados],
    );

    final imagePaths = orphans
        .where((r) => r['local_image_path'] != null)
        .map((r) => r['local_image_path'] as String)
        .toList();

    // Delete the orphan readings
    if (validAbonados.isNotEmpty) {
      await db.delete(
        'readings',
        where: 'period_id = ? AND n_abonado NOT IN (${validAbonados.map((_) => '?').join(',')})',
        whereArgs: [periodId, ...validAbonados],
      );
    }

    return imagePaths;
  }

  /// Get all local_image_path values that are not null
  Future<List<String>> getAllLocalImagePaths() async {
    final db = await database;
    final rows = await db.query(
      'readings',
      columns: ['local_image_path'],
      where: 'local_image_path IS NOT NULL',
    );
    return rows.map((r) => r['local_image_path'] as String).toList();
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ─── Helpers ──────────────────────────────────────────────

  ReadingModel _readingFromRow(Map<String, dynamic> row) {
    Map<String, dynamic>? incidents;
    if (row['incidents'] != null && (row['incidents'] as String).isNotEmpty) {
      try {
        incidents = jsonDecode(row['incidents'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    return ReadingModel(
      nAbonado: row['n_abonado'] as String,
      currentReading: row['current_reading'] as int?,
      notes: row['notes'] as String?,
      incidents: incidents,
      isDamaged: (row['is_damaged'] as int? ?? 0) == 1,
      isInaccessible: (row['is_inaccessible'] as int? ?? 0) == 1,
      synced: (row['synced'] as int? ?? 0) == 1,
      syncError: row['sync_error'] as String?,
      localTimestamp: row['local_timestamp'] as String?,
      dateRead: row['date_read'] as String?,
      lat: (row['lat'] as num?)?.toDouble(),
      lon: (row['lon'] as num?)?.toDouble(),
      localImagePath: row['local_image_path'] as String?,
      imageSynced: (row['image_synced'] as int? ?? 0) == 1,
    );
  }
}
