import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;

  late bool _enabled;
  late bool _dailyStudyEnabled;
  late TimeOfDay _dailyStudyTime;
  late bool _reviewReminderEnabled;
  late bool _checkinReminderEnabled;

  static const _primaryColor = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = _notificationService.settings;
    setState(() {
      _enabled = settings.enabled;
      _dailyStudyEnabled = settings.dailyStudyEnabled;
      _dailyStudyTime = settings.dailyStudyTime;
      _reviewReminderEnabled = settings.reviewReminderEnabled;
      _checkinReminderEnabled = settings.checkinReminderEnabled;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _notificationService.updateSettings(
      enabled: _enabled,
      dailyStudyEnabled: _dailyStudyEnabled,
      dailyStudyTime: _dailyStudyTime,
      reviewReminderEnabled: _reviewReminderEnabled,
      checkinReminderEnabled: _checkinReminderEnabled,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyStudyTime,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dailyStudyTime) {
      setState(() {
        _dailyStudyTime = picked;
      });
      await _saveSettings();
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('测试通知已发送')),
      );
    }
  }

  Future<void> _requestPermissionIfNeeded(bool value) async {
    if (value) {
      final granted = await _notificationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请前往系统设置开启通知权限')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC),
        foregroundColor: isDark ? Colors.grey[200] : Colors.black87,
        elevation: 0,
        title: const Text('学习提醒'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildMasterSwitch(context, isDark),
                        const SizedBox(height: 24),
                        if (_enabled) ...[
                          _buildSectionTitle(context, '提醒设置'),
                          const SizedBox(height: 12),
                          _buildReminderCard(context, isDark),
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, '测试'),
                          const SizedBox(height: 12),
                          _buildTestCard(context, isDark),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMasterSwitch(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _enabled
                  ? _primaryColor.withOpacity(0.15)
                  : (isDark ? Colors.grey[700] : Colors.grey[200]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: _enabled ? _primaryColor : (isDark ? Colors.grey[500] : Colors.grey[500]),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '学习提醒总开关',
                  style: TextStyle(
                    color: isDark ? Colors.grey[200] : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _enabled ? '已开启，将按时发送学习提醒' : '已关闭，不会收到任何提醒',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (value) async {
              await _requestPermissionIfNeeded(value);
              setState(() {
                _enabled = value;
              });
              await _saveSettings();
            },
            activeColor: _primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildTimePickerItem(context, isDark),
          _buildDivider(isDark),
          _buildSwitchItem(
            context,
            isDark: isDark,
            icon: Icons.menu_book_rounded,
            iconColor: Colors.teal,
            title: '每日学习提醒',
            subtitle: '每天 ${_dailyStudyTime.hour.toString().padLeft(2, '0')}:${_dailyStudyTime.minute.toString().padLeft(2, '0')} 提醒学习',
            value: _dailyStudyEnabled,
            onChanged: (value) {
              setState(() {
                _dailyStudyEnabled = value;
              });
              _saveSettings();
            },
          ),
          _buildDivider(isDark),
          _buildSwitchItem(
            context,
            isDark: isDark,
            icon: Icons.sync_rounded,
            iconColor: Colors.orange,
            title: '复习提醒',
            subtitle: '有单词需要复习时推送通知',
            value: _reviewReminderEnabled,
            onChanged: (value) {
              setState(() {
                _reviewReminderEnabled = value;
              });
              _saveSettings();
            },
          ),
          _buildDivider(isDark),
          _buildSwitchItem(
            context,
            isDark: isDark,
            icon: Icons.check_circle_rounded,
            iconColor: Colors.green,
            title: '打卡提醒',
            subtitle: '当天未完成学习目标时提醒',
            value: _checkinReminderEnabled,
            onChanged: (value) {
              setState(() {
                _checkinReminderEnabled = value;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerItem(BuildContext context, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.access_time_rounded, color: _primaryColor, size: 20),
      ),
      title: Text(
        '提醒时间',
        style: TextStyle(
          color: isDark ? Colors.grey[200] : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '设置每日学习提醒的时间',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[500],
          fontSize: 12,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${_dailyStudyTime.hour.toString().padLeft(2, '0')}:${_dailyStudyTime.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _primaryColor,
            fontSize: 14,
          ),
        ),
      ),
      onTap: _pickTime,
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.grey[200] : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[500],
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: _enabled ? onChanged : null,
        activeColor: _primaryColor,
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_active_rounded, color: Colors.purple, size: 20),
        ),
        title: Text(
          '发送测试通知',
          style: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '立即发送一条测试通知，检查功能是否正常',
          style: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[500],
            fontSize: 12,
          ),
        ),
        trailing: FilledButton.icon(
          onPressed: _enabled ? _testNotification : null,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('测试'),
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFF1F5F9),
    );
  }
}
