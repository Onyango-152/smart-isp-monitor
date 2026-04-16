/// MetricPredictionModel represents a short-horizon prediction for a device metric.
class MetricPredictionModel {
  final int    id;
  final int    deviceId;
  final String deviceName;
  final int    metricId;
  final String metricName;
  final String metricUnit;
  final double predictedValue;
  final double slopePerMin;
  final String riskLevel;
  final int    horizonMinutes;
  final String generatedAt;

  const MetricPredictionModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.metricId,
    required this.metricName,
    required this.metricUnit,
    required this.predictedValue,
    required this.slopePerMin,
    required this.riskLevel,
    required this.horizonMinutes,
    required this.generatedAt,
  });

  factory MetricPredictionModel.fromJson(Map<String, dynamic> json) {
    return MetricPredictionModel(
      id:             json['id'] as int,
      deviceId:       json['device'] as int,
      deviceName:     json['device_name'] as String? ?? 'Unknown Device',
      metricId:       json['metric'] as int,
      metricName:     json['metric_name'] as String? ?? '',
      metricUnit:     json['metric_unit'] as String? ?? '',
      predictedValue: (json['predicted_value'] as num).toDouble(),
      slopePerMin:    (json['slope_per_min'] as num).toDouble(),
      riskLevel:      json['risk_level'] as String,
      horizonMinutes: json['horizon_minutes'] as int? ?? 60,
      generatedAt:    json['generated_at'] as String,
    );
  }
}
