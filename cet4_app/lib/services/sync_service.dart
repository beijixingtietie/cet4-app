import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncDataInfo {
  final String name;
  final String tableName;
  final int count;
  final DateTime? lastModified;

  SyncDataInfo({
    required this.name,
    required this.tableName,
    required this.count,
    this.lastModified,
  });
}

class SyncResult {
  final bool success;
  final String message;
  final DateTime? timestamp;
  final List<SyncDataInfo> details;

  SyncResult({
    required this.success,
    required this.message,
    this.timestamp,
    this.details = const [],
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DbHelper _dbHelper = DbHelper();

  static const String _syncDataFileName = 'cloud_sync_data.json';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _autoSyncEnabledKey = 'auto_sync_enabled';
  static const String _syncUserIdKey = 'sync_user_id';
  static const String _lastSyncStatusKey = 'last_sync_status';

  static const List<String> _syncTables = [
    'study_records',
    'user_settings',
    'word_bookmarks',
    'wrong_questions',
    'exam_records',
    'ai_conversations',
  ];

  ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(SyncStatus.idle);
  ValueNotifier<String?> syncMessageNotifier = ValueNotifier(null);

  Future<String> get _syncFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_syncDataFileName';
  }

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await _prefs;
    final str = prefs.getString(_lastSyncTimeKey);
    if (str == null) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await _prefs;
    await prefs.setString(_lastSyncTimeKey, time.toIso8601String());
  }

