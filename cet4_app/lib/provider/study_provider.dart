import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../utils/ebbinghaus_algorithm.dart';

class StudyProvider with ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();

  List<Map<String, dynamic>> _todayWords = [];
  List<Map<String, dynamic>> _reviewWords = [];
  Map<String, int> _studyProgress = {};
  int _todayStudyCount = 0;
  int _todayReviewCount = 0;
  int _checkinDays = 0;
  bool _isLoading = false;
  bool _dailyGoalReached = false;
  bool _goalNotified = false;
  List<int> _reviewForecast = List.filled(7, 0);

  List<Map<String, dynamic>> get todayWords => _todayWords;
  List<Map<String, dynamic>> get reviewWords => _reviewWords;
  Map<String, int> get studyProgress => _studyProgress;
  int get todayStudyCount => _todayStudyCount;
  int get todayReviewCount => _todayReviewCount;
  int get checkinDays => _checkinDays;
  bool get isLoading => _isLoading;
  bool get dailyGoalReached => _dailyGoalReached;
  List<int> get reviewForecast => _reviewForecast;

  int get notLearnedCount => _studyProgress['not_learned'] ?? 0;
  int get learningCount => _studyProgress['learning'] ?? 0;
  int get masteredCount => _studyProgress['mastered'] ?? 0;
  int get forgottenCount => _studyProgress['forgotten'] ?? 0;
  int get totalWordsCount => _studyProgress['total'] ?? 0;

  /// 重置所有内存状态为0
  void resetState() {
    _todayWords = [];
    _reviewWords = [];
    _studyProgress = {
      'total': 0,
      'not_learned': 0,
      'learning': 0,
      'mastered': 0,
      'forgotten': 0,
    };
    _todayStudyCount = 0;
    _todayReviewCount = 0;
    _checkinDays = 0;
    _dailyGoalReached = false;
    _goalNotified = false;
    _reviewForecast = List.filled(7, 0);
    _isLoading = false;
    notifyListeners();
  }

  // 加载今日学习数据
  Future<void> loadTodayData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 获取所有学习记录
      final allRecords = await _dbHelper.query('study_records');

      // 计算学习进度
      _studyProgress = EbbinghausAlgorithm.getStudyProgress(allRecords);

      // 获取今日需要复习的单词
      _todayReviewCount = EbbinghausAlgorithm.getTodayReviewCount(allRecords);

      // 获取今日已学习的单词数量
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      _todayStudyCount = allRecords.where((record) {
        if (record['last_study_time'] != null) {
          final lastStudyTime = DateTime.parse(record['last_study_time'] as String);
          return lastStudyTime.isAfter(todayStart) && lastStudyTime.isBefore(todayEnd);
        }
        return false;
      }).length;

      // 未来7天复习预测
      final now = DateTime.now();
      final todayBase = DateTime(now.year, now.month, now.day);
      _reviewForecast = List.filled(7, 0);
      for (final record in allRecords) {
        if (record['next_review_time'] != null) {
          final nextReview = DateTime.parse(record['next_review_time'] as String);
          final diff = nextReview.difference(todayBase).inDays;
          if (diff >= 0 && diff < 7) {
            _reviewForecast[diff]++;
          }
        }
      }

      // 获取打卡天数及每日目标
      final settings = await _dbHelper.query('user_settings', where: 'user_id = ?', whereArgs: [1]);
      if (settings.isNotEmpty) {
        _checkinDays = settings.first['checkin_days'] as int? ?? 0;
        final dailyGoal = settings.first['daily_word_count'] as int? ?? 10;
        final wasReached = _dailyGoalReached;
        _dailyGoalReached = dailyGoal > 0 && _todayStudyCount >= dailyGoal;
        if (!_dailyGoalReached) {
          _goalNotified = false;
        }
        // 目标刚达成时自动打卡
        if (_dailyGoalReached && !wasReached) {
          await _autoCheckin(settings.first);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('加载学习数据失败: $e');
    }
  }

  // 获取今日需要学习的新单词
  Future<void> loadTodayWords(int count) async {
    try {
      // 获取未学习的单词
      final notLearnedWords = await _dbHelper.rawQuery('''
        SELECT w.* FROM words w
        LEFT JOIN study_records sr ON w.id = sr.word_id AND sr.user_id = 1
        WHERE sr.id IS NULL OR sr.status = '未学'
        ORDER BY RANDOM()
        LIMIT ?
      ''', [count]);

      _todayWords = notLearnedWords;
      notifyListeners();
    } catch (e) {
      print('加载今日单词失败: $e');
    }
  }

  // 获取需要复习的单词
  Future<void> loadReviewWords() async {
    try {
      final now = DateTime.now();
      _reviewWords = await _dbHelper.rawQuery('''
        SELECT w.*, sr.* FROM words w
        INNER JOIN study_records sr ON w.id = sr.word_id
        WHERE sr.user_id = 1 AND sr.next_review_time <= ?
        ORDER BY sr.next_review_time ASC
      ''', [now.toIso8601String()]);

      notifyListeners();
    } catch (e) {
      print('加载复习单词失败: $e');
    }
  }

  /// 弹出目标达成提示（仅触发一次）
  bool consumeGoalReached() {
    if (_dailyGoalReached && !_goalNotified) {
      _goalNotified = true;
      return true;
    }
    return false;
  }

  // 更新单词学习状态
  Future<void> updateWordStudyStatus(int wordId, bool isCorrect) async {
    try {
      // 获取当前学习记录
      final records = await _dbHelper.query(
        'study_records',
        where: 'word_id = ? AND user_id = ?',
        whereArgs: [wordId, 1],
      );

      if (records.isEmpty) {
        // 创建新的学习记录
        final updateData = EbbinghausAlgorithm.updateStudyRecord(
          isCorrect: isCorrect,
          currentCorrectCount: 0,
          currentWrongCount: 0,
          currentStatus: '未学',
        );

        await _dbHelper.insert('study_records', {
          'word_id': wordId,
          'user_id': 1,
          ...updateData,
        });
      } else {
        // 更新现有记录
        final record = records.first;
        final updateData = EbbinghausAlgorithm.updateStudyRecord(
          isCorrect: isCorrect,
          currentCorrectCount: record['correct_count'] as int,
          currentWrongCount: record['wrong_count'] as int,
          currentStatus: record['status'] as String,
        );

        await _dbHelper.update(
          'study_records',
          updateData,
          where: 'word_id = ? AND user_id = ?',
          whereArgs: [wordId, 1],
        );
      }

      // 重新加载数据
      await loadTodayData();
    } catch (e) {
      print('更新学习状态失败: $e');
    }
  }

  /// 目标达成时自动打卡（静默）
  Future<void> _autoCheckin(Map<String, dynamic> setting) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastCheckinDate = setting['last_checkin_date'] as String?;

      if (lastCheckinDate == null || lastCheckinDate != todayStr) {
        final newDays = (setting['checkin_days'] as int? ?? 0) + 1;
        await _dbHelper.update(
          'user_settings',
          {
            'checkin_days': newDays,
            'total_study_days': (setting['total_study_days'] as int? ?? 0) + 1,
            'last_checkin_date': todayStr,
            'updated_at': now.toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [1],
        );
        _checkinDays = newDays;
      }
    } catch (e) {
      print('自动打卡失败: $e');
    }
  }
}
