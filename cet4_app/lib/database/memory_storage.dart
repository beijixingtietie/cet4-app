import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web 平台内存存储，使用 SharedPreferences 持久化
/// - words 表按首字母分片（a-z, other），增量持久化
/// - words 表懒加载 + 索引缓存
/// - 其他表保持原存储方式
/// - 大表支持 800KB 分片存储，避免 SharedPreferences 单 key 1MB 限制
class MemoryStorage {
  static final MemoryStorage _instance = MemoryStorage._internal();
  factory MemoryStorage() => _instance;
  MemoryStorage._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  /// 内存表数据
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  int _nextId = 1000;

  /// words 表分片加载状态
  bool _wordsLoaded = false;
  static const Set<String> _shardableTables = {'words'};

  /// words 索引缓存
  final Map<int, Map<String, dynamic>> _wordIdIndex = {};
  final Map<String, Map<String, dynamic>> _wordTextIndex = {};

  /// 分片大小限制：800KB（预留安全余量，低于 1MB）
  static const int _maxShardBytes = 800 * 1024;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;

    // 加载小表（words 懒加载）
    const smallTables = [
      'user_settings', 'word_bookmarks', 'wrong_questions',
      'study_records', 'ai_conversations', 'ai_corrections',
      'exam_records', 'questions',
    ];
    for (final table in smallTables) {
      await _loadTable(table);
    }

