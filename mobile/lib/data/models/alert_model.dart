/// AlertModel represents a network alert triggered when a metric
/// breaches a configured threshold.
class AlertModel {
  final int     id;
  final int     deviceId;
  final String  deviceName;   // included for display convenience
  final String  alertType;
  final String  severity;
  final String  message;
  final Map<String, dynamic>? details;
  final bool    isResolved;
  final bool    isAcknowledged;
  final String  triggeredAt;
  final String? resolvedAt;

  const AlertModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.alertType,
    required this.severity,
    required this.message,
    this.details,
    required this.isResolved,
    required this.isAcknowledged,
    required this.triggeredAt,
    this.resolvedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id:             json['id']              as int,
      deviceId:       json['device_id']       as int,
      deviceName:     json['device_name']     as String? ?? 'Unknown Device',
      alertType:      json['alert_type']      as String,
      severity:       json['severity']        as String,
      message:        json['message']         as String,
      details:        json['details']         as Map<String, dynamic>?,
      isResolved:     json['is_resolved']     as bool,
      isAcknowledged: json['is_acknowledged'] as bool,
      triggeredAt:    json['triggered_at']    as String,
      resolvedAt:     json['resolved_at']     as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':               id,
      'device_id':        deviceId,
      'device_name':      deviceName,
      'alert_type':       alertType,
      'severity':         severity,
      'message':          message,
      'details':          details,
      'is_resolved':      isResolved,
      'is_acknowledged':  isAcknowledged,
      'triggered_at':     triggeredAt,
      'resolved_at':      resolvedAt,
    };
  }
}