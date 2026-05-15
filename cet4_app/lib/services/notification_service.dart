import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

/// 通知类型枚举
enum NotificationType {
  dailyStudy,
  reviewReminder,
  checkinReminder,
  testNotification,
}

/// 通知导航目标
enum NotificationTarget {
  home,
  vocabulary,
  wordStudy,
  review,
}

/// 通知设置数据模型
class NotificationSettings {
  bool enabled;
  bool dailyStudyEnabled;
  TimeOfDay dailyStudyTime;
  bool reviewReminderEnabled;
  bool checkinReminderEnabled;

  NotificationSettings({
    this.enabled = true,
    this.dailyStudyEnabled = true,
    this.dailyStudyTime = const TimeOfDay(hour: 20, minute: 0),
    this.reviewReminderEnabled = true,
    this.checkinReminderEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'dailyStudyEnabled': dailyStudyEnabled,
        'dailyStudyHour': dailyStudyTime.hour,
        'dailyStudyMinute': dailyStudyTime.minute,
        'reviewReminderEnabled': reviewReminderEnabled,
        'checkinReminderEnabled': checkinReminderEnabled,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      dailyStudyEnabled: json['dailyStudyEnabled'] ?? true,
      dailyStudyTime: TimeOfDay(
        hour: json['dailyStudyHour'] ?? 20,
        minute: json['dailyStudyMinute'] ?? 0,
      ),
      reviewReminderEnabled: json['reviewReminderEnabled'] ?? true,
      checkinReminderEnabled: json['checkinReminderEnabled'] ?? true,
    );
  }
}

