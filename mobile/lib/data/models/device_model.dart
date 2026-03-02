/// DeviceModel represents a network device being monitored by the ISP.
class DeviceModel {
  final int     id;
  final String  name;
  final String  ipAddress;
  final String? macAddress;
  final String  deviceType;
  final String  status;
  final String? location;
  final String? description;
  final bool    snmpEnabled;
  final String  snmpCommunity;
  final bool    isActive;
  final String? lastSeen;
  final String  createdAt;

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

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id:            json['id']             as int,
      name:          json['name']           as String,
      ipAddress:     json['ip_address']     as String,
      macAddress:    json['mac_address']    as String?,
      deviceType:    json['device_type']    as String,
      status:        json['status']         as String,
      location:      json['location']       as String?,
      description:   json['description']    as String?,
      snmpEnabled:   json['snmp_enabled']   as bool,
      snmpCommunity: json['snmp_community'] as String,
      isActive:      json['is_active']      as bool,
      lastSeen:      json['last_seen']      as String?,
      createdAt:     json['created_at']     as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':             id,
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
      'last_seen':      lastSeen,
      'created_at':     createdAt,
    };
  }
}