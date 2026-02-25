class PeriodModel {
  final int periodId;
  final int? parentId;
  final String? startDate;
  final String? endDate;
  final bool enablePhoto;
  final bool requirePhoto;

  const PeriodModel({
    required this.periodId,
    this.parentId,
    this.startDate,
    this.endDate,
    this.enablePhoto = false,
    this.requirePhoto = false,
  });

  factory PeriodModel.fromJson(Map<String, dynamic> json) {
    final params = json['aditionalParams'] as Map<String, dynamic>? ?? {};
    return PeriodModel(
      periodId: json['period_id'] as int? ?? params['period_id'] as int? ?? 0,
      parentId: json['parent_id'] as int?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      enablePhoto: params['enable_photo'] as bool? ?? false,
      requirePhoto: params['require_photo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period_id': periodId,
      'parent_id': parentId,
      'start_date': startDate,
      'end_date': endDate,
      'enable_photo': enablePhoto,
      'require_photo': requirePhoto,
    };
  }
}
