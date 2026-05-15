import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

/// 批量词库填充引擎 — 分批次循环处理，持久化进度，支持中断恢复
class BatchWordFiller {
  final DbHelper _dbHelper = DbHelper();

  List<String> _allWords = [];
  int _currentBatch = 0;
  int _batchSize = 50;
  int _totalSuccess = 0;
  int _totalFailed = 0;
  final List<String> _failedWords = [];
  bool _isRunning = false;

  static const _progressKey = 'batch_fill_progress';

  bool get isRunning => _isRunning;
  int get totalWords => _allWords.length;
  int get totalBatches => (_allWords.length / _batchSize).ceil();
  int get currentBatch => _currentBatch;
  int get batchSize => _batchSize;
  List<String> get failedWords => List.unmodifiable(_failedWords);

  /// 初始化：加载全部单词 + 恢复进度
  Future<String> init() async {
    _isRunning = true;
    _currentBatch = 0;
    _totalSuccess = 0;
    _totalFailed = 0;
    _failedWords.clear();

    // 加载词库全部单词
    final allWords = await _dbHelper.query('words');
    if (allWords.isEmpty) {
      _isRunning = false;
      return '词库为空，没有单词需要填充。';
    }

    _allWords = allWords
        .map((w) => (w['word'] as String?) ?? '')
        .where((w) => w.isNotEmpty)
        .toList();

    // 恢复进度
    await _loadProgress();

    return '词库共 ${_allWords.length} 个单词，'
        '分 ${totalBatches} 批处理（每批 $_batchSize 个），'
        '从第 ${_currentBatch + 1} 批开始。';
  }

  /// 获取下一批单词（20个），返回 null 表示全部完成
  List<String>? nextBatch() {
    if (!_isRunning) return null;
    final start = _currentBatch * _batchSize;
    if (start >= _allWords.length) {
      _isRunning = false;
      return null;
    }
    final end = (start + _batchSize).clamp(0, _allWords.length);
    return _allWords.sublist(start, end);
  }

  /// 构建发给 AI 的批次提示词（50词/批）
  String buildBatchPrompt(List<String> words) {
    final wordList = words.join(', ');
    return '''为以下 ${words.length} 个四级单词一次性生成完整内容：$wordList
对每个单词返回 5 条 batch_update_words（type/meaning/example/example_translation/collocation）。
只返回纯JSON（不含```json```标记）：
{"action":"batch_update_words","params":{"words":[
  {"target":"单词","field":"type","newValue":"n."},
  {"target":"单词","field":"meaning","newValue":"释义"},
  {"target":"单词","field":"example","newValue":"例句"},
  {"target":"单词","field":"example_translation","newValue":"例句翻译"},
  {"target":"单词","field":"collocation","newValue":"搭配"}
]},"confirmMessage":"第X批更新${words.length}词"}''';
  }

  /// 记录批次结果
  void recordBatchResult(int success, int failed, List<String> batchFailedWords) {
    _totalSuccess += success;
    _totalFailed += failed;
    _failedWords.addAll(batchFailedWords);
    _currentBatch++;
    _saveProgress();
  }

  /// 进度信息
  String get progressMessage {
    final processed = (_currentBatch * _batchSize).clamp(0, _allWords.length);
    final remaining = (_allWords.length - processed).clamp(0, _allWords.length);
    final nextBatch = (_currentBatch + 1).clamp(1, totalBatches);
    return '📊 进度：已处理 $processed/${_allWords.length} 个单词 '
        '（✅ $_totalSuccess 个字段成功 | ❌ $_totalFailed 个字段失败），'
        '还剩 $remaining 个单词，'
        '即将处理第 $nextBatch/$totalBatches 批';
  }

  /// 完成信息
  String get completionMessage {
    if (_allWords.isEmpty) return '没有单词需要处理。';
    final pct = _allWords.isNotEmpty
        ? (_totalSuccess / (_allWords.length * 5) * 100).toStringAsFixed(1)
        : '0';
    final parts = <String>[
      '✅ 所有批次处理完成！',
      '共处理 ${_allWords.length} 个单词（${totalBatches} 批）',
      '成功填充 $_totalSuccess 个字段（约 $pct%）',
    ];
    if (_totalFailed > 0) {
      parts.add('失败 $_totalFailed 个字段');
    }
    if (_failedWords.isNotEmpty) {
      parts.add('失败单词：${_failedWords.take(20).join('、')}'
          '${_failedWords.length > 20 ? '等${_failedWords.length}个' : ''}');
      parts.add('可发送「重试上次失败的单词」重新处理。');
    }
    return parts.join('\n');
  }

  /// 重置进度
  Future<void> reset() async {
    _currentBatch = 0;
    _totalSuccess = 0;
    _totalFailed = 0;
    _failedWords.clear();
    _isRunning = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  /// 标记停止
  void stop() {
    _isRunning = false;
  }

  // --- 内部 ---

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_progressKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _currentBatch = (data['current_batch'] as int?) ?? 0;
        _totalSuccess = (data['total_success'] as int?) ?? 0;
        _totalFailed = (data['total_failed'] as int?) ?? 0;
        _failedWords.clear();
        if (data['failed_words'] != null) {
          _failedWords.addAll(List<String>.from(data['failed_words'] as List));
        }
        _isRunning = _currentBatch * _batchSize < _allWords.length;
      }
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressKey, jsonEncode({
        'current_batch': _currentBatch,
        'total_success': _totalSuccess,
        'total_failed': _totalFailed,
        'failed_words': _failedWords,
      }));
    } catch (_) {}
  }
}
