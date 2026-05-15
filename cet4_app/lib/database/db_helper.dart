import 'memory_storage.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static MemoryStorage? _memoryStorage;

  factory DbHelper() => _instance;

  DbHelper._internal();

  MemoryStorage get _memory => _memoryStorage ??= MemoryStorage();

  Future<void> _initMemoryStorage() async {
    if (_memoryStorage == null) {
      _memoryStorage = MemoryStorage();
      await _memoryStorage!.init();
    }
  }

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
    await _initMemoryStorage();
    return _memory.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    await _initMemoryStorage();
    return _memory.insert(table, data);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    await _initMemoryStorage();
    return _memory.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    await _initMemoryStorage();
    return _memory.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    await _initMemoryStorage();
    return _memory.rawQuery(sql, arguments);
  }

  Future<void> batchInsert(
    String table,
    List<Map<String, dynamic>> dataList,
  ) async {
    await _initMemoryStorage();
    await _memory.batchInsert(table, dataList);
  }

  /// 批量更新 words 表 — 所有更新一次性提交，每个分片只写一次
  Future<int> batchUpdateWords(List<Map<String, dynamic>> updates) async {
    await _initMemoryStorage();
    return _memory.batchUpdateWords(updates);
  }

  Future<void> close() async {
    _memoryStorage = null;
  }
}
