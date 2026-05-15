import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/ai_provider.dart';
import '../../provider/user_provider.dart';
import '../../utils/claude_api.dart';
import '../../utils/agent_executor.dart';
import '../../utils/batch_word_filler.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  BatchWordFiller? _batchFiller;
  CancelToken? _currentCancelToken;

  static const _primaryColor = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _loadConversationHistory();
  }

  Future<void> _loadConversationHistory() async {
    final aiProvider = context.read<AiProvider>();
    await aiProvider.loadConversations();
    setState(() {
      _messages.clear();
      for (var msg in aiProvider.conversations) {
        _messages.add({
          'role': msg['role'] as String,
          'content': msg['content'] as String,
        });
      }
    });
  }

  static const _agentSystemPrompt = '''你是CET4备考助手的内置编辑Agent。

【意图分类规则 — 最高优先级】
根据用户消息的语义自动判断模式，无需用户手动添加前缀：

触发「Agent编辑模式」的关键词/语义：
- 修改类：修改、更新、改、改成、改为、修正、更正、纠正
- 删除类：删除、移除、去掉、清理、清空
- 新增类：添加、增加、新增、录入、加入、写进去
- 批量类：批量、全部、所有、统一、一次性、补全、填充、完善、补齐
- 组合指令：帮我改、帮我删、帮我加、帮我把、请把、能不能把
- 只要语义上是对词库/题库/每日目标的增删改操作，一律进入 Agent 编辑模式
- Agent 编辑模式下，只返回纯 JSON（不要加 ```json ``` 标记，不要任何额外文字，不要解释）

以下情况使用「普通辅导模式」正常回复：
- 提问、咨询、查询词义、翻译、语法讲解、学习建议、考试技巧
- 请求解释某个单词或题目的含义
- 非修改类的任何对话

【Agent编辑模式 — 支持的 action 与 JSON 格式】

可修改的单词字段：word(单词), meaning(释义), phonetic_uk(英式音标), phonetic_us(美式音标), type(词性), example(例句), example_translation(例句翻译), collocation(搭配), level(级别)
可修改的题目字段：content(题干), options(选项), answer(答案), explanation(解析), type(题型), year(年份)

JSON 必须包含 action、params、confirmMessage 三个字段：

{"action":"update_word","params":{"target":"要改的单词","field":"字段名","newValue":"新内容"},"confirmMessage":"用户可见的确认信息"}
{"action":"batch_update_words","params":{"words":[{"target":"单词1","field":"字段名","newValue":"新值"},{"target":"单词2","field":"字段名","newValue":"新值"}]},"confirmMessage":"批量更新 N 个字段"}
{"action":"add_word","params":{"word":"单词","meaning":"释义","type":"词性","phonetic_uk":"音标","example":"例句","example_translation":"例句翻译","collocation":"搭配","level":"级别"},"confirmMessage":"用户可见的确认信息"}
{"action":"delete_word","params":{"target":"要删的单词"},"confirmMessage":"用户可见的确认信息"}
{"action":"update_question","params":{"target":"题目关键词","field":"字段名","newValue":"新内容"},"confirmMessage":"用户可见的确认信息"}
{"action":"set_daily_goal","params":{"newValue":30},"confirmMessage":"用户可见的确认信息"}
{"action":"offline_import_full_wordbank","params":{},"confirmMessage":"从离线词库重新导入完整四级单词（秒级完成，覆盖所有错误数据，修复字段错位）"}
{"action":"start_batch_fill","params":{},"confirmMessage":"开始自动分批填充词库所有单词（分批次循环，支持中断恢复）"}

特别指令：当用户发送「重置并修复所有单词」或「重置词库」时，必须返回 offline_import_full_wordbank，不要使用 start_batch_fill。
{"action":"list_words","params":{"filter":"all 或 empty_fields","limit":50,"offset":0},"confirmMessage":"查询词库单词列表"}

★★★★★ 最重要规则 ★★★★★

1. 当用户要求"填充/补全"某个单词的多个字段时，必须使用 batch_update_words，在 words 数组中为同一个 target 写多条记录，每一条改一个字段。例如用户说「把account的词性、释义、例句、例句翻译、常见搭配填充完整」，你必须返回：
{"action":"batch_update_words","params":{"words":[
  {"target":"account","field":"type","newValue":"n."},
  {"target":"account","field":"meaning","newValue":"账户；账号"},
  {"target":"account","field":"example","newValue":"I opened a new bank account yesterday."},
  {"target":"account","field":"example_translation","newValue":"我昨天开了一个新的银行账户。"},
  {"target":"account","field":"collocation","newValue":"bank account; take account of; on account of"}
]},"confirmMessage":"填充account的5个字段（词性、释义、例句、例句翻译、常见搭配）"}

2. 如果用户要求填充多个单词的字段，同样使用 batch_update_words，每个单词每个字段一条记录。

3. target 必须是数据库中真实存在的单词名（大小写不敏感），不能虚构、不能缩写。

4. 当用户要求"所有单词"或"词库内全部"填充时，返回 start_batch_fill action。系统会自动：查询全部单词 → 分批次（每批50个）→ 每批发送给AI生成内容 → 执行更新 → 自动下一批 → 直到全部完成。你只需要返回一条 start_batch_fill JSON，后续系统自动循环处理，不需要你再操心分批逻辑。

5. 每条 newValue 必须是真实合理的四级英语内容，不能编造、不能留空。

【普通辅导模式】用户提问、咨询、练习等非修改类问题时，作为专业的大学英语四级备考老师正常回复。用简洁中文，重点突出，符合四级考试要求。''';

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _currentCancelToken = CancelToken();

    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final aiProvider = context.read<AiProvider>();

      // 检测是否是 Agent 编辑指令（需要 JSON 模式）
      final isAgentCommand = _isAgentEditCommand(message);

      if (isAgentCommand) {
        // Agent 模式：使用普通请求（需要完整 JSON）
        final response = await aiProvider.sendMessage(
          message,
          systemPrompt: _agentSystemPrompt,
          responseFormatJson: true,
          cancelToken: _currentCancelToken,
        );

        if (!mounted) return;
        if (_currentCancelToken != null && _currentCancelToken!.isCancelled) return;

        final command = AgentExecutor.tryParseCommand(response);
        if (command != null) {
          final action = command['action'] as String? ?? '';
          await aiProvider.deleteLastAssistantMessage();
          setState(() => _isLoading = false);
          _currentCancelToken = null;

          if (action == 'start_batch_fill' || action == 'offline_import_full_wordbank') {
            await _handleAgentCommand(command, aiProvider);
          } else if (action == 'list_words') {
            final executor = AgentExecutor();
            final result = await executor.execute(command);
            if (!mounted) return;
            setState(() {
              _messages.add({'role': 'assistant', 'content': result});
            });
            await aiProvider.saveAssistantMessage(result);
          } else {
            await _handleAgentCommand(command, aiProvider);
          }
        } else {
          setState(() {
            _messages.add({'role': 'assistant', 'content': response});
            _isLoading = false;
          });
          _currentCancelToken = null;
        }
      } else {
        // 普通对话模式：使用流式响应（打字机效果）
        await _sendStreamMessage(aiProvider, message);
      }

      _scrollToBottom();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '⏹ 已停止生成'});
          _isLoading = false;
        });
        _currentCancelToken = null;
        return;
      }
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'content': '抱歉，发生错误: ${e.message}'});
        _isLoading = false;
      });
      _currentCancelToken = null;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'content': '抱歉，发生错误: $e'});
        _isLoading = false;
      });
      _currentCancelToken = null;
    }
  }

  /// 判断是否是 Agent 编辑指令
  bool _isAgentEditCommand(String message) {
    final agentKeywords = [
      '修改', '更新', '改', '改成', '改为', '修正', '更正', '纠正',
      '删除', '移除', '去掉', '清理', '清空',
      '添加', '增加', '新增', '录入', '加入', '写进去',
      '批量', '全部', '所有', '统一', '一次性', '补全', '填充', '完善', '补齐',
      '帮我改', '帮我删', '帮我加', '帮我把', '请把', '能不能把',
      '重置', '修复',
    ];
    return agentKeywords.any((kw) => message.contains(kw));
  }

  /// 发送流式消息（打字机效果）
  Future<void> _sendStreamMessage(AiProvider aiProvider, String message) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final stream = aiProvider.sendMessageStream(
      message,
      systemPrompt: '''你是一位专业的大学英语四级备考助手，专门为准备英语四级考试的学生提供帮助。

你的职责包括：
1. 回答任何关于英语四级考试的问题
2. 解释英语语法知识点
3. 生成四级模拟题
4. 提供学习方法和备考建议
5. 进行简单的英语对话练习

请用简洁明了的中文回答问题，重点突出，符合四级考试要求。''',
      requestId: requestId,
    );

    // 先添加一个空的 assistant 消息占位
    setState(() {
      _messages.add({'role': 'assistant', 'content': ''});
    });
    _scrollToBottom();

    String fullResponse = '';
    bool hasError = false;

    await for (final chunk in stream) {
      if (!mounted) return;
      if (_currentCancelToken != null && _currentCancelToken!.isCancelled) {
        break;
      }

      fullResponse += chunk;
      setState(() {
        _messages.last['content'] = fullResponse;
      });
      _scrollToBottom();
    }

    if (!mounted) return;

    // 保存完整的 AI 回复到数据库
    if (fullResponse.isNotEmpty && !hasError) {
      await aiProvider.saveAssistantMessage(fullResponse);
    }

    setState(() {
      _isLoading = false;
    });
    _currentCancelToken = null;
  }

  void _stopGeneration() {
    _currentCancelToken?.cancel();
    _batchFiller?.stop();
    setState(() => _isLoading = false);
  }

  Future<void> _handleAgentCommand(
    Map<String, dynamic> command,
    AiProvider aiProvider,
  ) async {
    final confirmMessage = command['confirmMessage'] as String? ?? '确认执行此操作？';
    final action = command['action'] as String? ?? '';

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _actionColor(action).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_actionIcon(action), color: _actionColor(action), size: 22),
            ),
            const SizedBox(width: 12),
            Text(_actionTitle(action)),
          ],
        ),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确认执行'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      if (action == 'start_batch_fill') {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '🚀 正在启动批量填充引擎...',
          });
        });
        await _startBatchLoop(aiProvider);
        return;
      }

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '正在执行: $confirmMessage',
        });
      });

      final userProvider = context.read<UserProvider>();
      final executor = AgentExecutor();
      final result = await executor.execute(command, userProvider: userProvider);

      if (!mounted) return;

      setState(() {
        _messages.removeLast();
        _messages.add({'role': 'assistant', 'content': result});
      });

      await aiProvider.saveAssistantMessage(result);
    } else {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '操作已取消'});
      });
      await aiProvider.saveAssistantMessage('操作已取消');
    }
  }

  Future<void> _startBatchLoop(AiProvider aiProvider) async {
    _batchFiller = BatchWordFiller();
    final initMsg = await _batchFiller!.init();

    if (!mounted) return;

    setState(() {
      _messages.removeLast();
      _messages.add({'role': 'assistant', 'content': initMsg});
    });

    if (!_batchFiller!.isRunning) return;

    await _processNextBatch(aiProvider);
  }

  Future<void> _processNextBatch(AiProvider aiProvider) async {
    if (_batchFiller == null || !_batchFiller!.isRunning) return;
    if (!mounted) return;

    final batch = _batchFiller!.nextBatch();
    if (batch == null) {
      final completion = _batchFiller!.completionMessage;
      setState(() {
        _messages.add({'role': 'assistant', 'content': completion});
      });
      await aiProvider.saveAssistantMessage(completion);
      await _batchFiller!.reset();
      _batchFiller = null;
      return;
    }

    final progressMsg = _batchFiller!.progressMessage;
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': '$progressMsg\n⏳ 正在为第 ${_batchFiller!.currentBatch + 1} 批单词生成内容（${batch.join(', ')}）...',
      });
    });

    try {
      _currentCancelToken = CancelToken();
      final prompt = _batchFiller!.buildBatchPrompt(batch);

      final response = await aiProvider.sendMessage(
        prompt,
        systemPrompt: '''为以下单词一次性生成四级内容。只返回 batch_update_words JSON（不含```json```标记）。
每个单词5条：type(词性)/meaning(释义)/example(例句)/example_translation(例句翻译)/collocation(常见搭配)。
target 用上面的精确单词名。newValue 必须真实合理。格式：
{"action":"batch_update_words","params":{"words":[...每条{"target":"单词","field":"字段","newValue":"值"}...]},"confirmMessage":"第X批"}''',
        responseFormatJson: true,
        cancelToken: _currentCancelToken,
      );

      if (!mounted) return;
      if (_currentCancelToken != null && _currentCancelToken!.isCancelled) return;

      final command = AgentExecutor.tryParseCommand(response);
      int success = 0;
      int failed = 0;
      final failedWords = <String>[];

      if (command != null && command['action'] == 'batch_update_words') {
        final executor = AgentExecutor();
        final result = await executor.execute(command);
        final successMatch = RegExp(r'成功更新 (\d+) 个字段').firstMatch(result);
        if (successMatch != null) {
          success = int.tryParse(successMatch.group(1)!) ?? 0;
        }
        final expectedFields = batch.length * 5;
        failed = expectedFields - success;
        if (failed > 0) {
          final skipMatches = RegExp(r'❌ (\w+):').allMatches(result);
          failedWords.addAll(skipMatches.map((m) => m.group(1)!));
        }
      } else {
        failed = batch.length * 5;
        failedWords.addAll(batch);
      }

      _batchFiller!.recordBatchResult(success, failed, failedWords);

      setState(() {
        _messages.removeLast();
        final totalInBatch = batch.length * 5;
        _messages.add({
          'role': 'assistant',
          'content': '✅ 第 ${_batchFiller!.currentBatch}/${_batchFiller!.totalBatches} 批完成（${batch.join(', ')}）\n'
              '成功 $success/$totalInBatch 个字段'
              '${failed > 0 ? '，失败 $failed 个' : ''}',
        });
      });

      _currentCancelToken = null;
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        await _processNextBatch(aiProvider);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        setState(() {
          _messages.removeLast();
          _messages.add({'role': 'assistant', 'content': '⏹ 批量填充已停止。进度已保存，发送「继续批量填充」可恢复。'});
        });
        _currentCancelToken = null;
        return;
      }
      if (!mounted) return;
      _batchFiller!.recordBatchResult(0, batch.length * 5, batch);
      setState(() {
        _messages.removeLast();
        _messages.add({
          'role': 'assistant',
          'content': '❌ 第 ${_batchFiller!.currentBatch}/${_batchFiller!.totalBatches} 批失败: ${e.message}\n'
              '进度已保存，可稍后重试。',
        });
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await _processNextBatch(aiProvider);
      }
    } catch (e) {
      if (!mounted) return;
      _batchFiller!.recordBatchResult(0, batch.length * 5, batch);
      setState(() {
        _messages.removeLast();
        _messages.add({
          'role': 'assistant',
          'content': '❌ 第 ${_batchFiller!.currentBatch}/${_batchFiller!.totalBatches} 批失败: $e\n'
              '进度已保存，可稍后重试。',
        });
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await _processNextBatch(aiProvider);
      }
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'add_word':
        return Icons.add_circle_outline;
      case 'delete_word':
        return Icons.delete_outline;
      case 'set_daily_goal':
        return Icons.track_changes;
      default:
        return Icons.edit;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'delete_word':
        return Colors.red;
      case 'add_word':
        return Colors.green;
      default:
        return _primaryColor;
    }
  }

  String _actionTitle(String action) {
    switch (action) {
      case 'update_word':
        return '修改单词';
      case 'start_batch_fill':
        return '启动批量填充';
      case 'batch_update_words':
        return '批量修改单词';
      case 'add_word':
        return '新增单词';
      case 'delete_word':
        return '删除单词';
      case 'update_question':
        return '修改题目';
      case 'set_daily_goal':
        return '设置目标';
      case 'list_words':
        return '查询词库';
      case 'offline_import_full_wordbank':
        return '离线导入完整词库';
      default:
        return '确认操作';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _currentCancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC),
      body: Column(
        children: [
          _buildGradientHeader(context, isDark),
          if (!userProvider.isApiConfigured)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '请先配置API密钥才能使用AI功能',
                      style: TextStyle(
                        color: isDark ? Colors.orange[200] : Colors.orange[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _showApiSettings,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('去配置', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(context, isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildLoadingIndicator(isDark);
                      }
                      return _buildMessageBubble(_messages[index], isDark);
                    },
                  ),
          ),
          _buildInputArea(context, isDark),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    onPressed: _clearConversation,
                    tooltip: '清空对话',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    onPressed: _showApiSettings,
                    tooltip: 'API设置',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'AI 智能助手',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '你的专属四级备考辅导老师',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.75),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            '有什么四级备考问题可以问我？',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('帮我背单词', isDark),
              _buildSuggestionChip('四级语法讲解', isDark),
              _buildSuggestionChip('作文模板', isDark),
              _buildSuggestionChip('听力技巧', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, bool isDark) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDark) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : (isDark ? const Color(0xFF1A1F2E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Text(
          message['content'] as String,
          style: TextStyle(
            color: isUser ? Colors.white : (isDark ? Colors.grey[200] : Colors.black87),
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypingDots(),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _stopGeneration,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '停止',
                  style: TextStyle(fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 36,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return _TypingDot(delay: index * 0.2);
        }),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: '输入你的问题...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.grey[200] : Colors.black87,
                          fontSize: 15,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                      ),
                    ),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: _stopGeneration,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.stop_rounded, color: Colors.red[400], size: 20),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(14)),
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('清空对话'),
          content: const Text('确定要清空所有对话记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: Colors.grey[600])),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final aiProvider = context.read<AiProvider>();
                await aiProvider.clearConversations();
                setState(() => _messages.clear());
              },
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  static const List<Map<String, String>> _modelOptions = [
    {'label': 'GPT-4o Mini (推荐)', 'value': 'gpt-4o-mini'},
    {'label': 'GPT-4o', 'value': 'gpt-4o'},
    {'label': 'GPT-3.5 Turbo', 'value': 'gpt-3.5-turbo'},
    {'label': 'DeepSeek Chat', 'value': 'deepseek-chat'},
    {'label': 'DeepSeek Reasoner', 'value': 'deepseek-reasoner'},
    {'label': 'Claude Sonnet 4', 'value': 'claude-sonnet-4-20250514'},
    {'label': 'Claude Haiku 3.5', 'value': 'claude-3-5-haiku-20241022'},
    {'label': 'Qwen Turbo', 'value': 'qwen-turbo'},
    {'label': '自定义...', 'value': '__custom__'},
  ];

  void _showApiSettings() {
    final userProvider = context.read<UserProvider>();
    final baseUrlController = TextEditingController(text: userProvider.baseUrl);
    final apiKeyController = TextEditingController(text: userProvider.apiKey ?? '');

    final currentModel = userProvider.modelName;
    final presetIdx = _modelOptions.indexWhere((m) => m['value'] == currentModel);
    String selectedModel = presetIdx >= 0 ? currentModel : '__custom__';
    final customModelController = TextEditingController(
      text: presetIdx >= 0 ? '' : currentModel,
    );

    bool obscureKey = true;
    bool testing = false;
    String? testResult;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                        helperText: 'OpenAI 兼容接口均可使用',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: apiKeyController,
                      obscureText: obscureKey,
                      decoration: InputDecoration(
                        labelText: 'API密钥',
                        hintText: 'sk-...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _modelOptions.any((m) => m['value'] == selectedModel)
                          ? selectedModel
                          : '__custom__',
                      decoration: InputDecoration(
                        labelText: '模型',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _modelOptions.map((m) {
                        return DropdownMenuItem(
                          value: m['value'],
                          child: Text(m['label']!, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedModel = val ?? 'gpt-4o-mini';
                          if (selectedModel != '__custom__') {
                            customModelController.clear();
                          }
                        });
                      },
                    ),
                    if (selectedModel == '__custom__') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customModelController,
                        decoration: InputDecoration(
                          labelText: '自定义模型名称',
                          hintText: '输入模型名',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (testResult != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: testResult!.startsWith('✅')
                              ? Colors.green.withOpacity(0.08)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          testResult!,
                          style: TextStyle(
                            fontSize: 13,
                            color: testResult!.startsWith('✅')
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: testing
                            ? null
                            : () async {
                                setDialogState(() {
                                  testing = true;
                                  testResult = '⏳ 正在测试连接...';
                                });
                                try {
                                  final baseUrl = baseUrlController.text.trim();
                                  final apiKey = apiKeyController.text.trim();
                                  if (apiKey.isEmpty) {
                                    setDialogState(() {
                                      testResult = '❌ 请先输入API密钥';
                                      testing = false;
                                    });
                                    return;
                                  }
                                  final result = await AiProvider.testConnection(
                                    apiKey: apiKey,
                                    baseUrl: baseUrl.isNotEmpty
                                        ? baseUrl
                                        : ClaudeApiService.defaultBaseUrl,
                                  );
                                  setDialogState(() {
                                    testResult = result.startsWith('✅') ? result : '❌ $result';
                                    testing = false;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    testResult = '❌ 连接失败: $e';
                                    testing = false;
                                  });
                                }
                              },
                        icon: testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(testing ? '测试中...' : '测试连接'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                    if (apiKey.isEmpty) return;

                    final modelName = selectedModel == '__custom__'
                        ? customModelController.text.trim()
                        : selectedModel;
                    if (modelName.isEmpty) return;

                    if (baseUrl.isNotEmpty) {
                      await userProvider.updateBaseUrl(baseUrl);
                    }
                    await userProvider.updateApiKey(apiKey);
                    await userProvider.updateModelName(modelName);

                    final aiProvider = context.read<AiProvider>();
                    aiProvider.initApi(
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
}

class _TypingDot extends StatefulWidget {
  final double delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final offset = (value * 2 - 1).abs();
        return Transform.translate(
          offset: Offset(0, -offset * 6),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(
                0.4 + offset * 0.6,
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
