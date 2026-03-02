/// MetricModel represents a single performance snapshot for a device.
class MetricModel {
  final int     id;
  final int     deviceId;
  final double? latencyMs;
  final double? packetLossPct;
  final int?    bandwidthInBps;
  final int?    bandwidthOutBps;
  final double? cpuUsagePct;
  final double? memoryUsagePct;
  final int?    interfaceErrors;
  final int?    uptimeSeconds;
  final String  pollMethod;
  final String  recordedAt;

  const MetricModel({
    required this.id,
    required this.deviceId,
    this.latencyMs,
    this.packetLossPct,
    this.bandwidthInBps,
    this.bandwidthOutBps,
    this.cpuUsagePct,
    this.memoryUsagePct,
    this.interfaceErrors,
    this.uptimeSeconds,
    required this.pollMethod,
    required this.recordedAt,
  });

  factory MetricModel.fromJson(Map<String, dynamic> json) {
    return MetricModel(
      id:               json['id']                as int,
      deviceId:         json['device_id']         as int,
      latencyMs:        (json['latency_ms']        as num?)?.toDouble(),
      packetLossPct:    (json['packet_loss_pct']   as num?)?.toDouble(),
      bandwidthInBps:   json['bandwidth_in_bps']   as int?,
      bandwidthOutBps:  json['bandwidth_out_bps']  as int?,
      cpuUsagePct:      (json['cpu_usage_pct']     as num?)?.toDouble(),
      memoryUsagePct:   (json['memory_usage_pct']  as num?)?.toDouble(),
      interfaceErrors:  json['interface_errors']   as int?,
      uptimeSeconds:    json['uptime_seconds']     as int?,
      pollMethod:       json['poll_method']        as String,
      recordedAt:       json['recorded_at']        as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':                id,
      'device_id':         deviceId,
      'latency_ms':        latencyMs,
      'packet_loss_pct':   packetLossPct,
      'bandwidth_in_bps':  bandwidthInBps,
      'bandwidth_out_bps': bandwidthOutBps,
      'cpu_usage_pct':     cpuUsagePct,
      'memory_usage_pct':  memoryUsagePct,
      'interface_errors':  interfaceErrors,
      'uptime_seconds':    uptimeSeconds,
      'poll_method':       pollMethod,
      'recorded_at':       recordedAt,
    };
  }
}