import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/user_provider.dart';
import '../../provider/study_provider.dart';
import '../../provider/ai_provider.dart';
import '../../provider/navigation_provider.dart';
import '../../database/db_helper.dart';
import '../../utils/claude_api.dart';
import '../../services/lock_screen_service.dart';
import '../word_book/word_book_manager_page.dart';
import '../vocabulary/lock_screen_words_page.dart';
import 'notification_settings_page.dart';
import 'study_statistics_page.dart';
import 'cloud_sync_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _primaryColor = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC),
      body: Consumer2<UserProvider, StudyProvider>(
        builder: (context, userProvider, studyProvider, child) {
          return CustomScrollView(
            slivers: [
              _buildGradientHeader(context, isDark, studyProvider),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildStudyStats(context, isDark, studyProvider),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, '学习数据'),
                      const SizedBox(height: 12),
                      _buildStatisticsCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, '学习设置'),
                      const SizedBox(height: 12),
                      _buildSettingsCard(context, isDark, userProvider),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, '锁屏学习'),
                      const SizedBox(height: 12),
                      _buildLockScreenCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, '提醒设置'),
                      const SizedBox(height: 12),
                      _buildNotificationCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, '数据管理'),
                      const SizedBox(height: 12),
                      _buildDataCard(context, isDark, userProvider),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, '关于'),
                      const SizedBox(height: 12),
                      _buildAboutCard(context, isDark),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGradientHeader(BuildContext context, bool isDark, StudyProvider studyProvider) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 28,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '个人中心',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${studyProvider.checkinDays} 天',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CET4 备考用户',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '坚持学习，每天进步一点点',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyStats(BuildContext context, bool isDark, StudyProvider studyProvider) {
    final progress = studyProvider.studyProgress;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习统计',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, '已学习', '${progress['total'] ?? 0}', const Color(0xFF4F46E5), isDark),
              _buildStatItem(context, '已掌握', '${progress['mastered'] ?? 0}', Colors.green, isDark),
              _buildStatItem(context, '学习中', '${progress['learning'] ?? 0}', Colors.orange, isDark),
              _buildStatItem(context, '已遗忘', '${progress['forgotten'] ?? 0}', Colors.red, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
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

  Widget _buildStatisticsCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildSettingsItem(
        context,
        isDark: isDark,
        icon: Icons.bar_chart_rounded,
        iconColor: _primaryColor,
        title: '学习数据统计',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudyStatisticsPage()),
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, bool isDark, UserProvider userProvider) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.dark_mode_rounded,
            iconColor: Colors.indigo,
            title: '深色模式',
            trailing: Switch(
              value: userProvider.themeMode == ThemeMode.dark,
              onChanged: (value) {
                userProvider.updateThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
              activeColor: _primaryColor,
            ),
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.text_fields_rounded,
            iconColor: Colors.teal,
            title: '字体大小',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconButton(
                  Icons.remove_rounded,
                  () {
                    final newSize = (userProvider.fontSize - 0.1).clamp(0.8, 1.5);
                    userProvider.updateFontSize(newSize);
                  },
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(userProvider.fontSize * 100).toInt()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _buildIconButton(
                  Icons.add_rounded,
                  () {
                    final newSize = (userProvider.fontSize + 0.1).clamp(0.8, 1.5);
                    userProvider.updateFontSize(newSize);
                  },
                ),
              ],
            ),
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.track_changes_rounded,
            iconColor: Colors.deepPurple,
            title: '每日目标',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconButton(
                  Icons.remove_rounded,
                  () {
                    final newGoal = (userProvider.dailyWordGoal - 10).clamp(10, 200);
                    userProvider.updateDailyWordGoal(newGoal);
                  },
                ),
                GestureDetector(
                  onTap: () => _showGoalInputDialog(context, userProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${userProvider.dailyWordGoal}个',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                _buildIconButton(
                  Icons.add_rounded,
                  () {
                    final newGoal = (userProvider.dailyWordGoal + 10).clamp(10, 200);
                    userProvider.updateDailyWordGoal(newGoal);
                  },
                ),
              ],
            ),
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.volume_up_rounded,
            iconColor: Colors.blue,
            title: '音效',
            trailing: Switch(
              value: userProvider.soundEnabled,
              onChanged: (value) => userProvider.updateSoundEnabled(value),
              activeColor: _primaryColor,
            ),
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.api_rounded,
            iconColor: Colors.orange,
            title: 'API设置',
            onTap: () => _showApiSettings(context, userProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildLockScreenCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          FutureBuilder(
            future: LockScreenService().init(),
            builder: (context, snapshot) {
              final service = LockScreenService();
              return _buildSettingsItem(
                context,
                isDark: isDark,
                icon: Icons.screen_lock_portrait_rounded,
                iconColor: Colors.indigoAccent,
                title: '锁屏背单词',
                trailing: Switch(
                  value: service.isEnabled,
                  onChanged: (value) async {
                    await service.setEnabled(value);
                    (context as Element).markNeedsBuild();
                  },
                  activeColor: _primaryColor,
                ),
                onTap: () => _showLockScreenSettings(context, isDark),
              );
            },
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.play_circle_fill_rounded,
            iconColor: Colors.deepPurple,
            title: '进入锁屏模式',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LockScreenWordsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showLockScreenSettings(BuildContext context, bool isDark) {
    final service = LockScreenService();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '锁屏背单词设置',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '开启后，每次解锁屏幕将显示单词卡片',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLockScreenSettingItem(
                      context,
                      isDark: isDark,
                      icon: Icons.toggle_on_rounded,
                      title: '启用锁屏单词',
                      trailing: Switch(
                        value: service.isEnabled,
                        onChanged: (value) async {
                          await service.setEnabled(value);
                          setModalState(() {});
                          (ctx as Element).markNeedsBuild();
                        },
                        activeColor: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLockScreenSettingItem(
                      context,
                      isDark: isDark,
                      icon: Icons.format_list_numbered_rounded,
                      title: '每次显示单词数',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIconButton(
                            Icons.remove_rounded,
                            () async {
                              final newCount = (service.wordsPerUnlock - 1).clamp(1, 5);
                              await service.setWordsPerUnlock(newCount);
                              setModalState(() {});
                            },
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${service.wordsPerUnlock}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          _buildIconButton(
                            Icons.add_rounded,
                            () async {
                              final newCount = (service.wordsPerUnlock + 1).clamp(1, 5);
                              await service.setWordsPerUnlock(newCount);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLockScreenSettingItem(
                      context,
                      isDark: isDark,
                      icon: Icons.timer_rounded,
                      title: '显示时长',
                      trailing: GestureDetector(
                        onTap: () => _showDurationPicker(ctx, isDark, service, setModalState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            service.getDisplayDurationText(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('确定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLockScreenSettingItem(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey[200] : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing,
      ],
    );
  }

  void _showDurationPicker(BuildContext context, bool isDark, LockScreenService service, StateSetter setModalState) {
    final options = [
      {'value': 0, 'label': '一直显示'},
      {'value': 5, 'label': '5秒'},
      {'value': 10, 'label': '10秒'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '选择显示时长',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final value = opt['value'] as int;
                final label = opt['label'] as String;
                final isSelected = service.displayDuration == value;
                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.grey[200] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: _primaryColor)
                      : null,
                  onTap: () async {
                    await service.setDisplayDuration(value);
                    setModalState(() {});
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.notifications_active_rounded,
            iconColor: Colors.purple,
            title: '学习提醒',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(BuildContext context, bool isDark, UserProvider userProvider) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.library_books_rounded,
            iconColor: Colors.cyan,
            title: '词书管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WordBookManagerPage()),
              );
            },
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.cloud_sync_rounded,
            iconColor: _primaryColor,
            title: '云同步',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CloudSyncPage()),
              );
            },
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.backup_rounded,
            iconColor: Colors.green,
            title: '数据备份',
            onTap: () => _backupData(context),
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.restore_rounded,
            iconColor: Colors.amber,
            title: '数据恢复',
            onTap: () => _restoreData(context),
          ),
          _buildDivider(isDark),
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.delete_forever_rounded,
            iconColor: Colors.red,
            title: '清空数据',
            titleColor: Colors.red,
            onTap: () => _showClearDataDialog(context, userProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            context,
            isDark: isDark,
            icon: Icons.info_outline_rounded,
            iconColor: Colors.grey,
            title: '版本',
            trailing: Text(
              'v1.0.0',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
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
          color: titleColor ?? (isDark ? Colors.grey[200] : Colors.black87),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
      onTap: onTap,
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

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: _primaryColor),
        ),
      ),
    );
  }

  void _showGoalInputDialog(BuildContext context, UserProvider userProvider) {
    final controller = TextEditingController(text: '${userProvider.dailyWordGoal}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('设置每日目标'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '每日背单词数量',
            hintText: '10~200',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 10 && value <= 200) {
                userProvider.updateDailyWordGoal(value);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入10~200之间的数字')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _backupData(BuildContext context) async {
    try {
      final dbHelper = DbHelper();
      final studyRecords = await dbHelper.query('study_records');
      final wrongQuestions = await dbHelper.query('wrong_questions');
      final wordBookmarks = await dbHelper.query('word_bookmarks');
      final userSettings = await dbHelper.query('user_settings');

      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'study_records': studyRecords,
        'wrong_questions': wrongQuestions,
        'word_bookmarks': wordBookmarks,
        'user_settings': userSettings,
      };

      final backupJson = jsonEncode(backupData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_data', backupJson);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据备份成功！备份已保存到本地')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString('backup_data');

      if (backupJson == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有找到备份数据')),
          );
        }
        return;
      }

      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('数据恢复'),
            content: const Text('恢复数据将覆盖当前数据，确定要继续吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消', style: TextStyle(color: Colors.grey[600])),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('确定恢复'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
      final dbHelper = DbHelper();

      await dbHelper.delete('study_records');
      await dbHelper.delete('wrong_questions');
      await dbHelper.delete('word_bookmarks');

      final studyRecords = backupData['study_records'] as List?;
      if (studyRecords != null) {
        for (var record in studyRecords) {
          await dbHelper.insert('study_records', Map<String, dynamic>.from(record));
        }
      }

      final wrongQuestions = backupData['wrong_questions'] as List?;
      if (wrongQuestions != null) {
        for (var record in wrongQuestions) {
          await dbHelper.insert('wrong_questions', Map<String, dynamic>.from(record));
        }
      }

      final wordBookmarks = backupData['word_bookmarks'] as List?;
      if (wordBookmarks != null) {
        for (var record in wordBookmarks) {
          await dbHelper.insert('word_bookmarks', Map<String, dynamic>.from(record));
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据恢复成功！')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }

  void _showApiSettings(BuildContext context, UserProvider userProvider) {
    final baseUrlController = TextEditingController(text: userProvider.baseUrl);
    final apiKeyController = TextEditingController(text: userProvider.apiKey ?? '');
    final modelController = TextEditingController(text: userProvider.modelName);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('API设置'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baseUrlController,
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                        helperText: '支持 OpenAI 兼容接口 (OpenAI/DeepSeek/Ollama/酒馆等)',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'API密钥',
                        hintText: '输入您的API密钥 (sk-...)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: modelController,
                      decoration: InputDecoration(
                        labelText: '模型名称',
                        hintText: 'gpt-4o-mini / deepseek-chat / claude-sonnet-4-20250514',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: Colors.grey[600])),
                ),
                FilledButton(
                  onPressed: () async {
                    final baseUrl = baseUrlController.text.trim();
                    final apiKey = apiKeyController.text.trim();
                    final modelName = modelController.text.trim();
                    if (apiKey.isNotEmpty) {
                      if (baseUrl.isNotEmpty) {
                        await userProvider.updateBaseUrl(baseUrl);
                      }
                      await userProvider.updateApiKey(apiKey);
                      if (modelName.isNotEmpty) {
                        await userProvider.updateModelName(modelName);
                      }
                      context.read<AiProvider>().initApi(
                        apiKey,
                        baseUrl: baseUrl.isNotEmpty ? baseUrl : null,
                        model: modelName.isNotEmpty ? modelName : ClaudeApiService.defaultModel,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('API配置已保存')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('清空数据'),
          content: const Text(
            '确定要清空所有数据吗？此操作不可恢复，将删除所有学习记录、打卡记录、错题本和生词本。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: Colors.grey[600])),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('正在清理...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                await userProvider.clearAllData();

                if (context.mounted) {
                  context.read<StudyProvider>().resetState();
                }

                if (context.mounted) {
                  context.read<NavigationProvider>().goToHome();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数据已清空，所有记录已重置')),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('确定清空'),
            ),
          ],
        );
      },
    );
  }
}