    debugPrint('MemoryStorage: initialized (words lazy)');
  }

  // ========== Shard Helpers ==========

  static String _shardKeyForWord(String word) {
    if (word.isEmpty) return '_other';
    final first = word[0].toLowerCase();
    if (first.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
        first.codeUnitAt(0) <= 'z'.codeUnitAt(0)) {
      return '_$first';
    }
    return '_other';
  }

  static String _shardTableName(String sliceKey) => 'words$sliceKey';

  static List<String> _allWordShardKeys() {
    final keys = <String>[];
    for (int c = 97; c <= 122; c++) {
      keys.add('_${String.fromCharCode(c)}');
    }
    keys.add('_other');
    return keys;
  }

  void _ensureWordsLoaded() {
    if (_wordsLoaded) return;
    // 迁移旧格式数据
    _migrateWordsIfNeeded();
    for (final sliceKey in _allWordShardKeys()) {
      _loadTable(_shardTableName(sliceKey));
    }
    _wordsLoaded = true;
  }

  void _migrateWordsIfNeeded() {
    final oldData = _prefs?.getString('mem_words');
    if (oldData == null) return;
    try {
      final list = jsonDecode(oldData) as List;
      final words = list.map((e) => Map<String, dynamic>.from(e)).toList();
      debugPrint('MemoryStorage: auto-migrating ${words.length} words to shards');
      final shards = <String, List<Map<String, dynamic>>>{};
      for (final w in words) {
        final word = (w['word'] as String?) ?? '';
        shards.putIfAbsent(_shardKeyForWord(word), () => []).add(w);
      }
      for (final entry in shards.entries) {
        final shardName = _shardTableName(entry.key);
        _tables[shardName] = entry.value;
        _saveTableWithChunking(shardName);
      }
      _prefs?.remove('mem_words');
      debugPrint('MemoryStorage: auto-migration done (${shards.length} shards)');
    } catch (e) {
      debugPrint('MemoryStorage: auto-migration failed: $e');
    }
  }

  void _ensureWordsIndexBuilt() {
    _ensureWordsLoaded();
    if (_wordIdIndex.isNotEmpty) return; // already built
    _wordIdIndex.clear();
    _wordTextIndex.clear();
    for (final sliceKey in _allWordShardKeys()) {
      final rows = _tables[_shardTableName(sliceKey)] ?? [];
      for (final row in rows) {
        final id = row['id'] as int?;
        final word = (row['word'] as String?)?.toLowerCase();
        if (id != null) _wordIdIndex[id] = row;
        if (word != null && word.isNotEmpty) _wordTextIndex[word] = row;
      }
    }
  }

  void _invalidateWordsIndex() {
    _wordIdIndex.clear();
    _wordTextIndex.clear();
  }

  List<Map<String, dynamic>> _allWordRows() {
    _ensureWordsLoaded();
    final result = <Map<String, dynamic>>[];
    for (final sliceKey in _allWordShardKeys()) {
      result.addAll(_tables[_shardTableName(sliceKey)] ?? []);
    }
    return result;
  }

  // ========== Persistence ==========

  Future<void> _loadTable(String table) async {
    // 尝试加载分片数据（支持大表分片）
    final chunks = <String>[];
    int idx = 0;
    while (true) {
      final chunk = _prefs?.getString('mem_${table}_chunk_$idx');
      if (chunk == null) break;
      chunks.add(chunk);
      idx++;
    }

    if (chunks.isNotEmpty) {
      try {
        final json = chunks.join();
        final list = jsonDecode(json) as List;
        _tables[table] = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return;
      } catch (_) {
        // fallthrough to simple key
      }
    }

    final json = _prefs?.getString('mem_$table');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _tables[table] = list.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        _tables[table] = [];
      }
    } else {
      _tables[table] = [];
    }
  }

  Future<void> _saveTable(String table) async {
    final data = _tables[table] ?? [];
    await _saveTableWithChunking(table, data: data);
  }

  Future<void> _saveWordsShard(String sliceKey) async {
    final name = _shardTableName(sliceKey);
    final data = _tables[name] ?? [];
    await _saveTableWithChunking(name, data: data);
  }

  /// 通用分片保存逻辑：当 JSON 超过 800KB 时拆分为多个 key 存储
  Future<void> _saveTableWithChunking(String table, {List<Map<String, dynamic>>? data}) async {
    final rows = data ?? _tables[table] ?? [];
    final json = jsonEncode(rows);
    final bytes = utf8.encode(json);

    // 清除旧分片
    int idx = 0;
    while (_prefs?.containsKey('mem_${table}_chunk_$idx') ?? false) {
      await _prefs?.remove('mem_${table}_chunk_$idx');
      idx++;
    }
    // 清除旧单 key
    await _prefs?.remove('mem_$table');

    if (bytes.length <= _maxShardBytes) {
      await _prefs?.setString('mem_$table', json);
    } else {
      final total = bytes.length;
      int offset = 0;
      int chunkIndex = 0;
      while (offset < total) {
        final end = min(offset + _maxShardBytes, total);
        final chunk = utf8.decode(bytes.sublist(offset, end));
        await _prefs?.setString('mem_${table}_chunk_$chunkIndex', chunk);
        chunkIndex++;
        offset = end;
      }
    }
  }

  void _saveWordsIfNeeded(String table) {
    // No-op for individual saves on sharded tables — handled by callers
  }

  // ========== Query ==========

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (!_initialized) await init();

    List<Map<String, dynamic>> rows;

    if (_shardableTables.contains(table)) {
      // 尝试用索引加速
      if (where == 'word = ?' && whereArgs != null && whereArgs.isNotEmpty) {
        _ensureWordsIndexBuilt();
        final wordKey = (whereArgs[0] as String).toLowerCase();
        final hit = _wordTextIndex[wordKey];
        rows = hit != null ? [Map<String, dynamic>.from(hit)] : [];
      } else if (where == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
        _ensureWordsIndexBuilt();
        final id = whereArgs[0] as int;
        final hit = _wordIdIndex[id];
        rows = hit != null ? [Map<String, dynamic>.from(hit)] : [];
      } else {
        rows = List<Map<String, dynamic>>.from(_allWordRows());
      }
    } else {
      rows = List<Map<String, dynamic>>.from(_tables[table] ?? []);
    }

    // WHERE
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      rows = _applyWhere(rows, where, whereArgs);
    }

    // ORDER BY
    if (orderBy != null) {
      rows = _applyOrderBy(rows, orderBy);
    }

    // Offset / Limit
    if (offset != null) {
      rows = rows.skip(offset).toList();
    }
    if (limit != null) {
      rows = rows.take(limit).toList();
    }

    return rows;
  }

  List<Map<String, dynamic>> _applyWhere(
    List<Map<String, dynamic>> rows,
    String where,
    List<dynamic> whereArgs,
  ) {
    final parts = where.split(' AND ');
    return rows.where((row) {
      int argIndex = 0;
      for (final part in parts) {
        final match = RegExp(r"(\w+)\s*=\s*\?").firstMatch(part.trim());
        if (match != null) {
          final colName = match.group(1)!;
          if (argIndex >= whereArgs.length) return false;
          final argValue = whereArgs[argIndex++];
          if (row[colName] != argValue) return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _applyOrderBy(
    List<Map<String, dynamic>> rows,
    String orderBy,
  ) {
    final upper = orderBy.toUpperCase();
    final isDesc = upper.endsWith(' DESC');
    final colName = orderBy.split(' ')[0].trim();
    rows.sort((a, b) {
      final aVal = a[colName];
      final bVal = b[colName];
      if (aVal is Comparable && bVal is Comparable) {
        return isDesc ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      }
      return 0;
    });
    return rows;
  }

  // ========== Insert ==========

  Future<int> insert(String table, Map<String, dynamic> data, {bool saveNow = true}) async {
    if (!_initialized) await init();

    final id = data['id'] as int? ?? _nextIdForTable(table);
    final row = Map<String, dynamic>.from(data);
    row['id'] = id;

    if (_shardableTables.contains(table)) {
      _ensureWordsLoaded();
      final word = (row['word'] as String?) ?? '';
      final sliceKey = _shardKeyForWord(word);
      final shardName = _shardTableName(sliceKey);
      _tables.putIfAbsent(shardName, () => []);
      _tables[shardName]!.add(row);
      if (saveNow) await _saveWordsShard(sliceKey);
      // 更新索引
      if (id != null) _wordIdIndex[id] = row;
      if (word.isNotEmpty) _wordTextIndex[word.toLowerCase()] = row;
    } else {
      _tables.putIfAbsent(table, () => []);
      _tables[table]!.add(row);
      if (saveNow) await _saveTable(table);
    }

    return id;
  }

  // ========== Batch Insert ==========

  Future<void> batchInsert(String table, List<Map<String, dynamic>> dataList) async {
    if (!_initialized) await init();

    if (_shardableTables.contains(table)) {
      _ensureWordsLoaded();
      // 按分片分组
      final shards = <String, List<Map<String, dynamic>>>{};
      for (final data in dataList) {
        final id = data['id'] as int? ?? _nextIdForTable(table);
        final row = Map<String, dynamic>.from(data);
        row['id'] = id;
        final word = (row['word'] as String?) ?? '';
        final sliceKey = _shardKeyForWord(word);
        shards.putIfAbsent(sliceKey, () => []).add(row);
        if (id != null) _wordIdIndex[id] = row;
        if (word.isNotEmpty) _wordTextIndex[word.toLowerCase()] = row;
      }
      for (final entry in shards.entries) {
        final shardName = _shardTableName(entry.key);
        _tables.putIfAbsent(shardName, () => []);
        _tables[shardName]!.addAll(entry.value);
        await _saveWordsShard(entry.key);
      }
    } else {
      _tables.putIfAbsent(table, () => []);
      final rows = _tables[table]!;
      for (final data in dataList) {
        final id = data['id'] as int? ?? _nextIdForTable(table);
        final row = Map<String, dynamic>.from(data);
        row['id'] = id;
        rows.add(row);
      }
      await _saveTable(table);
    }
  }

  // ========== Update ==========

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (!_initialized) await init();

    int count = 0;
    if (_shardableTables.contains(table)) {
      _ensureWordsLoaded();
      final modifiedShards = <String>{};
      for (final sliceKey in _allWordShardKeys()) {
        final shardName = _shardTableName(sliceKey);
        final rows = _tables[shardName] ?? [];
        for (int i = 0; i < rows.length; i++) {
          if (_rowMatches(rows[i], where, whereArgs)) {
            rows[i].addAll(data);
            // 同步更新索引
            final id = rows[i]['id'] as int?;
            final word = (rows[i]['word'] as String?)?.toLowerCase();
            if (id != null) _wordIdIndex[id] = rows[i];
            if (word != null && word.isNotEmpty) _wordTextIndex[word] = rows[i];
            modifiedShards.add(sliceKey);
            count++;
          }
        }
      }
      for (final sk in modifiedShards) {
        await _saveWordsShard(sk);
      }
    } else {
      final rows = _tables[table] ?? [];
      for (int i = 0; i < rows.length; i++) {
        if (_rowMatches(rows[i], where, whereArgs)) {
          rows[i].addAll(data);
          count++;
        }
      }
      if (count > 0) await _saveTable(table);
    }

    return count;
  }

  // ========== Batch Update Words ==========

  /// 批量更新 words 表（多个字段 × 多个单词）
  /// updates: [{"word": "apple", "fields": {"meaning": "苹果", "type": "n."}}, ...]
  /// 所有更新在内存中完成，每个分片仅保存一次
  Future<int> batchUpdateWords(List<Map<String, dynamic>> updates) async {
    if (!_initialized) await init();
    _ensureWordsLoaded();

    int count = 0;
    final modifiedShards = <String>{};

    for (final update in updates) {
      final targetWord = (update['word'] as String?)?.toLowerCase().trim();
      final fields = update['fields'] as Map<String, dynamic>?;
      if (targetWord == null || targetWord.isEmpty || fields == null || fields.isEmpty) {
        continue;
      }

      // 在所有分片中查找
      for (final sliceKey in _allWordShardKeys()) {
        final shardName = _shardTableName(sliceKey);
        final rows = _tables[shardName] ?? [];
        bool found = false;
        for (int i = 0; i < rows.length; i++) {
          if ((rows[i]['word'] as String).toLowerCase().trim() == targetWord) {
            rows[i].addAll(fields);
            final id = rows[i]['id'] as int?;
            final word = (rows[i]['word'] as String?)?.toLowerCase();
            if (id != null) _wordIdIndex[id] = rows[i];
            if (word != null && word.isNotEmpty) _wordTextIndex[word] = rows[i];
            modifiedShards.add(sliceKey);
            count += fields.length;
            found = true;
            break;
          }
        }
        if (found) break;
      }
    }

    // 每个分片仅保存一次
    for (final sk in modifiedShards) {
      await _saveWordsShard(sk);
    }

    return count;
  }

  // ========== Delete ==========

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (!_initialized) await init();

    int count = 0;
    if (_shardableTables.contains(table)) {
      _ensureWordsLoaded();
      final modifiedShards = <String>{};
      for (final sliceKey in _allWordShardKeys()) {
        final shardName = _shardTableName(sliceKey);
        final rows = _tables[shardName] ?? [];
        final toRemove = <int>[];
        for (int i = 0; i < rows.length; i++) {
          if (_rowMatches(rows[i], where, whereArgs)) {
            final id = rows[i]['id'] as int?;
            final word = (rows[i]['word'] as String?)?.toLowerCase();
            if (id != null) _wordIdIndex.remove(id);
            if (word != null) _wordTextIndex.remove(word);
            toRemove.add(i);
            count++;
          }
        }
        for (final i in toRemove.reversed) {
          rows.removeAt(i);
        }
        if (toRemove.isNotEmpty) modifiedShards.add(sliceKey);
      }
      for (final sk in modifiedShards) {
        await _saveWordsShard(sk);
      }
    } else {
      final rows = _tables[table] ?? [];
      final toRemove = <int>[];
      for (int i = 0; i < rows.length; i++) {
        if (_rowMatches(rows[i], where, whereArgs)) {
          toRemove.add(i);
          count++;
        }
      }
      for (final i in toRemove.reversed) {
        rows.removeAt(i);
      }
      if (toRemove.isNotEmpty) await _saveTable(table);
    }

    return count;
  }

  bool _rowMatches(Map<String, dynamic> row, String? where, List<dynamic>? whereArgs) {
    if (where == null || whereArgs == null || whereArgs.isEmpty) return true;
    final parts = where.split(' AND ');
    int argIndex = 0;
    for (final part in parts) {
      final match = RegExp(r"(\w+)\s*=\s*\?").firstMatch(part.trim());
      if (match != null) {
        final colName = match.group(1)!;
        if (argIndex >= whereArgs.length) return false;
        if (row[colName] != whereArgs[argIndex++]) return false;
      }
    }
    return true;
  }

  // ========== Raw Query ==========

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    if (!_initialized) await init();

    final upperSql = sql.toUpperCase().trim();

    if (upperSql.startsWith('SELECT')) {
      final fromMatch = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(sql);
      if (fromMatch == null) return [];

      final table = fromMatch.group(1)!;
      final isSharded = _shardableTables.contains(table);
      var rows = isSharded
          ? List<Map<String, dynamic>>.from(_allWordRows())
          : List<Map<String, dynamic>>.from(_tables[table] ?? []);

      // JOIN
      if (upperSql.contains('JOIN')) {
        final isLeftJoin = upperSql.contains('LEFT JOIN');
        final joinMatch = RegExp(
          r'(?:LEFT\s+|INNER\s+)?JOIN\s+(\w+)\s+(\w+)\s+ON\s+\w+\.(\w+)\s*=\s*\w+\.(\w+)',
          caseSensitive: false,
        ).firstMatch(sql);
        if (joinMatch != null) {
          final joinTable = joinMatch.group(1)!;
          if (_shardableTables.contains(joinTable)) {
            _ensureWordsLoaded();
          }
          final leftCol = joinMatch.group(3)!;
          final rightCol = joinMatch.group(4)!;
          final joinRows = _shardableTables.contains(joinTable)
              ? _allWordRows()
              : _tables[joinTable] ?? [];

          final result = <Map<String, dynamic>>[];
          for (final row in rows) {
            bool matched = false;
            for (final joinRow in joinRows) {
              if (row[leftCol] == joinRow[rightCol]) {
                final merged = Map<String, dynamic>.from(row);
                merged.addAll(joinRow);
                result.add(merged);
                matched = true;
              }
            }
            if (!matched && isLeftJoin) {
              result.add(Map<String, dynamic>.from(row));
            }
          }
          rows = result;
        }
      }

      // WHERE
      if (arguments != null && arguments.isNotEmpty) {
        rows = rows.where((row) {
          int argIndex = 0;
          final whereMatch = RegExp(
            r'WHERE\s+(.+?)(?:\s+ORDER\s+BY|\s+LIMIT|\s+OFFSET|\s*$)',
            caseSensitive: false,
          ).firstMatch(sql);
          if (whereMatch != null) {
            final whereClause = whereMatch.group(1)!;
            final conditions = whereClause.split(' AND ');
            for (final cond in conditions) {
              final trimmed = cond.trim();
              if (trimmed.contains('?')) {
                final colMatch = RegExp(r'(\w+)\s*(<=?|>=?|!=|=)\s*\?').firstMatch(trimmed);
                if (colMatch != null) {
                  final col = colMatch.group(1)!;
                  final op = colMatch.group(2)!;
                  final val = arguments[argIndex++];
                  final rowVal = row[col];
                  if (rowVal == null) return false;
                  switch (op) {
                    case '=': if (rowVal.toString() != val.toString()) return false;
                    case '<=': if ((rowVal as Comparable).compareTo(val) > 0) return false;
                    case '>=': if ((rowVal as Comparable).compareTo(val) < 0) return false;
                    case '<': if ((rowVal as Comparable).compareTo(val) >= 0) return false;
                    case '>': if ((rowVal as Comparable).compareTo(val) <= 0) return false;
                  }
                }
              }
            }
          }
          return true;
        }).toList();
      }

      // ORDER BY — handle RANDOM() and multiple columns
      final orderMatches = RegExp(
        r'ORDER\s+BY\s+(.+?)(?:\s+LIMIT|\s+OFFSET|\s*$)',
        caseSensitive: false,
      ).firstMatch(sql);
      if (orderMatches != null) {
        final orderPart = orderMatches.group(1)!;
        final orderSegments = orderPart.split(',').map((s) => s.trim()).toList();
        rows.sort((a, b) {
          for (final segment in orderSegments) {
            final upperSeg = segment.toUpperCase();
            if (upperSeg == 'RANDOM()') {
              // random already handled outside; here just treat as equal
              continue;
            }
            final isDesc = upperSeg.endsWith(' DESC');
            final colName = segment.split(' ')[0].trim();
            final aVal = a[colName];
            final bVal = b[colName];
            int cmp = 0;
            if (aVal is Comparable && bVal is Comparable) {
              cmp = aVal.compareTo(bVal);
            }
            if (cmp != 0) {
              return isDesc ? -cmp : cmp;
            }
          }
          return 0;
        });
        if (orderPart.toUpperCase().contains('RANDOM()')) {
          rows.shuffle();
        }
      }

      // OFFSET
      final offsetMatch = RegExp(r'OFFSET\s+(\d+)', caseSensitive: false).firstMatch(sql);
      if (offsetMatch != null) {
        final offset = int.parse(offsetMatch.group(1)!);
        rows = rows.skip(offset).toList();
      }

      // LIMIT
      final limitMatch = RegExp(r'LIMIT\s+(\d+)', caseSensitive: false).firstMatch(sql);
      if (limitMatch != null) {
        final limit = int.parse(limitMatch.group(1)!);
        rows = rows.take(limit).toList();
      }

      return rows;
    }

    return [];
  }

  // ========== Utilities ==========

  int _nextIdForTable(String table) {
    if (_shardableTables.contains(table)) {
      _ensureWordsLoaded();
      int maxId = 0;
      for (final sliceKey in _allWordShardKeys()) {
        final rows = _tables[_shardTableName(sliceKey)] ?? [];
        for (final row in rows) {
          final id = row['id'] as int?;
          if (id != null && id > maxId) maxId = id;
        }
      }
      return maxId > 0 ? maxId + 1 : _nextId++;
    }
    final rows = _tables[table] ?? [];
    if (rows.isEmpty) return _nextId++;
    int maxId = 0;
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id != null && id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    if (!_initialized) await init();

    // 清除小表
    for (final table in _tables.keys.where((k) => !k.startsWith('words_')).toList()) {
      _tables[table] = [];
      await _prefs?.remove('mem_$table');
      // 清除分片
      int idx = 0;
      while (_prefs?.containsKey('mem_${table}_chunk_$idx') ?? false) {
        await _prefs?.remove('mem_${table}_chunk_$idx');
        idx++;
      }
    }

    // 清除 words 分片
    for (final sliceKey in _allWordShardKeys()) {
      final shardName = _shardTableName(sliceKey);
      _tables[shardName] = [];
      await _prefs?.remove('mem_$shardName');
      int idx = 0;
      while (_prefs?.containsKey('mem_${shardName}_chunk_$idx') ?? false) {
        await _prefs?.remove('mem_${shardName}_chunk_$idx');
        idx++;
      }
    }

    // 清除旧格式的 words key（迁移兼容）
    await _prefs?.remove('mem_words');

    _wordIdIndex.clear();
    _wordTextIndex.clear();
    _wordsLoaded = false;
  }

  /// 获取内部状态（仅测试用）
  Map<String, int> getShardStats() {
    final stats = <String, int>{};
    for (final sliceKey in _allWordShardKeys()) {
      final name = _shardTableName(sliceKey);
      stats[sliceKey] = (_tables[name]?.length ?? 0);
    }
    return stats;
  }
}
