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
  final int?    macTableEntries;
  final double? powerLoadPct;
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
    this.macTableEntries,
    this.powerLoadPct,
    required this.pollMethod,
    required this.recordedAt,
  });

  factory MetricModel.fromJson(Map<String, dynamic> json) {
    return MetricModel(
      id:               json['id']                as int,
      deviceId:         json['device_id']         as int,
      latencyMs:        (json['latency_ms']        as num?)?.toDouble(),
      packetLossPct:    (json['packet_loss_pct']   as num?)?.toDouble(),
      bandwidthInBps:   (json['bandwidth_in_bps']  as num?)?.toInt(),
      bandwidthOutBps:  (json['bandwidth_out_bps'] as num?)?.toInt(),
      cpuUsagePct:      (json['cpu_usage_pct']     as num?)?.toDouble(),
      memoryUsagePct:   (json['memory_usage_pct']  as num?)?.toDouble(),
      interfaceErrors:  (json['interface_errors']  as num?)?.toInt(),
      uptimeSeconds:    (json['uptime_seconds']    as num?)?.toInt(),
      macTableEntries:  (json['mac_table_entries'] as num?)?.toInt(),
      powerLoadPct:     (json['power_load_pct']    as num?)?.toDouble(),
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
      'mac_table_entries': macTableEntries,
      'power_load_pct':    powerLoadPct,
      'poll_method':       pollMethod,
      'recorded_at':       recordedAt,
    };
  }
}