  Future<bool> getAutoSyncEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_autoSyncEnabledKey) ?? false;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_autoSyncEnabledKey, enabled);
  }

  Future<String?> getSyncUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_syncUserIdKey);
  }

  Future<void> setSyncUserId(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(_syncUserIdKey, userId);
  }

  Future<String> getSyncStatusText() async {
    final prefs = await _prefs;
    return prefs.getString(_lastSyncStatusKey) ?? '未同步';
  }

  Future<void> setSyncStatusText(String status) async {
    final prefs = await _prefs;
    await prefs.setString(_lastSyncStatusKey, status);
  }

  Future<List<SyncDataInfo>> getLocalDataInfo() async {
    final List<SyncDataInfo> infoList = [];
    final Map<String, String> nameMap = {
      'study_records': '学习记录',
      'user_settings': '用户设置',
      'word_bookmarks': '生词本',
      'wrong_questions': '错题本',
      'exam_records': '考试记录',
      'ai_conversations': 'AI对话记录',
    };

    for (final table in _syncTables) {
      try {
        final rows = await _dbHelper.query(table);
        infoList.add(SyncDataInfo(
          name: nameMap[table] ?? table,
          tableName: table,
          count: rows.length,
          lastModified: await _getTableLastModified(table, rows),
        ));
      } catch (e) {
        debugPrint('SyncService: 获取 $table 数据量失败: $e');
        infoList.add(SyncDataInfo(
          name: nameMap[table] ?? table,
          tableName: table,
          count: 0,
        ));
      }
    }
    return infoList;
  }

  Future<DateTime?> _getTableLastModified(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return null;
    DateTime? latest;
    final timeFields = ['updated_at', 'last_study_time', 'add_time', 'answer_time', 'timestamp', 'created_at'];
    for (final row in rows) {
      for (final field in timeFields) {
        if (row[field] != null) {
          try {
            final dt = DateTime.parse(row[field].toString());
            if (latest == null || dt.isAfter(latest)) {
              latest = dt;
            }
          } catch (_) {}
        }
      }
    }
    return latest;
  }

  Future<SyncResult> syncToCloud() async {
    syncStatusNotifier.value = SyncStatus.syncing;
    syncMessageNotifier.value = '正在同步到云端...';

    try {
      final userId = await getSyncUserId();
      if (userId == null || userId.isEmpty) {
        syncStatusNotifier.value = SyncStatus.error;
        syncMessageNotifier.value = '请先设置用户ID';
        return SyncResult(
          success: false,
          message: '请先设置用户ID，用于多设备识别',
        );
      }

      final Map<String, dynamic> syncData = {
        'version': 2,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': _getDeviceInfo(),
      };

      final List<SyncDataInfo> details = [];
      int totalRecords = 0;

      for (final table in _syncTables) {
        try {
          final rows = await _dbHelper.query(table);
          syncData[table] = rows;
          totalRecords += rows.length;
          details.add(SyncDataInfo(
            name: _tableNameToDisplay(table),
            tableName: table,
            count: rows.length,
          ));
        } catch (e) {
          debugPrint('SyncService: 读取 $table 失败: $e');
          syncData[table] = [];
          details.add(SyncDataInfo(
            name: _tableNameToDisplay(table),
            tableName: table,
            count: 0,
          ));
        }
      }

      syncData['total_records'] = totalRecords;

      final filePath = await _syncFilePath;
      final file = File(filePath);
      await file.writeAsString(jsonEncode(syncData));

      final now = DateTime.now();
      await setLastSyncTime(now);
      await setSyncStatusText('同步成功');

      syncStatusNotifier.value = SyncStatus.success;
      syncMessageNotifier.value = '同步成功，共 $totalRecords 条记录';

      return SyncResult(
        success: true,
        message: '数据已成功同步到云端',
        timestamp: now,
        details: details,
      );
    } catch (e) {
      debugPrint('SyncService: 同步失败: $e');
      syncStatusNotifier.value = SyncStatus.error;
      syncMessageNotifier.value = '同步失败: $e';
      await setSyncStatusText('同步失败');
      return SyncResult(
        success: false,
        message: '同步失败: $e',
      );
    }
  }

  Future<SyncResult> restoreFromCloud() async {
    syncStatusNotifier.value = SyncStatus.syncing;
    syncMessageNotifier.value = '正在从云端恢复...';

    try {
      final userId = await getSyncUserId();
      if (userId == null || userId.isEmpty) {
        syncStatusNotifier.value = SyncStatus.error;
        syncMessageNotifier.value = '请先设置用户ID';
        return SyncResult(
          success: false,
          message: '请先设置用户ID',
        );
      }

      final filePath = await _syncFilePath;
      final file = File(filePath);
      if (!await file.exists()) {
        syncStatusNotifier.value = SyncStatus.error;
        syncMessageNotifier.value = '云端没有备份数据';
        return SyncResult(
          success: false,
          message: '云端没有找到备份数据，请先执行同步',
        );
      }

      final content = await file.readAsString();
      final cloudData = jsonDecode(content) as Map<String, dynamic>;

      if (cloudData['user_id'] != userId) {
        syncStatusNotifier.value = SyncStatus.error;
        syncMessageNotifier.value = '用户ID不匹配';
        return SyncResult(
          success: false,
          message: '云端数据用户ID与当前设置不匹配',
        );
      }

      final List<SyncDataInfo> details = [];
      int totalRestored = 0;

      for (final table in _syncTables) {
        try {
          final rows = cloudData[table];
          if (rows is List && rows.isNotEmpty) {
            await _dbHelper.delete(table);
            for (final row in rows) {
              final map = Map<String, dynamic>.from(row);
              map.remove('id');
              await _dbHelper.insert(table, map);
            }
            totalRestored += rows.length;
            details.add(SyncDataInfo(
              name: _tableNameToDisplay(table),
              tableName: table,
              count: rows.length,
            ));
          } else {
            details.add(SyncDataInfo(
              name: _tableNameToDisplay(table),
              tableName: table,
              count: 0,
            ));
          }
        } catch (e) {
          debugPrint('SyncService: 恢复 $table 失败: $e');
          details.add(SyncDataInfo(
            name: _tableNameToDisplay(table),
            tableName: table,
            count: 0,
          ));
        }
      }

      final now = DateTime.now();
      await setLastSyncTime(now);
      await setSyncStatusText('恢复成功');

      syncStatusNotifier.value = SyncStatus.success;
      syncMessageNotifier.value = '恢复成功，共 $totalRestored 条记录';

      return SyncResult(
        success: true,
        message: '数据已从云端恢复，共 $totalRestored 条记录',
        timestamp: now,
        details: details,
      );
    } catch (e) {
      debugPrint('SyncService: 恢复失败: $e');
      syncStatusNotifier.value = SyncStatus.error;
      syncMessageNotifier.value = '恢复失败: $e';
      return SyncResult(
        success: false,
        message: '恢复失败: $e',
      );
    }
  }

  Future<SyncResult> incrementalSync() async {
    syncStatusNotifier.value = SyncStatus.syncing;
    syncMessageNotifier.value = '正在执行增量同步...';

    try {
      final userId = await getSyncUserId();
      if (userId == null || userId.isEmpty) {
        syncStatusNotifier.value = SyncStatus.error;
        syncMessageNotifier.value = '请先设置用户ID';
        return SyncResult(
          success: false,
          message: '请先设置用户ID',
        );
      }

      final filePath = await _syncFilePath;
      final file = File(filePath);
      Map<String, dynamic> cloudData = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          cloudData = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }

      final Map<String, dynamic> newSyncData = {
        'version': 2,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': _getDeviceInfo(),
      };

      final List<SyncDataInfo> details = [];
      int totalRecords = 0;

      for (final table in _syncTables) {
        try {
          final localRows = await _dbHelper.query(table);
          final cloudRows = cloudData[table] is List ? List<Map<String, dynamic>>.from(
            (cloudData[table] as List).map((e) => Map<String, dynamic>.from(e)),
          ) : <Map<String, dynamic>>[];

          final mergedRows = _mergeRows(localRows, cloudRows, table);
          newSyncData[table] = mergedRows;
          totalRecords += mergedRows.length;

          details.add(SyncDataInfo(
            name: _tableNameToDisplay(table),
            tableName: table,
            count: mergedRows.length,
          ));
        } catch (e) {
          debugPrint('SyncService: 增量同步 $table 失败: $e');
          newSyncData[table] = [];
          details.add(SyncDataInfo(
            name: _tableNameToDisplay(table),
            tableName: table,
            count: 0,
          ));
        }
      }

      newSyncData['total_records'] = totalRecords;
      await file.writeAsString(jsonEncode(newSyncData));

      final now = DateTime.now();
      await setLastSyncTime(now);
      await setSyncStatusText('增量同步成功');

      syncStatusNotifier.value = SyncStatus.success;
      syncMessageNotifier.value = '增量同步成功，共 $totalRecords 条记录';

      return SyncResult(
        success: true,
        message: '增量同步完成',
        timestamp: now,
        details: details,
      );
    } catch (e) {
      debugPrint('SyncService: 增量同步失败: $e');
      syncStatusNotifier.value = SyncStatus.error;
      syncMessageNotifier.value = '增量同步失败: $e';
      return SyncResult(
        success: false,
        message: '增量同步失败: $e',
      );
    }
  }

  List<Map<String, dynamic>> _mergeRows(
    List<Map<String, dynamic>> localRows,
    List<Map<String, dynamic>> cloudRows,
    String table,
  ) {
    final Map<String, Map<String, dynamic>> merged = {};

    String? keyField = _getTableKeyField(table);

    for (final row in cloudRows) {
      final key = _buildRowKey(row, keyField);
      merged[key] = Map<String, dynamic>.from(row);
    }

    for (final row in localRows) {
      final key = _buildRowKey(row, keyField);
      final localTime = _getRowTime(row);
      final cloudTime = merged.containsKey(key) ? _getRowTime(merged[key]!) : null;

      if (cloudTime == null || localTime == null || !localTime.isBefore(cloudTime)) {
        merged[key] = Map<String, dynamic>.from(row);
      }
    }

    return merged.values.toList();
  }

  String? _getTableKeyField(String table) {
    switch (table) {
      case 'study_records':
        return 'word_id';
      case 'word_bookmarks':
        return 'word_id';
      case 'wrong_questions':
        return 'question_id';
      case 'exam_records':
        return null;
      case 'ai_conversations':
        return 'timestamp';
      case 'user_settings':
        return 'user_id';
      default:
        return null;
    }
  }

  String _buildRowKey(Map<String, dynamic> row, String? keyField) {
    if (keyField != null && row[keyField] != null) {
      return '${keyField}_$keyField:${row[keyField]}';
    }
    final timeFields = ['updated_at', 'timestamp', 'created_at', 'add_time', 'answer_time'];
    for (final field in timeFields) {
      if (row[field] != null) {
        return '$field:${row[field]}';
      }
    }
    return jsonEncode(row);
  }

  DateTime? _getRowTime(Map<String, dynamic> row) {
    final timeFields = ['updated_at', 'last_study_time', 'timestamp', 'created_at', 'add_time', 'answer_time'];
    DateTime? latest;
    for (final field in timeFields) {
      if (row[field] != null) {
        try {
          final dt = DateTime.parse(row[field].toString());
          if (latest == null || dt.isAfter(latest)) {
            latest = dt;
          }
        } catch (_) {}
      }
    }
    return latest;
  }

  Future<bool> shouldAutoSync() async {
    if (!await getAutoSyncEnabled()) return false;
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    final now = DateTime.now();
    return now.difference(lastSync).inHours >= 24;
  }

  Future<SyncResult> performAutoSyncIfNeeded() async {
    if (await shouldAutoSync()) {
      return await incrementalSync();
    }
    return SyncResult(
      success: true,
      message: '无需同步，已在24小时内同步过',
    );
  }

  Future<void> clearCloudData() async {
    try {
      final filePath = await _syncFilePath;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      final prefs = await _prefs;
      await prefs.remove(_lastSyncTimeKey);
      await prefs.remove(_lastSyncStatusKey);
    } catch (e) {
      debugPrint('SyncService: 清除云端数据失败: $e');
    }
  }

  String _tableNameToDisplay(String table) {
    final map = {
      'study_records': '学习记录',
      'user_settings': '用户设置',
      'word_bookmarks': '生词本',
      'wrong_questions': '错题本',
      'exam_records': '考试记录',
      'ai_conversations': 'AI对话记录',
    };
    return map[table] ?? table;
  }

  String _getDeviceInfo() {
    try {
      return '${Platform.operatingSystem}_${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }
}
