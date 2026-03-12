/// TaskModel represents a scheduled monitoring task.
///
/// Maps to the Django MonitoringTask model:
///   name, description, device (FK), task_type, interval, timeout,
///   enabled, last_run, last_status, created_at, updated_at.
class TaskModel {
  final int     id;
  final String  name;
  final String? description;
  final int?    deviceId;
  final String? deviceName;
  final String  taskType;     // snmp, ping, http, tcp, dns
  final int     intervalSecs; // polling interval in seconds
  final int     timeoutSecs;
  final bool    enabled;
  final String? lastRun;      // ISO 8601
  final String  lastStatus;   // success, failed, pending
  final String  createdAt;    // ISO 8601
  final String? updatedAt;

  const TaskModel({
    required this.id,
    required this.name,
    this.description,
    this.deviceId,
    this.deviceName,
    required this.taskType,
    required this.intervalSecs,
    this.timeoutSecs = 5,
    required this.enabled,
    this.lastRun,
    this.lastStatus = 'pending',
    required this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id:           json['id']            as int,
      name:         json['name']          as String,
      description:  json['description']   as String?,
      deviceId:     json['device']        as int?,
      deviceName:   json['device_name']   as String?,
      taskType:     json['task_type']     as String,
      intervalSecs: json['interval']      as int,
      timeoutSecs:  (json['timeout']      as int?) ?? 5,
      enabled:      json['enabled']       as bool,
      lastRun:      json['last_run']      as String?,
      lastStatus:   (json['last_status']  as String?) ?? 'pending',
      createdAt:    json['created_at']    as String,
      updatedAt:    json['updated_at']    as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':          id,
      'name':        name,
      'description': description,
      'device':      deviceId,
      'device_name': deviceName,
      'task_type':   taskType,
      'interval':    intervalSecs,
      'timeout':     timeoutSecs,
      'enabled':     enabled,
      'last_run':    lastRun,
      'last_status': lastStatus,
      'created_at':  createdAt,
      'updated_at':  updatedAt,
    };
  }

  TaskModel copyWith({
    String? name,
    String? description,
    int?    deviceId,
    String? deviceName,
    String? taskType,
    int?    intervalSecs,
    int?    timeoutSecs,
    bool?   enabled,
    String? lastRun,
    String? lastStatus,
    String? updatedAt,
  }) {
    return TaskModel(
      id:           id,
      name:         name          ?? this.name,
      description:  description   ?? this.description,
      deviceId:     deviceId      ?? this.deviceId,
      deviceName:   deviceName    ?? this.deviceName,
      taskType:     taskType      ?? this.taskType,
      intervalSecs: intervalSecs  ?? this.intervalSecs,
      timeoutSecs:  timeoutSecs   ?? this.timeoutSecs,
      enabled:      enabled       ?? this.enabled,
      lastRun:      lastRun       ?? this.lastRun,
      lastStatus:   lastStatus    ?? this.lastStatus,
      createdAt:    createdAt,
      updatedAt:    updatedAt     ?? this.updatedAt,
    );
  }
}
