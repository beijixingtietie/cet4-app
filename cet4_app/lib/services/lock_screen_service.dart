import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/word.dart';

class LockScreenService with WidgetsBindingObserver {
  static final LockScreenService _instance = LockScreenService._internal();
  factory LockScreenService() => _instance;
  LockScreenService._internal();

  final DbHelper _dbHelper = DbHelper();
  SharedPreferences? _prefs;
  bool _initialized = false;

  bool _lockScreenEnabled = false;
  int _wordsPerUnlock = 1;
  int _displayDuration = 0;
  int _todayShownCount = 0;
  String? _lastUnlockDate;

  bool get isEnabled => _lockScreenEnabled;
  int get wordsPerUnlock => _wordsPerUnlock;
  int get displayDuration => _displayDuration;
  int get todayShownCount => _todayShownCount;

  static const String _keyEnabled = 'lock_screen_enabled';
  static const String _keyWordsPerUnlock = 'lock_screen_words_per_unlock';
  static const String _keyDisplayDuration = 'lock_screen_display_duration';
  static const String _keyTodayShownCount = 'lock_screen_today_shown';
  static const String _keyLastUnlockDate = 'lock_screen_last_date';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    _lockScreenEnabled = _prefs?.getBool(_keyEnabled) ?? false;
    _wordsPerUnlock = _prefs?.getInt(_keyWordsPerUnlock) ?? 1;
    _displayDuration = _prefs?.getInt(_keyDisplayDuration) ?? 0;
    _todayShownCount = _prefs?.getInt(_keyTodayShownCount) ?? 0;
    _lastUnlockDate = _prefs?.getString(_keyLastUnlockDate);

    _checkNewDay();
    _initialized = true;
  }

  void _checkNewDay() {
    final today = _formatDate(DateTime.now());
    if (_lastUnlockDate != today) {
      _todayShownCount = 0;
      _lastUnlockDate = today;
      _prefs?.setInt(_keyTodayShownCount, 0);
      _prefs?.setString(_keyLastUnlockDate, today);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> setEnabled(bool enabled) async {
    _lockScreenEnabled = enabled;
    await _prefs?.setBool(_keyEnabled, enabled);
  }

  Future<void> setWordsPerUnlock(int count) async {
    _wordsPerUnlock = count.clamp(1, 5);
    await _prefs?.setInt(_keyWordsPerUnlock, _wordsPerUnlock);
  }

  Future<void> setDisplayDuration(int seconds) async {
    _displayDuration = seconds;
    await _prefs?.setInt(_keyDisplayDuration, seconds);
  }

  Future<List<Word>> getWordsForLockScreen() async {
    _checkNewDay();

    try {
      final rawWords = await _dbHelper.rawQuery('''
        SELECT w.* FROM words w
        LEFT JOIN study_records sr ON w.id = sr.word_id AND sr.user_id = 1
        WHERE sr.id IS NULL OR sr.status = '未学' OR sr.status = '学习中'
        ORDER BY RANDOM()
        LIMIT ?
      ''', [_wordsPerUnlock]);

      return rawWords.map((row) => Word.fromDbMap(row)).toList();
    } catch (e) {
      debugPrint('获取锁屏单词失败: $e');
      return [];
    }
  }

  Future<void> recordLockScreenStudy(int wordId, bool isKnown) async {
    try {
      final records = await _dbHelper.query(
        'study_records',
        where: 'word_id = ? AND user_id = ?',
        whereArgs: [wordId, 1],
      );

      final now = DateTime.now();
      final nextReview = now.add(Duration(days: isKnown ? 1 : 0));

      if (records.isEmpty) {
        await _dbHelper.insert('study_records', {
          'word_id': wordId,
          'user_id': 1,
          'status': isKnown ? '学习中' : '未学',
          'correct_count': isKnown ? 1 : 0,
          'wrong_count': isKnown ? 0 : 1,
          'last_study_time': now.toIso8601String(),
          'next_review_time': nextReview.toIso8601String(),
        });
      } else {
        final record = records.first;
        final correctCount = (record['correct_count'] as int? ?? 0) + (isKnown ? 1 : 0);
        final wrongCount = (record['wrong_count'] as int? ?? 0) + (isKnown ? 0 : 1);
        final total = correctCount + wrongCount;
        final accuracy = total > 0 ? correctCount / total : 0.0;

        String status;
        if (accuracy >= 0.8 && total >= 3) {
          status = '已掌握';
        } else if (total >= 1) {
          status = '学习中';
        } else {
          status = '未学';
        }

        await _dbHelper.update(
          'study_records',
          {
            'status': status,
            'correct_count': correctCount,
            'wrong_count': wrongCount,
            'last_study_time': now.toIso8601String(),
            'next_review_time': nextReview.toIso8601String(),
          },
          where: 'word_id = ? AND user_id = ?',
          whereArgs: [wordId, 1],
        );
      }

      _todayShownCount++;
      await _prefs?.setInt(_keyTodayShownCount, _todayShownCount);
    } catch (e) {
      debugPrint('记录锁屏学习数据失败: $e');
    }
  }

  Future<Map<String, dynamic>> getLockScreenStats() async {
    try {
      final today = _formatDate(DateTime.now());
      final todayRecords = await _dbHelper.rawQuery('''
        SELECT * FROM study_records
        WHERE date(last_study_time) = date(?)
      ''', [today]);

      final totalRecords = await _dbHelper.query('study_records');

      return {
        'today_studied': todayRecords.length,
        'total_studied': totalRecords.length,
        'today_shown': _todayShownCount,
        'mastered': totalRecords.where((r) => r['status'] == '已掌握').length,
        'learning': totalRecords.where((r) => r['status'] == '学习中').length,
      };
    } catch (e) {
      debugPrint('获取锁屏统计失败: $e');
      return {
        'today_studied': 0,
        'total_studied': 0,
        'today_shown': _todayShownCount,
        'mastered': 0,
        'learning': 0,
      };
    }
  }

  String getDisplayDurationText() {
    switch (_displayDuration) {
      case 5:
        return '5秒';
      case 10:
        return '10秒';
      case 0:
      default:
        return '一直显示';
    }
  }
}
