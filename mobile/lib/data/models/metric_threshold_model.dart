/// MetricThresholdModel represents per-device threshold overrides.
class MetricThresholdModel {
  final int     id;
  final int     deviceId;
  final int     metricId;
  final String  metricName;
  final double? warningThreshold;
  final double? criticalThreshold;
  final bool    isActive;

  const MetricThresholdModel({
    required this.id,
    required this.deviceId,
    required this.metricId,
    required this.metricName,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.isActive,
  });

  factory MetricThresholdModel.fromJson(Map<String, dynamic> json) {
    return MetricThresholdModel(
      id:                json['id'] as int,
      deviceId:          json['device'] as int,
      metricId:          json['metric'] as int,
      metricName:        json['metric_name'] as String? ?? '',
      warningThreshold:  (json['warning_threshold'] as num?)?.toDouble(),
      criticalThreshold: (json['critical_threshold'] as num?)?.toDouble(),
      isActive:          json['is_active'] as bool? ?? true,
    );
  }
}
