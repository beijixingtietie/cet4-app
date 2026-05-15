import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class UserProvider with ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();

  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 1.0;
  int _dailyWordGoal = 10;
  bool _soundEnabled = true;
  String? _apiKey;
  String _baseUrl = 'https://api.openai.com/v1';
  String _modelName = 'gpt-4o-mini';
  int _apiTimeout = 60;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  int get dailyWordGoal => _dailyWordGoal;
  bool get soundEnabled => _soundEnabled;
  String? get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  String get modelName => _modelName;
  int get apiTimeout => _apiTimeout;
  bool get isApiConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  // 初始化用户设置
  Future<void> initUserSettings() async {
    // 从数据库加载设置
    final settings = await _dbHelper.query('user_settings', where: 'user_id = ?', whereArgs: [1]);

    if (settings.isEmpty) {
      // 创建默认设置
      final now = DateTime.now().toIso8601String();
      await _dbHelper.insert('user_settings', {
        'user_id': 1,
        'base_url': 'https://api.openai.com/v1',
        'daily_word_count': 10,
        'theme_mode': 'system',
        'font_size': 1.0,
        'sound_enabled': 1,
        'checkin_days': 0,
        'total_study_days': 0,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      // 加载现有设置
      final setting = settings.first;
      _fontSize = (setting['font_size'] as num?)?.toDouble() ?? 1.0;
      _dailyWordGoal = (setting['daily_word_count'] as int?) ?? 10;
      _soundEnabled = (setting['sound_enabled'] as int?) == 1;
      _apiKey = setting['api_key'] as String?;
      _baseUrl = setting['base_url'] as String? ?? 'https://api.openai.com/v1';
      _modelName = setting['model_name'] as String? ?? 'gpt-4o-mini';
      _apiTimeout = setting['api_timeout'] as int? ?? 60;

      // 设置主题模式
      final themeModeStr = setting['theme_mode'] as String? ?? 'system';
      switch (themeModeStr) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    }

    notifyListeners();
  }

  // 更新主题模式
  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      default:
        modeStr = 'system';
    }

    await _dbHelper.update(
      'user_settings',
      {'theme_mode': modeStr, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新字体大小
  Future<void> updateFontSize(double size) async {
    _fontSize = size;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'font_size': size, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新每日单词目标
  Future<void> updateDailyWordGoal(int goal) async {
    _dailyWordGoal = goal;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'daily_word_count': goal, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新音效设置
  Future<void> updateSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'sound_enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新 API 密钥
  Future<void> updateApiKey(String? key) async {
    _apiKey = key;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'api_key': key, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新模型名称
  Future<void> updateModelName(String name) async {
    _modelName = name;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'model_name': name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新 Base URL
  Future<void> updateBaseUrl(String url) async {
    _baseUrl = url;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'base_url': url, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  // 更新 API 超时时间
  Future<void> updateApiTimeout(int timeout) async {
    _apiTimeout = timeout;
    notifyListeners();

    await _dbHelper.update(
      'user_settings',
      {'api_timeout': timeout, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [1],
    );
  }

  /// 清除所有学习数据（保留基础设置：字体/主题/API配置）
  Future<void> clearAllData() async {
    // 清空所有学习相关表
    await _dbHelper.delete('words');
    await _dbHelper.delete('questions');
    await _dbHelper.delete('study_records');
    await _dbHelper.delete('exam_records');
    await _dbHelper.delete('wrong_questions');
    await _dbHelper.delete('ai_conversations');
    await _dbHelper.delete('ai_corrections');
    await _dbHelper.delete('word_bookmarks');

    // 重置统计数据，但保留 API 配置、字体、主题、音效
    await _dbHelper.update(
      'user_settings',
      {
        'checkin_days': 0,
        'total_study_days': 0,
        'daily_word_count': 10,
        'last_checkin_date': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [1],
    );

    // 重置 UserProvider 内存状态（保留字体/主题/API）
    _dailyWordGoal = 10;
    notifyListeners();
  }
}
