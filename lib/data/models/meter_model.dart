class MeterModel {
  final String clientName;
  final String? identificationNumber;
  final String nAbonado;
  final String? number;
  final String address;
  final GeoModel geo;
  final MeterReadingInfo reading;
  final SectorModel? sector;

  const MeterModel({
    required this.clientName,
    this.identificationNumber,
    required this.nAbonado,
    this.number,
    required this.address,
    required this.geo,
    required this.reading,
    this.sector,
  });

  factory MeterModel.fromJson(Map<String, dynamic> json) {
    return MeterModel(
      clientName: json['client_name'] as String? ?? '',
      identificationNumber: json['identification_number'] as String?,
      nAbonado: json['n_abonado'] as String? ?? '',
      number: json['number'] as String?,
      address: json['address'] as String? ?? '',
      geo: GeoModel.fromJson(json['geo'] as Map<String, dynamic>? ?? {}),
      reading: MeterReadingInfo.fromJson(
        json['reading'] as Map<String, dynamic>? ?? {},
      ),
      sector: json['sector'] != null
          ? SectorModel.fromJson(json['sector'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_name': clientName,
      'identification_number': identificationNumber,
      'n_abonado': nAbonado,
      'number': number,
      'address': address,
      'geo': geo.toJson(),
      'reading': reading.toJson(),
      'sector': sector?.toJson(),
    };
  }

  MeterModel copyWith({
    String? clientName,
    String? identificationNumber,
    String? nAbonado,
    String? number,
    String? address,
    GeoModel? geo,
    MeterReadingInfo? reading,
    SectorModel? sector,
  }) {
    return MeterModel(
      clientName: clientName ?? this.clientName,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      nAbonado: nAbonado ?? this.nAbonado,
      number: number ?? this.number,
      address: address ?? this.address,
      geo: geo ?? this.geo,
      reading: reading ?? this.reading,
      sector: sector ?? this.sector,
    );
  }
}

class SectorModel {
  final String name;
  final double? point1Lat;
  final double? point1Lon;
  final double? point2Lat;
  final double? point2Lon;
  final double? point3Lat;
  final double? point3Lon;
  final double? point4Lat;
  final double? point4Lon;

  const SectorModel({
    required this.name,
    this.point1Lat,
    this.point1Lon,
    this.point2Lat,
    this.point2Lon,
    this.point3Lat,
    this.point3Lon,
    this.point4Lat,
    this.point4Lon,
  });

  factory SectorModel.fromJson(Map<String, dynamic> json) {
    return SectorModel(
      name: json['name'] as String? ?? 'Sin Nombre',
      point1Lat: _parseDouble(json['point1_lat']),
      point1Lon: _parseDouble(json['point1_lon']),
      point2Lat: _parseDouble(json['point2_lat']),
      point2Lon: _parseDouble(json['point2_lon']),
      point3Lat: _parseDouble(json['point3_lat']),
      point3Lon: _parseDouble(json['point3_lon']),
      point4Lat: _parseDouble(json['point4_lat']),
      point4Lon: _parseDouble(json['point4_lon']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'point1_lat': point1Lat,
      'point1_lon': point1Lon,
      'point2_lat': point2Lat,
      'point2_lon': point2Lon,
      'point3_lat': point3Lat,
      'point3_lon': point3Lon,
      'point4_lat': point4Lat,
      'point4_lon': point4Lon,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectorModel &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class GeoModel {
  final double? lat;
  final double? lon;

  const GeoModel({this.lat, this.lon});

  bool get hasCoordinates => lat != null && lon != null;

  factory GeoModel.fromJson(Map<String, dynamic> json) {
    return GeoModel(
      lat: _parseDouble(json['lat']),
      lon: _parseDouble(json['lon']),
    );
  }

  /// Parse a value that could be null, num, or String to double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}

class MeterReadingInfo {
  final int? currentReading;
  final int? previousReading;
  final int? consumption;
  final String? date;

  const MeterReadingInfo({
    this.currentReading,
    this.previousReading,
    this.consumption,
    this.date,
  });

  factory MeterReadingInfo.fromJson(Map<String, dynamic> json) {
    return MeterReadingInfo(
      currentReading: json['current_reading'] as int?,
      previousReading: json['previous_reading'] as int?,
      consumption: json['consumption'] as int?,
      date: json['date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_reading': currentReading,
      'previous_reading': previousReading,
      'consumption': consumption,
      'date': date,
    };
  }

  MeterReadingInfo copyWith({
    int? currentReading,
    int? previousReading,
    int? consumption,
    String? date,
  }) {
    return MeterReadingInfo(
      currentReading: currentReading ?? this.currentReading,
      previousReading: previousReading ?? this.previousReading,
      consumption: consumption ?? this.consumption,
      date: date ?? this.date,
    );
  }
}
