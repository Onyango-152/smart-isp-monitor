/// DeviceModel — mirrors the Django Device serializer response.
///
/// Django field names (snake_case) → Dart field names (camelCase):
///   id               → id
///   name             → name
///   ip_address       → ipAddress
///   mac_address      → macAddress
///   device_type      → deviceType   (slug: router / switch / olt / access_point)
///   status           → status       (online / offline / degraded / maintenance / unknown)
///   location         → location
///   description      → description
///   snmp_enabled     → snmpEnabled
///   snmp_community   → snmpCommunity
///   is_active        → isActive
///   last_seen        → lastSeen     (ISO-8601 string or null)
///   created_at       → createdAt    (ISO-8601 string)

class DeviceModel {
  final int    id;
  final String name;
  final String ipAddress;
  final String? macAddress;
  final String deviceType;
  final String status;
  final String? location;
  final String? description;
  final bool   snmpEnabled;
  final String snmpCommunity;
  final bool   isActive;
  final String? lastSeen;
  final String createdAt;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.macAddress,
    required this.deviceType,
    required this.status,
    this.location,
    this.description,
    required this.snmpEnabled,
    required this.snmpCommunity,
    required this.isActive,
    this.lastSeen,
    required this.createdAt,
  });

  // ── Deserialise from Django JSON response ─────────────────────────────────

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    // device_type can come back as a nested object {id, name, slug} or as a
    // plain slug string depending on the serializer depth.
    String resolveDeviceType(dynamic raw) {
      if (raw is String) return raw;
      if (raw is Map) {
        // Try slug first, fall back to name lowercased.
        return (raw['slug'] ?? raw['name'] ?? 'unknown')
            .toString()
            .toLowerCase()
            .replaceAll(' ', '_');
      }
      return 'unknown';
    }

    return DeviceModel(
      id:            json['id'] as int,
      name:          json['name'] as String,
      ipAddress:     json['ip_address'] as String,
      macAddress:    json['mac_address'] as String?,
      deviceType:    resolveDeviceType(json['device_type']),
      status:        (json['status'] as String?) ?? 'unknown',
      location:      json['location'] as String?,
      description:   json['description'] as String?,
      snmpEnabled:   (json['snmp_enabled'] as bool?) ?? false,
      snmpCommunity: (json['snmp_community'] as String?) ?? 'public',
      isActive:      (json['is_active'] as bool?) ?? true,
      lastSeen:      json['last_seen'] as String?,
      createdAt:     (json['created_at'] as String?) ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ── Serialise for POST / PUT to Django ────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name':           name,
        'ip_address':     ipAddress,
        'mac_address':    macAddress,
        'device_type':    deviceType,
        'status':         status,
        'location':       location,
        'description':    description,
        'snmp_enabled':   snmpEnabled,
        'snmp_community': snmpCommunity,
        'is_active':      isActive,
      };

  // ── copyWith ──────────────────────────────────────────────────────────────

  DeviceModel copyWith({
    int?    id,
    String? name,
    String? ipAddress,
    String? macAddress,
    String? deviceType,
    String? status,
    String? location,
    String? description,
    bool?   snmpEnabled,
    String? snmpCommunity,
    bool?   isActive,
    String? lastSeen,
    String? createdAt,
  }) {
    return DeviceModel(
      id:            id            ?? this.id,
      name:          name          ?? this.name,
      ipAddress:     ipAddress     ?? this.ipAddress,
      macAddress:    macAddress    ?? this.macAddress,
      deviceType:    deviceType    ?? this.deviceType,
      status:        status        ?? this.status,
      location:      location      ?? this.location,
      description:   description   ?? this.description,
      snmpEnabled:   snmpEnabled   ?? this.snmpEnabled,
      snmpCommunity: snmpCommunity ?? this.snmpCommunity,
      isActive:      isActive      ?? this.isActive,
      lastSeen:      lastSeen      ?? this.lastSeen,
      createdAt:     createdAt     ?? this.createdAt,
    );
  }
}

// ── DiagnosticSnapshot — used by DeviceDetailProvider ─────────────────────────

class DiagnosticSnapshot {
  final DateTime timestamp;
  final bool     passed;
  final double?  avgLatency;
  final double   packetLossPct;

  const DiagnosticSnapshot({
    required this.timestamp,
    required this.passed,
    this.avgLatency,
    required this.packetLossPct,
  });
}