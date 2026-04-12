class LocationPointModel {
  final double lat;
  final double lon;
  final bool read;
  final String? nAbonado;
  final String? readAt;

  LocationPointModel({
    required this.lat,
    required this.lon,
    this.read = false,
    this.nAbonado,
    this.readAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'read': read,
      if (nAbonado != null) 'n_abonado': nAbonado,
      if (readAt != null) 'read_at': readAt,
    };
  }

  factory LocationPointModel.fromJson(Map<String, dynamic> json) {
    return LocationPointModel(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      read: json['read'] == true || json['read'] == 1,
      nAbonado: json['n_abonado'] as String?,
      readAt: json['read_at'] as String?,
    );
  }
}

class UserLocationTraceModel {
  final int readingPeriodId;
  final String timezone;
  final List<LocationPointModel> locations;

  UserLocationTraceModel({
    required this.readingPeriodId,
    required this.timezone,
    required this.locations,
  });

  Map<String, dynamic> toJson() {
    return {
      'reading_period_id': readingPeriodId,
      'timezone': timezone,
      'locations': locations.map((e) => e.toJson()).toList(),
    };
  }

  factory UserLocationTraceModel.fromJson(Map<String, dynamic> json) {
    var locsList = json['locations'] as List<dynamic>?;
    List<LocationPointModel> locs = [];
    if (locsList != null) {
      locs = locsList.map((e) => LocationPointModel.fromJson(e)).toList();
    }
    
    return UserLocationTraceModel(
      readingPeriodId: json['reading_period_id'] as int,
      timezone: json['timezone'] as String,
      locations: locs,
    );
  }
}