/// CET4 本地通知服务
///
/// 功能：
/// - 每日学习提醒（定时推送）
/// - 复习提醒（检测有单词需要复习时推送）
/// - 打卡提醒（当天未完成学习目标时推送）
/// - 点击通知跳转对应页面
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// 通知渠道 ID（Android）
  static const String _channelId = 'cet4_notification_channel';
  static const String _channelName = 'CET4 学习提醒';
  static const String _channelDescription = '英语四级备考学习提醒通知';

  /// 通知 ID 定义
  static const int _dailyStudyNotificationId = 1001;
  static const int _reviewNotificationId = 1002;
  static const int _checkinNotificationId = 1003;
  static const int _testNotificationId = 9999;

  /// SharedPreferences key
  static const String _settingsKey = 'notification_settings';

  /// 当前设置
  NotificationSettings _settings = NotificationSettings();
  NotificationSettings get settings => _settings;

  /// 通知点击回调
  Function(NotificationTarget target)? onNotificationTap;

  /// 是否已初始化
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 初始化通知服务
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时区数据
    tz_data.initializeTimeZones();

    // 加载设置
    await _loadSettings();

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化设置
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'cet4_category',
          actions: [
            DarwinNotificationAction.plain(
              'open_app',
              '打开应用',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    // 全局初始化设置
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // 执行初始化
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationHandler,
    );

    // 创建 Android 通知渠道
    await _createNotificationChannel();

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Android 13+ 需要请求通知权限
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? true;
    }

    return true;
  }

  /// 检查通知权限状态
  Future<bool> checkPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final enabled = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications();
      return enabled != null;
    }

    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidPlugin?.areNotificationsEnabled();
      return enabled ?? false;
    }

    return true;
  }

  /// 创建 Android 通知渠道
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 通知响应处理
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final target = _parseTarget(payload);
    onNotificationTap?.call(target);
  }

  /// 后台通知处理（必须是顶层函数）
  @pragma('vm:entry-point')
  static void _backgroundNotificationHandler(NotificationResponse response) {
    debugPrint('Background notification received: ${response.payload}');
  }

  /// 解析通知 payload 为目标页面
  NotificationTarget _parseTarget(String payload) {
    switch (payload) {
      case 'vocabulary':
        return NotificationTarget.vocabulary;
      case 'wordStudy':
        return NotificationTarget.wordStudy;
      case 'review':
        return NotificationTarget.review;
      case 'home':
      default:
        return NotificationTarget.home;
    }
  }

  // ==================== 设置管理 ====================

  /// 加载通知设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_settingsKey);
      if (json != null) {
        _settings = NotificationSettings.fromJson(
          Map<String, dynamic>.from(
            // 简单解析，实际可以用 jsonDecode
            _parseSimpleJson(json),
          ),
        );
      }
    } catch (e) {
      debugPrint('加载通知设置失败: $e');
      _settings = NotificationSettings();
    }
  }

  /// 保存通知设置
  Future<void> saveSettings(NotificationSettings settings) async {
    _settings = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, _simpleJsonEncode(settings.toJson()));

      // 重新调度通知
      await rescheduleAllNotifications();
    } catch (e) {
      debugPrint('保存通知设置失败: $e');
    }
  }

  /// 简单 JSON 编码（避免额外依赖）
  String _simpleJsonEncode(Map<String, dynamic> map) {
    final entries = map.entries.map((e) {
      final value = e.value;
      if (value is String) return '"${e.key}":"$value"';
      if (value is bool) return '"${e.key}":$value';
      if (value is int) return '"${e.key}":$value';
      if (value is double) return '"${e.key}":$value';
      return '"${e.key}":$value';
    });
    return '{${entries.join(',')}}';
  }

  /// 简单 JSON 解析
  Map<String, dynamic> _parseSimpleJson(String json) {
    final result = <String, dynamic>{};
    final content = json.substring(1, json.length - 1);
    final pairs = content.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim().replaceAll('"', '');
        final value = parts[1].trim();
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value.contains('"')) {
          result[key] = value.replaceAll('"', '');
        } else {
          result[key] = int.tryParse(value) ?? double.tryParse(value) ?? value;
        }
      }
    }
    return result;
  }

  // ==================== 通知调度 ====================

  /// 重新调度所有通知
  Future<void> rescheduleAllNotifications() async {
    await cancelAllNotifications();

    if (!_settings.enabled) return;

    if (_settings.dailyStudyEnabled) {
      await scheduleDailyStudyNotification();
    }

    if (_settings.reviewReminderEnabled) {
      await scheduleReviewReminder();
    }

    if (_settings.checkinReminderEnabled) {
      await scheduleCheckinReminder();
    }
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 取消特定类型通知
  Future<void> cancelNotification(NotificationType type) async {
    switch (type) {
      case NotificationType.dailyStudy:
        await _notifications.cancel(_dailyStudyNotificationId);
        break;
      case NotificationType.reviewReminder:
        await _notifications.cancel(_reviewNotificationId);
        break;
      case NotificationType.checkinReminder:
        await _notifications.cancel(_checkinNotificationId);
        break;
      case NotificationType.testNotification:
        await _notifications.cancel(_testNotificationId);
        break;
    }
  }

  /// 调度每日学习提醒
  Future<void> scheduleDailyStudyNotification() async {
    if (!_settings.enabled || !_settings.dailyStudyEnabled) return;

    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _settings.dailyStudyTime.hour,
      _settings.dailyStudyTime.minute,
    );

    // 如果今天的时间已过，安排到明天
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _dailyStudyNotificationId,
      title: '📚 每日学习提醒',
      body: '该背单词啦！坚持每天学习，四级必过！',
      scheduledDate: scheduledTime,
      payload: 'vocabulary',
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('每日学习提醒已设置: ${scheduledTime.toIso8601String()}');
  }

  /// 调度复习提醒
  Future<void> scheduleReviewReminder() async {
    if (!_settings.enabled || !_settings.reviewReminderEnabled) return;

    final now = DateTime.now();
    // 下午3点提醒复习
    var scheduledTime = DateTime(now.year, now.month, now.day, 15, 0);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _reviewNotificationId,
      title: '🔄 复习提醒',
      body: '有单词需要复习了，及时巩固记忆效果更佳！',
      scheduledDate: scheduledTime,
      payload: 'wordStudy',
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('复习提醒已设置: ${scheduledTime.toIso8601String()}');
  }

  /// 调度打卡提醒
  Future<void> scheduleCheckinReminder() async {
    if (!_settings.enabled || !_settings.checkinReminderEnabled) return;

    final now = DateTime.now();
    // 晚上9点提醒打卡
    var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _checkinNotificationId,
      title: '⏰ 打卡提醒',
      body: '今天还没完成学习目标哦，坚持打卡，养成好习惯！',
      scheduledDate: scheduledTime,
      payload: 'home',
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('打卡提醒已设置: ${scheduledTime.toIso8601String()}');
  }

  /// 发送即时复习提醒（当检测到有单词需要复习时调用）
  Future<void> showInstantReviewReminder(int reviewCount) async {
    if (!_settings.enabled || !_settings.reviewReminderEnabled) return;

    await _showInstantNotification(
      id: _reviewNotificationId,
      title: '🔄 复习时间到',
      body: '你有 $reviewCount 个单词需要复习，快来巩固一下吧！',
      payload: 'wordStudy',
    );
  }

  /// 发送即时打卡提醒（当检测到当天未完成学习目标时调用）
  Future<void> showInstantCheckinReminder() async {
    if (!_settings.enabled || !_settings.checkinReminderEnabled) return;

    await _showInstantNotification(
      id: _checkinNotificationId,
      title: '⏰ 今日打卡',
      body: '今天还没有完成学习目标，快去背几个单词吧！',
      payload: 'home',
    );
  }

  /// 发送测试通知
  Future<void> showTestNotification() async {
    await _showInstantNotification(
      id: _testNotificationId,
      title: '🔔 通知测试',
      body: 'CET4 备考助手通知功能正常工作！',
      payload: 'home',
    );
  }

  // ==================== 底层通知方法 ====================

  /// 调度定时通知
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );

      final darwinDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('调度通知失败: $e');
    }
  }

  /// 发送即时通知
  Future<void> _showInstantNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(body),
      );

      final darwinDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('发送即时通知失败: $e');
    }
  }

  /// 获取待发送的通知列表
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// 更新设置并重新调度
  Future<void> updateSettings({
    bool? enabled,
    bool? dailyStudyEnabled,
    TimeOfDay? dailyStudyTime,
    bool? reviewReminderEnabled,
    bool? checkinReminderEnabled,
  }) async {
    final newSettings = NotificationSettings(
      enabled: enabled ?? _settings.enabled,
      dailyStudyEnabled: dailyStudyEnabled ?? _settings.dailyStudyEnabled,
      dailyStudyTime: dailyStudyTime ?? _settings.dailyStudyTime,
      reviewReminderEnabled:
          reviewReminderEnabled ?? _settings.reviewReminderEnabled,
      checkinReminderEnabled:
          checkinReminderEnabled ?? _settings.checkinReminderEnabled,
    );

    await saveSettings(newSettings);
  }
}
