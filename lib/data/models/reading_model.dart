class ReadingModel {
  final String nAbonado;
  final int? currentReading;
  final String? notes;
  final Map<String, dynamic>? incidents;
  final bool isDamaged;
  final bool isInaccessible;
  final bool synced;
  final String? syncError;
  final String? localTimestamp;
  final String? dateRead;
  final double? lat;
  final double? lon;
  /// Local file path for the compressed image (before upload)
  final String? localImagePath;
  /// Whether the image has already been uploaded to the server
  final bool imageSynced;

  const ReadingModel({
    required this.nAbonado,
    this.currentReading,
    this.notes,
    this.incidents,
    this.isDamaged = false,
    this.isInaccessible = false,
    this.synced = false,
    this.syncError,
    this.localTimestamp,
    this.dateRead,
    this.lat,
    this.lon,
    this.localImagePath,
    this.imageSynced = false,
  });


  factory ReadingModel.fromJson(Map<String, dynamic> json) {
    return ReadingModel(
      nAbonado: json['n_abonado'] as String,
      currentReading: json['current_reading'] as int?,
      notes: json['notes'] as String?,
      incidents: json['incidents'] is String
          ? null
          : json['incidents'] as Map<String, dynamic>?,
      isDamaged: (json['is_damaged'] as int? ?? 0) == 1,
      isInaccessible: (json['is_inaccessible'] as int? ?? 0) == 1,
      synced: (json['synced'] as int? ?? 0) == 1,
      syncError: json['sync_error'] as String?,
      localTimestamp: json['local_timestamp'] as String?,
      dateRead: json['date_read'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      localImagePath: json['local_image_path'] as String?,
      imageSynced: (json['image_synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n_abonado': nAbonado,
      'current_reading': currentReading,
      'notes': notes,
      'incidents': incidents,
      'is_damaged': isDamaged ? 1 : 0,
      'is_inaccessible': isInaccessible ? 1 : 0,
      'synced': synced ? 1 : 0,
      'sync_error': syncError,
      'local_timestamp': localTimestamp,
      'date_read': dateRead,
      'lat': lat,
      'lon': lon,
      'local_image_path': localImagePath,
      'image_synced': imageSynced ? 1 : 0,
    };
  }

  String? _formatApiDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final dt = DateTime.parse(dateStr);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final sec = dt.second.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min:$sec';
    } catch (_) {
      return dateStr;
    }
  }

  /// Convert to API bulk format (images are sent separately)
  Map<String, dynamic> toApiBulkItem() {
    return {
      'n_abonado': nAbonado,
      'reading_value': currentReading,
      'datetime_read': _formatApiDate(dateRead ?? localTimestamp),
      'lon': lon,
      'lat': lat,
      'is_damaged': isDamaged,
      'is_inaccessible': isInaccessible,
      'note': notes,
    };
  }

  ReadingModel copyWith({
    String? nAbonado,
    int? currentReading,
    bool clearReading = false,
    String? notes,
    Map<String, dynamic>? incidents,
    bool? isDamaged,
    bool? isInaccessible,
    bool? synced,
    String? syncError,
    String? localTimestamp,
    String? dateRead,
    double? lat,
    double? lon,
    String? localImagePath,
    bool clearLocalImagePath = false,
    bool? imageSynced,
  }) {
    return ReadingModel(
      nAbonado: nAbonado ?? this.nAbonado,
      currentReading: clearReading ? null : (currentReading ?? this.currentReading),
      notes: notes ?? this.notes,
      incidents: incidents ?? this.incidents,
      isDamaged: isDamaged ?? this.isDamaged,
      isInaccessible: isInaccessible ?? this.isInaccessible,
      synced: synced ?? this.synced,
      syncError: syncError,
      localTimestamp: localTimestamp ?? this.localTimestamp,
      dateRead: dateRead ?? this.dateRead,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      localImagePath: clearLocalImagePath ? null : (localImagePath ?? this.localImagePath),
      imageSynced: imageSynced ?? this.imageSynced,
    );
  }

  /// Whether the reading is considered valid (has a value or is marked inaccessible/damaged)
  bool get isValid => currentReading != null || isInaccessible || isDamaged;

  /// Whether the reading has a locally stored image
  bool get hasLocalImage => localImagePath != null && localImagePath!.isNotEmpty;
}
