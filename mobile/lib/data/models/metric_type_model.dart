/// MetricTypeModel represents a metric definition from the API.
class MetricTypeModel {
  final int    id;
  final String name;
  final String unit;
  final String? description;

  const MetricTypeModel({
    required this.id,
    required this.name,
    required this.unit,
    this.description,
  });

  factory MetricTypeModel.fromJson(Map<String, dynamic> json) {
    return MetricTypeModel(
      id:          json['id'] as int,
      name:        json['name'] as String,
      unit:        json['unit'] as String,
      description: json['description'] as String?,
    );
  }
}
