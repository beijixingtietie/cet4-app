import 'dart:convert';
import 'dart:math';
import '../database/db_helper.dart';
import '../provider/user_provider.dart';
import 'cet4_offline_wordbank.dart';

class AgentExecutor {
  final DbHelper _dbHelper = DbHelper();

  static const Set<String> _validActions = {
    'update_word', 'add_word', 'delete_word', 'update_question', 'set_daily_goal',
    'batch_update_words', 'list_words', 'start_batch_fill',
    'offline_import_full_wordbank',
  };

  static const Map<String, String> _wordFieldMapping = {
    'meaning': 'meaning', '释义': 'meaning',
    'phonetic': 'phonetic_uk', 'phonetic_uk': 'phonetic_uk', '音标': 'phonetic_uk', '英式音标': 'phonetic_uk',
    'phonetic_us': 'phonetic_us', '美式音标': 'phonetic_us',
    'type': 'type', '词性': 'type',
    'example': 'example', '例句': 'example',
    'example_translation': 'example_translation', '例句翻译': 'example_translation',
    'collocation': 'collocation', '搭配': 'collocation',
    'level': 'level', '级别': 'level',
    'word': 'word', '单词': 'word',
  };

  static const Map<String, String> _questionFieldMapping = {
    'content': 'content', '题干': 'content',
    'options': 'options', '选项': 'options',
    'answer': 'answer', '答案': 'answer',
    'explanation': 'explanation', '解析': 'explanation', 'analysis': 'explanation',
    'type': 'type', '题型': 'type',
    'year': 'year', '年份': 'year',
  };

  static const Set<String> _requiredWordFields = {'word', 'meaning'};
  static const Set<String> _requiredQuestionFields = {'content', 'answer', 'type'};

  // 操作快照（内存缓存，最多50条）
  final Map<String, _SnapshotEntry> _snapshots = {};
  static const int _maxSnapshots = 50;

  /// 尝试从AI回复中提取Agent JSON命令
  static Map<String, dynamic>? tryParseCommand(String text) {
    if (text.isEmpty) return null;

    // 1. 直接解析整个文本
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (_isValidCommand(json)) return json;
    } catch (_) {}

    // 2. 从markdown代码块提取
    final codeMatch = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(text);
    if (codeMatch != null) {
      try {
        final json = jsonDecode(codeMatch.group(1)!) as Map<String, dynamic>;
        if (_isValidCommand(json)) return json;
      } catch (_) {}
    }

    // 3. 在文本中搜索JSON对象
    final jsonMatch = RegExp(r'\{[^{}]*"action"\s*:\s*"[a-z_]+"[^{}]*\}').firstMatch(text);
    if (jsonMatch != null) {
      try {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        if (_isValidCommand(json)) return json;
      } catch (_) {}
    }

