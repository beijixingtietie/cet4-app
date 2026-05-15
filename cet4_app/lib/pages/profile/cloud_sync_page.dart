import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/sync_service.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  final SyncService _syncService = SyncService();
  final TextEditingController _userIdController = TextEditingController();

  bool _autoSyncEnabled = false;
  DateTime? _lastSyncTime;
  String _syncStatusText = '未同步';
  List<SyncDataInfo> _dataInfoList = [];
  bool _isLoading = true;

  static const Color _primaryColor = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _syncService.getSyncUserId();
      final autoSync = await _syncService.getAutoSyncEnabled();
      final lastSync = await _syncService.getLastSyncTime();
      final statusText = await _syncService.getSyncStatusText();
      final dataInfo = await _syncService.getLocalDataInfo();

      setState(() {
        _userIdController.text = userId ?? '';
        _autoSyncEnabled = autoSync;
        _lastSyncTime = lastSync;
        _syncStatusText = statusText;
        _dataInfoList = dataInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载设置失败: $e')),
        );
      }
    }
  }

  Future<void> _saveUserId() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户ID')),
      );
      return;
    }
    await _syncService.setSyncUserId(userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户ID已保存')),
      );
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    await _syncService.setAutoSyncEnabled(value);
    setState(() => _autoSyncEnabled = value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? '已开启自动同步' : '已关闭自动同步')),
      );
    }
  }

  Future<void> _performSync() async {
    final result = await _syncService.syncToCloud();
    if (mounted) {
      _showResultSnackBar(result);
      await _loadSettings();
    }
  }

  Future<void> _performIncrementalSync() async {
    final result = await _syncService.incrementalSync();
    if (mounted) {
      _showResultSnackBar(result);
      await _loadSettings();
    }
  }

  Future<void> _performRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('从云端恢复'),
        content: const Text(
          '恢复操作将使用云端数据覆盖本地数据，此操作不可撤销。\n\n冲突解决策略：以本地数据为准。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _syncService.restoreFromCloud();
    if (mounted) {
      _showResultSnackBar(result);
      await _loadSettings();
    }
  }

  void _showResultSnackBar(SyncResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  String _formatSyncTime(DateTime? time) {
    if (time == null) return '从未同步';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF1A1F2E) : Colors.white;
    final textColor = isDark ? Colors.grey[200] : Colors.black87;
    final subTextColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '云同步',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    _buildUserIdCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    _buildAutoSyncCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    _buildActionButtons(cardColor, textColor),
                    const SizedBox(height: 16),
                    _buildDataListCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(Color cardColor, Color? textColor, Color? subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '同步状态',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<SyncStatus>(
                      valueListenable: _syncService.syncStatusNotifier,
                      builder: (context, status, child) {
                        String statusText = _syncStatusText;
                        Color statusColor = subTextColor ?? Colors.grey;
                        if (status == SyncStatus.syncing) {
                          statusText = '同步中...';
                          statusColor = _primaryColor;
                        } else if (status == SyncStatus.success) {
                          statusText = '同步成功';
                          statusColor = Colors.green;
                        } else if (status == SyncStatus.error) {
                          statusText = '同步失败';
                          statusColor = Colors.red;
                        }
                        return Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: textColor?.withOpacity(0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最后同步时间',
                style: TextStyle(fontSize: 14, color: subTextColor),
              ),
              Text(
                _formatSyncTime(_lastSyncTime),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '本地数据总量',
                style: TextStyle(fontSize: 14, color: subTextColor),
              ),
              Text(
                '${_dataInfoList.fold<int>(0, (sum, e) => sum + e.count)} 条',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserIdCard(Color cardColor, Color? textColor, Color? subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '用户ID（多设备识别）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '设置相同的用户ID可在多设备间同步数据',
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userIdController,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '请输入用户ID',
                    hintStyle: TextStyle(color: subTextColor?.withOpacity(0.5)),
                    filled: true,
                    fillColor: textColor?.withOpacity(0.03),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _saveUserId,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncCard(Color cardColor, Color? textColor, Color? subTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.schedule_rounded, color: Colors.teal, size: 20),
        ),
        title: Text(
          '自动同步',
          style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '每天自动执行一次增量同步',
          style: TextStyle(color: subTextColor, fontSize: 12),
        ),
        trailing: Switch(
          value: _autoSyncEnabled,
          onChanged: _toggleAutoSync,
          activeColor: _primaryColor,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color cardColor, Color? textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '同步操作',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<SyncStatus>(
            valueListenable: _syncService.syncStatusNotifier,
            builder: (context, status, child) {
              final isSyncing = status == SyncStatus.syncing;
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSyncing ? null : _performIncrementalSync,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(isSyncing ? '同步中...' : '立即同步（增量）'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSyncing ? null : _performSync,
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: const Text('完整备份到云端'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: const BorderSide(color: _primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSyncing ? null : _performRestore,
                      icon: const Icon(Icons.cloud_download_rounded, size: 18),
                      label: const Text('从云端恢复'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataListCard(Color cardColor, Color? textColor, Color? subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '同步数据详情',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ..._dataInfoList.map((info) => _buildDataItem(info, textColor, subTextColor)),
        ],
      ),
    );
  }

  Widget _buildDataItem(SyncDataInfo info, Color? textColor, Color? subTextColor) {
    IconData icon;
    Color iconColor;
    switch (info.tableName) {
      case 'study_records':
        icon = Icons.menu_book_rounded;
        iconColor = Colors.blue;
        break;
      case 'user_settings':
        icon = Icons.settings_rounded;
        iconColor = Colors.grey;
        break;
      case 'word_bookmarks':
        icon = Icons.bookmark_rounded;
        iconColor = Colors.pink;
        break;
      case 'wrong_questions':
        icon = Icons.error_outline_rounded;
        iconColor = Colors.red;
        break;
      case 'exam_records':
        icon = Icons.assignment_rounded;
        iconColor = Colors.purple;
        break;
      case 'ai_conversations':
        icon = Icons.chat_bubble_outline_rounded;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.storage_rounded;
        iconColor = _primaryColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (info.lastModified != null)
                  Text(
                    '最近更新: ${_formatSyncTime(info.lastModified)}',
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${info.count} 条',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
