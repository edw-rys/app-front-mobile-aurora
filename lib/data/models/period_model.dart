class PeriodModel {
  final int periodId;
  final int? parentId;
  final String? startDate;
  final String? endDate;

  const PeriodModel({
    required this.periodId,
    this.parentId,
    this.startDate,
    this.endDate,
  });

  factory PeriodModel.fromJson(Map<String, dynamic> json) {
    return PeriodModel(
      periodId: json['period_id'] as int? ?? json['aditionalParams']?['period_id'] as int? ?? 0,
      parentId: json['parent_id'] as int?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period_id': periodId,
      'parent_id': parentId,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}
