import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../data/models/device_model.dart';
import '../data/models/alert_model.dart';
import '../data/models/task_model.dart';
import '../data/models/user_model.dart';

/// DatabaseHelper is a singleton that manages the local SQLite database.
///
/// It provides the offline cache for the four core data types:
///   devices, alerts, tasks, and clients (customers).
///
/// Usage pattern in providers:
///   1. Try to load from cache immediately (instant display).
///   2. Fetch from API in background.
///   3. On success, write to cache and refresh UI.
///   4. On failure with no network, fall back to cached data.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName    = 'smart_isp.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  // ── Open / Create ─────────────────────────────────────────────────────────

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path   = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        id            INTEGER PRIMARY KEY,
        name          TEXT    NOT NULL,
        ip_address    TEXT    NOT NULL,
        mac_address   TEXT,
        device_type   TEXT    NOT NULL,
        status        TEXT    NOT NULL,
        location      TEXT,
        description   TEXT,
        snmp_enabled  INTEGER NOT NULL DEFAULT 1,
        snmp_community TEXT   NOT NULL DEFAULT 'public',
        is_active     INTEGER NOT NULL DEFAULT 1,
        last_seen     TEXT,
        created_at    TEXT    NOT NULL,
        cached_at     TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id               INTEGER PRIMARY KEY,
        device_id        INTEGER NOT NULL,
        device_name      TEXT    NOT NULL,
        alert_type       TEXT    NOT NULL,
        severity         TEXT    NOT NULL,
        message          TEXT    NOT NULL,
        details          TEXT,
        is_resolved      INTEGER NOT NULL DEFAULT 0,
        is_acknowledged  INTEGER NOT NULL DEFAULT 0,
        triggered_at     TEXT    NOT NULL,
        resolved_at      TEXT,
        cached_at        TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id            INTEGER PRIMARY KEY,
        name          TEXT    NOT NULL,
        description   TEXT,
        device_id     INTEGER,
        device_name   TEXT,
        task_type     TEXT    NOT NULL,
        interval_secs INTEGER NOT NULL DEFAULT 300,
        timeout_secs  INTEGER NOT NULL DEFAULT 5,
        enabled       INTEGER NOT NULL DEFAULT 1,
        last_run      TEXT,
        last_status   TEXT    NOT NULL DEFAULT 'pending',
        created_at    TEXT    NOT NULL,
        updated_at    TEXT,
        cached_at     TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id           INTEGER PRIMARY KEY,
        email        TEXT    NOT NULL,
        username     TEXT    NOT NULL,
        role         TEXT    NOT NULL DEFAULT 'customer',
        is_active    INTEGER NOT NULL DEFAULT 1,
        plan         TEXT    NOT NULL DEFAULT 'Home Basic',
        device_ids   TEXT    NOT NULL DEFAULT '[]',
        fcm_token    TEXT,
        date_joined  TEXT,
        last_login   TEXT,
        cached_at    TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_alerts_device   ON alerts(device_id);
      ''');
    await db.execute('''
      CREATE INDEX idx_tasks_device    ON tasks(device_id);
      ''');
    await db.execute('''
      CREATE INDEX idx_alerts_severity ON alerts(severity);
      ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Drop and recreate on schema change during development.
    await db.execute('DROP TABLE IF EXISTS devices');
    await db.execute('DROP TABLE IF EXISTS alerts');
    await db.execute('DROP TABLE IF EXISTS tasks');
    await db.execute('DROP TABLE IF EXISTS clients');
    await _onCreate(db, newVersion);
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  static String _now() => DateTime.now().toUtc().toIso8601String();

  // ═════════════════════════════════════════════════════════════════════════
  // DEVICES
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> cacheDevices(List<DeviceModel> devices) async {
    final db = await database;
    final batch = db.batch();
    for (final d in devices) {
      batch.insert(
        'devices',
        {
          'id':            d.id,
          'name':          d.name,
          'ip_address':    d.ipAddress,
          'mac_address':   d.macAddress,
          'device_type':   d.deviceType,
          'status':        d.status,
          'location':      d.location,
          'description':   d.description,
          'snmp_enabled':  d.snmpEnabled  ? 1 : 0,
          'snmp_community': d.snmpCommunity,
          'is_active':     d.isActive     ? 1 : 0,
          'last_seen':     d.lastSeen,
          'created_at':    d.createdAt,
          'cached_at':     _now(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<DeviceModel>> getCachedDevices() async {
    final db   = await database;
    final rows = await db.query('devices', orderBy: 'name ASC');
    return rows.map(_deviceFromRow).toList();
  }

  Future<void> upsertDevice(DeviceModel d) async {
    final db = await database;
    await db.insert(
      'devices',
      {
        'id':            d.id,
        'name':          d.name,
        'ip_address':    d.ipAddress,
        'mac_address':   d.macAddress,
        'device_type':   d.deviceType,
        'status':        d.status,
        'location':      d.location,
        'description':   d.description,
        'snmp_enabled':  d.snmpEnabled  ? 1 : 0,
        'snmp_community': d.snmpCommunity,
        'is_active':     d.isActive     ? 1 : 0,
        'last_seen':     d.lastSeen,
        'created_at':    d.createdAt,
        'cached_at':     _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDevice(int id) async {
    final db = await database;
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  DeviceModel _deviceFromRow(Map<String, dynamic> r) {
    return DeviceModel(
      id:            r['id']            as int,
      name:          r['name']          as String,
      ipAddress:     r['ip_address']    as String,
      macAddress:    r['mac_address']   as String?,
      deviceType:    r['device_type']   as String,
      status:        r['status']        as String,
      location:      r['location']      as String?,
      description:   r['description']   as String?,
      snmpEnabled:   (r['snmp_enabled']  as int) == 1,
      snmpCommunity: r['snmp_community'] as String,
      isActive:      (r['is_active']     as int) == 1,
      lastSeen:      r['last_seen']      as String?,
      createdAt:     r['created_at']     as String,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ALERTS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> cacheAlerts(List<AlertModel> alerts) async {
    final db    = await database;
    final batch = db.batch();
    for (final a in alerts) {
      batch.insert(
        'alerts',
        {
          'id':              a.id,
          'device_id':       a.deviceId,
          'device_name':     a.deviceName,
          'alert_type':      a.alertType,
          'severity':        a.severity,
          'message':         a.message,
          'details':         a.details != null ? jsonEncode(a.details) : null,
          'is_resolved':     a.isResolved     ? 1 : 0,
          'is_acknowledged': a.isAcknowledged ? 1 : 0,
          'triggered_at':    a.triggeredAt,
          'resolved_at':     a.resolvedAt,
          'cached_at':       _now(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AlertModel>> getCachedAlerts() async {
    final db   = await database;
    final rows = await db.query('alerts', orderBy: 'triggered_at DESC');
    return rows.map(_alertFromRow).toList();
  }

  Future<void> upsertAlert(AlertModel a) async {
    final db = await database;
    await db.insert(
      'alerts',
      {
        'id':              a.id,
        'device_id':       a.deviceId,
        'device_name':     a.deviceName,
        'alert_type':      a.alertType,
        'severity':        a.severity,
        'message':         a.message,
        'details':         a.details != null ? jsonEncode(a.details) : null,
        'is_resolved':     a.isResolved     ? 1 : 0,
        'is_acknowledged': a.isAcknowledged ? 1 : 0,
        'triggered_at':    a.triggeredAt,
        'resolved_at':     a.resolvedAt,
        'cached_at':       _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAlert(int id) async {
    final db = await database;
    await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }

  AlertModel _alertFromRow(Map<String, dynamic> r) {
    return AlertModel(
      id:              r['id']              as int,
      deviceId:        r['device_id']       as int,
      deviceName:      r['device_name']     as String,
      alertType:       r['alert_type']      as String,
      severity:        r['severity']        as String,
      message:         r['message']         as String,
      details:         r['details'] != null
          ? Map<String, dynamic>.from(jsonDecode(r['details'] as String))
          : null,
      isResolved:      (r['is_resolved']     as int) == 1,
      isAcknowledged:  (r['is_acknowledged'] as int) == 1,
      triggeredAt:     r['triggered_at']    as String,
      resolvedAt:      r['resolved_at']     as String?,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TASKS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> cacheTasks(List<TaskModel> tasks) async {
    final db    = await database;
    final batch = db.batch();
    for (final t in tasks) {
      batch.insert(
        'tasks',
        _taskToRow(t),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TaskModel>> getCachedTasks() async {
    final db   = await database;
    final rows = await db.query('tasks', orderBy: 'name ASC');
    return rows.map(_taskFromRow).toList();
  }

  Future<void> upsertTask(TaskModel t) async {
    final db = await database;
    await db.insert('tasks', _taskToRow(t),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, dynamic> _taskToRow(TaskModel t) => {
    'id':           t.id,
    'name':         t.name,
    'description':  t.description,
    'device_id':    t.deviceId,
    'device_name':  t.deviceName,
    'task_type':    t.taskType,
    'interval_secs': t.intervalSecs,
    'timeout_secs':  t.timeoutSecs,
    'enabled':      t.enabled    ? 1 : 0,
    'last_run':     t.lastRun,
    'last_status':  t.lastStatus,
    'created_at':   t.createdAt,
    'updated_at':   t.updatedAt,
    'cached_at':    _now(),
  };

  TaskModel _taskFromRow(Map<String, dynamic> r) {
    return TaskModel(
      id:           r['id']           as int,
      name:         r['name']         as String,
      description:  r['description']  as String?,
      deviceId:     r['device_id']    as int?,
      deviceName:   r['device_name']  as String?,
      taskType:     r['task_type']    as String,
      intervalSecs: r['interval_secs'] as int,
      timeoutSecs:  r['timeout_secs']  as int,
      enabled:      (r['enabled']      as int) == 1,
      lastRun:      r['last_run']      as String?,
      lastStatus:   r['last_status']   as String,
      createdAt:    r['created_at']    as String,
      updatedAt:    r['updated_at']    as String?,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CLIENTS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> cacheClients(
    List<UserModel> clients, {
    required Map<int, String>   plans,
    required Map<int, List<int>> deviceIds,
  }) async {
    final db    = await database;
    final batch = db.batch();
    for (final c in clients) {
      batch.insert(
        'clients',
        {
          'id':          c.id,
          'email':       c.email,
          'username':    c.username,
          'role':        c.role,
          'is_active':   c.isActive  ? 1 : 0,
          'plan':        plans[c.id]     ?? 'Home Basic',
          'device_ids':  jsonEncode(deviceIds[c.id] ?? []),
          'fcm_token':   c.fcmToken,
          'date_joined': c.dateJoined,
          'last_login':  c.lastLogin,
          'cached_at':   _now(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<UserModel>> getCachedClients() async {
    final db   = await database;
    final rows = await db.query('clients',
        where: "role = 'customer'", orderBy: 'username ASC');
    return rows.map(_clientFromRow).toList();
  }

  /// Returns plan name for a cached client.
  Future<String> getCachedClientPlan(int clientId) async {
    final db   = await database;
    final rows = await db.query('clients',
        columns: ['plan'], where: 'id = ?', whereArgs: [clientId]);
    return rows.isNotEmpty ? rows.first['plan'] as String : 'Home Basic';
  }

  /// Returns device ID list for a cached client.
  Future<List<int>> getCachedClientDeviceIds(int clientId) async {
    final db   = await database;
    final rows = await db.query('clients',
        columns: ['device_ids'], where: 'id = ?', whereArgs: [clientId]);
    if (rows.isEmpty) return [];
    final raw = rows.first['device_ids'] as String;
    return List<int>.from(jsonDecode(raw));
  }

  Future<void> upsertClient(
    UserModel c, {
    required String   plan,
    required List<int> deviceIds,
  }) async {
    final db = await database;
    await db.insert(
      'clients',
      {
        'id':          c.id,
        'email':       c.email,
        'username':    c.username,
        'role':        c.role,
        'is_active':   c.isActive  ? 1 : 0,
        'plan':        plan,
        'device_ids':  jsonEncode(deviceIds),
        'fcm_token':   c.fcmToken,
        'date_joined': c.dateJoined,
        'last_login':  c.lastLogin,
        'cached_at':   _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteClient(int id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  UserModel _clientFromRow(Map<String, dynamic> r) {
    return UserModel(
      id:         r['id']          as int,
      email:      r['email']       as String,
      username:   r['username']    as String,
      role:       r['role']        as String,
      isActive:   (r['is_active']  as int) == 1,
      fcmToken:   r['fcm_token']   as String?,
      dateJoined: r['date_joined'] as String?,
      lastLogin:  r['last_login']  as String?,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ═════════════════════════════════════════════════════════════════════════

  /// Wipes all cached data — useful for logout or forced refresh.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('devices');
    await db.delete('alerts');
    await db.delete('tasks');
    await db.delete('clients');
  }

  /// Closes the database connection (call on app teardown).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
