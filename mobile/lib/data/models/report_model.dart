/// ReportModel represents a generated network performance report.
///
/// Reports are periodic summaries (daily / weekly / monthly) of
/// network health, device status, alert activity, and key KPIs.
class ReportModel {
  final int     id;
  final String  title;
  final String  type;         // 'daily', 'weekly', 'monthly'
  final String  status;       // 'completed', 'generating', 'failed'
  final String  periodStart;  // ISO 8601
  final String  periodEnd;    // ISO 8601
  final String  generatedAt;  // ISO 8601
  final double  uptimePct;
  final double  avgLatencyMs;
  final int     totalAlerts;
  final int     resolvedAlerts;
  final int     totalDevices;
  final int     onlineDevices;
  final int     offlineDevices;
  final int     degradedDevices;
  final double  avgMttrMinutes;
  final int     totalFaults;
  final List<Map<String, dynamic>>? dailyLatency;   // [{date, value}]
  final List<Map<String, dynamic>>? alertsBySeverity; // [{severity, count}]

  const ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.uptimePct,
    required this.avgLatencyMs,
    required this.totalAlerts,
    required this.resolvedAlerts,
    required this.totalDevices,
    required this.onlineDevices,
    required this.offlineDevices,
    required this.degradedDevices,
    required this.avgMttrMinutes,
    required this.totalFaults,
    this.dailyLatency,
    this.alertsBySeverity,
  });

  double get resolutionRate =>
      totalAlerts > 0 ? (resolvedAlerts / totalAlerts * 100) : 100.0;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id:              json['id']               as int,
      title:           json['title']            as String,
      type:            json['type']             as String,
      status:          json['status']           as String,
      periodStart:     json['period_start']     as String,
      periodEnd:       json['period_end']       as String,
      generatedAt:     json['generated_at']     as String,
      uptimePct:       (json['uptime_pct']      as num).toDouble(),
      avgLatencyMs:    (json['avg_latency_ms']  as num).toDouble(),
      totalAlerts:     json['total_alerts']     as int,
      resolvedAlerts:  json['resolved_alerts']  as int,
      totalDevices:    json['total_devices']    as int,
      onlineDevices:   json['online_devices']   as int,
      offlineDevices:  json['offline_devices']  as int,
      degradedDevices: json['degraded_devices'] as int,
      avgMttrMinutes:  (json['avg_mttr_minutes'] as num).toDouble(),
      totalFaults:     json['total_faults']     as int,
      dailyLatency:    (json['daily_latency'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e)).toList(),
      alertsBySeverity: (json['alerts_by_severity'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':                id,
      'title':             title,
      'type':              type,
      'status':            status,
      'period_start':      periodStart,
      'period_end':        periodEnd,
      'generated_at':      generatedAt,
      'uptime_pct':        uptimePct,
      'avg_latency_ms':    avgLatencyMs,
      'total_alerts':      totalAlerts,
      'resolved_alerts':   resolvedAlerts,
      'total_devices':     totalDevices,
      'online_devices':    onlineDevices,
      'offline_devices':   offlineDevices,
      'degraded_devices':  degradedDevices,
      'avg_mttr_minutes':  avgMttrMinutes,
      'total_faults':      totalFaults,
      'daily_latency':     dailyLatency,
      'alerts_by_severity': alertsBySeverity,
    };
  }
}