    return null;
  }

  static bool _isValidCommand(Map<String, dynamic> json) {
    final action = json['action'] as String?;
    return action != null && _validActions.contains(action) && json['params'] is Map;
  }

  String _generateActionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
  }

  /// 执行Agent命令
  Future<String> execute(Map<String, dynamic> command, {UserProvider? userProvider}) async {
    final action = command['action'] as String;
    final params = (command['params'] as Map).cast<String, dynamic>();
    final actionId = _generateActionId();
    String result;

    try {
      switch (action) {
        case 'update_word':
          result = await _updateWord(params, actionId);
          break;
        case 'add_word':
          result = await _addWord(params, actionId);
          break;
        case 'delete_word':
          result = await _deleteWord(params, actionId);
          break;
        case 'update_question':
          result = await _updateQuestion(params, actionId);
          break;
        case 'set_daily_goal':
          result = await _setDailyGoal(params, userProvider, actionId);
          break;
        case 'batch_update_words':
          result = await _batchUpdateWords(params, actionId);
          break;
        case 'list_words':
          result = await _listWords(params);
          break;
        case 'offline_import_full_wordbank':
          result = await _offlineImportFullWordbank(actionId);
          break;
        default:
          result = '不支持的操作: $action';
      }
    } catch (e) {
      result = '操作执行失败: $e';
    }

    // 审计日志
    await _auditLog(action, params, result, actionId);
    return result;
  }

  /// 回滚指定操作
  Future<String> rollback(String actionId) async {
    final entry = _snapshots[actionId];
    if (entry == null) return '没有找到操作快照: $actionId';

    try {
      switch (entry.action) {
        case 'update_word':
          // 恢复原始数据
          if (entry.snapshot.isNotEmpty) {
            final row = entry.snapshot.first;
            await _dbHelper.update(
              'words',
              row,
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
          break;
        case 'delete_word':
          // 重新插入
          for (final row in entry.snapshot) {
            await _dbHelper.insert('words', row);
          }
          break;
        case 'add_word':
          // 删除新增的单词
          final params = entry.params;
          final word = params['word'] as String? ?? '';
          if (word.isNotEmpty) {
            await _dbHelper.delete('words', where: 'word = ?', whereArgs: [word]);
          }
          break;
        default:
          return '不支持回滚的操作类型: ${entry.action}';
      }

      _snapshots.remove(actionId);
      await _auditLog('rollback_${entry.action}', entry.params, '回滚成功', actionId);
      return '已回滚操作 $actionId';
    } catch (e) {
      return '回滚失败: $e';
    }
  }

  // ========== 快照 ==========

  Future<void> _takeSnapshot(String actionId, String action, Map<String, dynamic> params,
      List<Map<String, dynamic>> data) async {
    if (_snapshots.length >= _maxSnapshots) {
      final oldest = _snapshots.keys.first;
      _snapshots.remove(oldest);
    }
    _snapshots[actionId] = _SnapshotEntry(
      action: action,
      params: params,
      snapshot: data,
      timestamp: DateTime.now(),
    );
  }

  // ========== 校验 ==========

  String? _validateWordFields(Map<String, dynamic> params, {bool forAdd = false}) {
    final word = params['word'] as String?;
    final meaning = params['meaning'] as String?;

    if (forAdd) {
      if (word == null || word.trim().isEmpty) return '单词名称不能为空';
      if (meaning == null || meaning.trim().isEmpty) return '释义不能为空';
    }

    final field = params['field'] as String?;
    if (!forAdd && field != null) {
      final dbField = _wordFieldMapping[field];
      if (dbField == null) {
        return '不支持的字段「$field」，可用字段：${_wordFieldMapping.keys.where((k) => !_wordFieldMapping.containsKey(k) || _wordFieldMapping[k] == k || k.length == 1).join('、')}';
      }
      final newValue = params['newValue'];
      if (_requiredWordFields.contains(dbField) &&
          (newValue == null || newValue.toString().trim().isEmpty)) {
        return '字段「$field」为必填项，不能为空';
      }
    }
    return null;
  }

  // ========== 审计 ==========

  Future<String> _offlineImportFullWordbank(String actionId) async {
    try {
      final words = await Cet4OfflineWordbank.loadFullWordbank();
      if (words.isEmpty) return '❌ 离线词库加载失败，请检查数据文件';

      // 清空现有 words 表
      await _dbHelper.delete('words');
      // 也清空相关学习记录（因为旧单词 ID 可能变化）
      await _dbHelper.delete('study_records');
      await _dbHelper.delete('word_bookmarks');

      // 批量插入
      await _dbHelper.batchInsert('words', words);

      return '✅ 离线词库导入完成！\n'
          '共导入 ${words.length} 个完整 CET4 高频核心词\n'
          '所有字段（词性、释义、音标、例句、例句翻译、搭配）均已填充\n'
          '学习记录和生词本已重置，可立即开始背单词。';
    } catch (e) {
      return '❌ 离线导入失败: $e';
    }
  }

  Future<void> _auditLog(String action, Map<String, dynamic> params, String result, String actionId) async {
    try {
      await _dbHelper.insert('agent_logs', {
        'action': action,
        'params': jsonEncode(params),
        'result': result,
        'action_id': actionId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // 审计失败不影响主流程
    }
  }

  // ========== Word Operations ==========

  Future<String> _updateWord(Map<String, dynamic> params, String actionId) async {
    final target = params['target'] as String?;
    final field = params['field'] as String?;
    final newValue = params['newValue'];

    if (target == null || target.isEmpty) return 'ERROR: 请指定要修改的单词';
    if (field == null) return 'ERROR: 请指定要修改的字段';
    if (newValue == null || newValue.toString().trim().isEmpty) {
      return 'ERROR: 字段值不能为空';
    }

    final validationError = _validateWordFields(params);
    if (validationError != null) return 'ERROR: $validationError';

    final dbField = _wordFieldMapping[field] ?? field;
    final newValueStr = newValue.toString();

    final words = await _dbHelper.query('words');
    final matched = words.where((w) =>
      (w['word'] as String).toLowerCase() == target.toLowerCase()
    ).toList();

    if (matched.isEmpty) return '未找到单词「$target」';

    // 快照
    await _takeSnapshot(actionId, 'update_word', params,
        matched.map((m) => Map<String, dynamic>.from(m)).toList());

    await _dbHelper.update(
      'words',
      {dbField: newValueStr},
      where: 'word = ?',
      whereArgs: [matched.first['word']],
    );

    final fieldLabel = _wordFieldMapping.entries
        .firstWhere((e) => e.value == dbField, orElse: () => MapEntry(field, field)).key;
    return '已成功将单词「${matched.first['word']}」的$fieldLabel修改为：$newValueStr';
  }

  Future<String> _batchUpdateWords(Map<String, dynamic> params, String actionId) async {
    final wordsList = params['words'] as List<dynamic>?;
    if (wordsList == null || wordsList.isEmpty) {
      return 'ERROR: 缺少 words 数组或数组为空';
    }

    int success = 0;
    final skipped = <String>[];
    final notFound = <String>[];

    // 加载全部单词，建立精确索引
    final allWords = await _dbHelper.query('words');
    if (allWords.isEmpty) {
      return '❌ 词库为空，请先导入单词数据';
    }

    final wordIndex = <String, Map<String, dynamic>>{};
    for (final w in allWords) {
      final text = (w['word'] as String).toLowerCase().trim();
      wordIndex[text] = w;
    }

    // 预校验
    for (final item in wordsList) {
      if (item is! Map) continue;
      final target = ((item['target'] as String?) ?? '').toLowerCase().trim();
      if (target.isNotEmpty && !wordIndex.containsKey(target)) {
        notFound.add(item['target'] as String);
      }
    }
    if (notFound.isNotEmpty && notFound.length == wordsList.length) {
      return '❌ 所有单词均未在词库中找到：${notFound.take(10).join('、')}'
          '${notFound.length > 10 ? '等${notFound.length}个' : ''}。词库现有 ${allWords.length} 个单词，请确认单词名拼写正确。';
    }

    // 按单词分组，将多个字段合并为一次批量更新
    final wordGroups = <String, Map<String, String>>{};
    for (final item in wordsList) {
      if (item is! Map) {
        skipped.add('格式错误');
        continue;
      }

      final targetRaw = item['target'] as String?;
      final field = item['field'] as String?;
      final newValue = item['newValue'];

      if (targetRaw == null || targetRaw.trim().isEmpty) {
        skipped.add('缺少target');
        continue;
      }
      if (field == null) {
        skipped.add('$targetRaw: 缺少field');
        continue;
      }
      if (newValue == null || newValue.toString().trim().isEmpty) {
        skipped.add('$targetRaw: 新值不能为空');
        continue;
      }

      final dbField = _wordFieldMapping[field] ?? field;
      final key = targetRaw.toLowerCase().trim();

      if (!wordIndex.containsKey(key)) {
        skipped.add('❌ $targetRaw: 未在词库中找到');
        continue;
      }

      wordGroups.putIfAbsent(key, () => {});
      wordGroups[key]![dbField] = newValue.toString();
    }

    // 构建批量更新列表
    final updates = <Map<String, dynamic>>[];
    for (final entry in wordGroups.entries) {
      updates.add({
        'word': entry.key,
        'fields': entry.value,
      });
      success += entry.value.length;
    }

    if (updates.isEmpty) {
      final parts = <String>['没有执行任何更新'];
      if (skipped.isNotEmpty) {
        parts.add('跳过 ${skipped.length} 个（${skipped.join('；')}）');
      }
      return parts.join('，');
    }

    // 一次批量写入所有 shard
    await _dbHelper.batchUpdateWords(updates);

    // 更新快照
    await _takeSnapshot(actionId, 'batch_update_words', params,
        updates.map((u) => u).toList());

    final parts = <String>['✅ 成功更新 $success 个字段'];
    if (skipped.isNotEmpty) {
      parts.add('跳过 ${skipped.length} 个（${skipped.join('；')}）');
    }
    return parts.join('，');
  }

  Future<String> _listWords(Map<String, dynamic> params) async {
    final filter = params['filter'] as String?;    // 'all' | 'empty_fields' | 'missing_meaning' 等
    final limit = (params['limit'] as int?) ?? 50;
    final offset = (params['offset'] as int?) ?? 0;

    final allWords = await _dbHelper.query('words');
    if (allWords.isEmpty) {
      return '词库为空。';
    }

    List<Map<String, dynamic>> result;
    if (filter == 'empty_fields') {
      result = allWords.where((w) {
        return (w['type'] as String?)?.isEmpty == true ||
            (w['meaning'] as String?)?.isEmpty == true ||
            (w['example'] as String?)?.isEmpty == true ||
            (w['example_translation'] as String?)?.isEmpty == true ||
            (w['collocation'] as String?)?.isEmpty == true;
      }).toList();
    } else {
      result = allWords;
    }

    final total = result.length;
    result = result.skip(offset).take(limit).toList();

    final lines = <String>[
      '词库共 ${allWords.length} 个单词',
      if (filter == 'empty_fields') '其中有 $total 个单词的字段不完整',
      '',
      '当前页(${offset + 1}-${offset + result.length}/$total)：',
    ];

    for (final w in result) {
      final fields = <String>[];
      if ((w['type'] as String?)?.isEmpty != false) fields.add('词性空');
      if ((w['meaning'] as String?)?.isEmpty != false) fields.add('释义空');
      if ((w['example'] as String?)?.isEmpty != false) fields.add('例句空');
      if ((w['collocation'] as String?)?.isEmpty != false) fields.add('搭配空');
      final note = fields.isEmpty ? '' : ' [${fields.join(',')}]';
      lines.add('  ${w['word']}$note');
    }

    if (offset + result.length < total) {
      lines.add('');
      lines.add('（还有 ${total - offset - result.length} 个单词，继续查询请增加 offset）');
    }

    return lines.join('\n');
  }

  Future<String> _addWord(Map<String, dynamic> params, String actionId) async {
    final word = params['word'] as String?;
    if (word == null || word.trim().isEmpty) return 'ERROR: 缺少单词名称';
    if (params['meaning'] == null || (params['meaning'] as String).trim().isEmpty) {
      return 'ERROR: 释义不能为空';
    }

    final existing = await _dbHelper.query('words', where: 'word = ?', whereArgs: [word]);
    if (existing.isNotEmpty) return '单词「$word」已存在，请用修改功能更新';

    await _dbHelper.insert('words', {
      'word': word,
      'meaning': params['meaning']?.toString() ?? '',
      'type': params['type']?.toString() ?? '',
      'phonetic_uk': params['phonetic_uk']?.toString() ?? '',
      'phonetic_us': params['phonetic_us']?.toString() ?? '',
      'example': params['example']?.toString() ?? '',
      'example_translation': params['example_translation']?.toString() ?? '',
      'collocation': params['collocation']?.toString() ?? '',
      'level': params['level']?.toString() ?? '高频核心词',
      'audio_uk': '',
      'audio_us': '',
    });

    return '已成功添加单词「$word」';
  }

  Future<String> _deleteWord(Map<String, dynamic> params, String actionId) async {
    final target = params['target'] as String?;
    if (target == null || target.isEmpty) return 'ERROR: 请指定要删除的单词';

    final words = await _dbHelper.query('words');
    final matched = words.where((w) =>
      (w['word'] as String).toLowerCase() == target.toLowerCase()
    ).toList();

    if (matched.isEmpty) return '未找到单词「$target」';

    final wordId = matched.first['id'] as int;
    final wordText = matched.first['word'] as String;

    // 快照：保存单词 + 关联数据
    final snapshot = matched.map((m) => Map<String, dynamic>.from(m)).toList();
    await _takeSnapshot(actionId, 'delete_word', params, snapshot);

    await _dbHelper.delete('words', where: 'word = ?', whereArgs: [wordText]);
    await _dbHelper.delete('study_records', where: 'word_id = ?', whereArgs: [wordId]);
    await _dbHelper.delete('word_bookmarks', where: 'word_id = ?', whereArgs: [wordId]);

    return '已成功删除单词「$wordText」及其学习记录和生词本数据';
  }

  // ========== Question Operations ==========

  Future<String> _updateQuestion(Map<String, dynamic> params, String actionId) async {
    final target = params['target'] as String?;
    final field = params['field'] as String?;
    final newValue = params['newValue'];

    if (target == null || target.isEmpty) return 'ERROR: 请提供题目关键词';
    if (field == null) return 'ERROR: 请指定要修改的字段';
    if (newValue == null || newValue.toString().trim().isEmpty) return 'ERROR: 字段值不能为空';

    final dbField = _questionFieldMapping[field];
    if (dbField == null) return 'ERROR: 不支持的字段「$field」';
    final newValueStr = newValue.toString();

    final questions = await _dbHelper.query('questions');
    final matched = questions.where((q) {
      final content = (q['content'] as String?) ?? '';
      return content.contains(target);
    }).toList();

    if (matched.isEmpty) return '未找到包含「$target」的题目';
    if (matched.length > 1) {
      return '找到${matched.length}道匹配题目，请提供更精确的关键词';
    }

    await _takeSnapshot(actionId, 'update_question', params,
        matched.map((m) => Map<String, dynamic>.from(m)).toList());

    final q = matched.first;
    await _dbHelper.update(
      'questions',
      {dbField: newValueStr},
      where: 'id = ?',
      whereArgs: [q['id']],
    );

    final fieldLabel = _questionFieldMapping.entries
        .firstWhere((e) => e.value == dbField, orElse: () => MapEntry(field, field)).key;
    return '已成功修改题目(ID:${q['id']})的$fieldLabel';
  }

  // ========== Goal Operation ==========

  Future<String> _setDailyGoal(Map<String, dynamic> params, UserProvider? userProvider, String actionId) async {
    final newValue = params['newValue'];
    if (newValue == null) return 'ERROR: 缺少目标数值';

    final goal = newValue is int ? newValue : int.tryParse(newValue.toString());
    if (goal == null || goal < 10 || goal > 200) {
      return '每日目标需在10~200之间，输入值：$newValue';
    }

    if (userProvider != null) {
      await userProvider.updateDailyWordGoal(goal);
    } else {
      await _dbHelper.update(
        'user_settings',
        {'daily_word_count': goal, 'updated_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [1],
      );
    }

    return '已成功将每日背词目标设置为 $goal 个';
  }
}

class _SnapshotEntry {
  final String action;
  final Map<String, dynamic> params;
  final List<Map<String, dynamic>> snapshot;
  final DateTime timestamp;

  _SnapshotEntry({
    required this.action,
    required this.params,
    required this.snapshot,
    required this.timestamp,
  });
}
