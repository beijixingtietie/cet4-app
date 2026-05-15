import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/db_helper.dart';
import '../../models/question.dart';
import '../../provider/ai_provider.dart';

class WrongQuestionsPage extends StatefulWidget {
  const WrongQuestionsPage({super.key});

  @override
  State<WrongQuestionsPage> createState() => _WrongQuestionsPageState();
}

class _WrongQuestionsPageState extends State<WrongQuestionsPage> {
  final DbHelper _dbHelper = DbHelper();
  final Map<String, List<_WrongQuestionEntry>> _sections = {};
  List<_WrongQuestionEntry> _allEntries = [];
  bool _isLoading = true;
  int? _reAnswerId;
  Map<int, String> _userAnswers = {};
  Map<int, bool> _reAnswerResult = {};
  bool _showAllAnswers = false;

  @override
  void initState() {
    super.initState();
    _loadWrongQuestions();
  }

  Future<void> _loadWrongQuestions() async {
    setState(() => _isLoading = true);
    try {
      final wqRows = await _dbHelper.query(
        'wrong_questions',
        where: 'user_id = ?',
        whereArgs: [1],
        orderBy: 'add_time DESC',
      );

      if (wqRows.isEmpty) {
        _allEntries = [];
        _sections.clear();
        setState(() => _isLoading = false);
        return;
      }

      final questionIds = wqRows.map((r) => r['question_id'] as int).toSet();
      final allQuestions = await _dbHelper.query('questions');
      final qMap = <int, Map<String, dynamic>>{};
      for (final q in allQuestions) {
        qMap[q['id'] as int] = q;
      }

      _allEntries = wqRows.map((wq) {
        final q = qMap[wq['question_id']];
        final merged = <String, dynamic>{};
        if (q != null) merged.addAll(q);
        merged['wq_id'] = wq['id'];
        merged['wrong_answer'] = wq['user_answer'] ?? '';
        merged['add_time'] = wq['add_time'] ?? '';
        return _WrongQuestionEntry(
          wqId: wq['id'] as int? ?? 0,
          questionId: wq['question_id'] as int,
          question: q != null ? Question.fromDbMap(q) : _fallbackQuestion(wq),
          wrongAnswer: (wq['user_answer'] as String?) ?? '',
          addTime: (wq['add_time'] as String?) ?? '',
        );
      }).toList();

      _groupByType();
    } catch (e) {
      _allEntries = [];
      _sections.clear();
    }
    setState(() => _isLoading = false);
  }

  Question _fallbackQuestion(Map<String, dynamic> wq) {
    return Question(
      id: wq['question_id'] as int,
      type: '未知',
      year: '',
      content: '题目数据丢失',
      answer: '',
      explanation: '',
    );
  }

  void _groupByType() {
    _sections.clear();
    for (final entry in _allEntries) {
      _sections.putIfAbsent(entry.question.type, () => []).add(entry);
    }
  }

  Future<void> _deleteEntry(_WrongQuestionEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出错题本'),
        content: const Text('确定要移除这道错题吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dbHelper.delete(
        'wrong_questions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [entry.wqId, 1],
      );
      setState(() {
        _allEntries.removeWhere((e) => e.wqId == entry.wqId);
        _groupByType();
        if (_reAnswerId == entry.questionId) {
          _reAnswerId = null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从错题本移除')),
        );
      }
    } catch (_) {}
  }

  void _enterReAnswer(_WrongQuestionEntry entry) {
    setState(() {
      _reAnswerId = entry.questionId;
      _userAnswers.remove(entry.questionId);
      _reAnswerResult.remove(entry.questionId);
    });
  }

  void _exitReAnswer() {
    setState(() {
      _reAnswerId = null;
      _userAnswers = {};
      _reAnswerResult = {};
    });
  }

  void _submitAnswer(_WrongQuestionEntry entry, String userPick) {
    final correct = entry.question.answer;
    final isCorrect = userPick == correct;
    setState(() {
      _userAnswers[entry.questionId] = userPick;
      _reAnswerResult[entry.questionId] = isCorrect;
    });
    if (isCorrect) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('回答正确！'),
          content: const Text('是否从错题本中移除这道题？'),
          actions: [
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              _exitReAnswer();
            }, child: const Text('保留')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteEntry(entry);
                _exitReAnswer();
              },
              child: const Text('移除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  void _showAiExplanation(_WrongQuestionEntry entry) {
    final aiProvider = context.read<AiProvider>();
    if (!aiProvider.isApiConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置API密钥')),
      );
      return;
    }

    String? result;
    bool loading = true;
    String? error;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (loading && result == null && error == null) {
              aiProvider.explainQuestion(entry.question.content, entry.question.answer).then((data) {
                setState(() { result = data; loading = false; });
              }).catchError((e) {
                setState(() { error = e.toString(); loading = false; });
              });
            }

            return AlertDialog(
              title: const Text('AI深度解析'),
              content: loading
                  ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                  : error != null
                      ? Text('错误: $error')
                      : SingleChildScrollView(child: Text(result ?? '')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
              ],
            );
          },
        );
      },
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '听力': return Colors.blue;
      case '选词填空': return Colors.green;
      case '长篇阅读': return Colors.orange;
      case '仔细阅读': return Colors.purple;
      case '翻译': return Colors.red;
      case '写作': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        centerTitle: true,
        actions: [
          if (_allEntries.isNotEmpty) ...[
            IconButton(
              icon: Icon(_showAllAnswers ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showAllAnswers = !_showAllAnswers),
              tooltip: _showAllAnswers ? '隐藏答案' : '显示全部答案',
            ),
            IconButton(
              icon: const Icon(Icons.dashboard),
              onPressed: _showAnswerCard,
              tooltip: '答题卡',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allEntries.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildStatsBar(),
                    Expanded(child: _buildSectionList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('错题本为空', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('做错的题目会自动收录到这里', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[50],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.grey[700],
                  radius: 12,
                  child: Text('${_allEntries.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
                label: const Text('全部', style: TextStyle(fontSize: 12)),
              ),
            ),
            ..._sections.entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: _getTypeColor(e.key),
                  radius: 12,
                  child: Text('${e.value.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
                label: Text(e.key, style: const TextStyle(fontSize: 12)),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionList() {
    if (_sections.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final type = _sections.keys.elementAt(index);
        final entries = _sections[type]!;
        return _buildSectionGroup(type, entries);
      },
    );
  }

  Widget _buildSectionGroup(String type, List<_WrongQuestionEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _getTypeColor(type).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: _getTypeColor(type), width: 3)),
          ),
          child: Row(
            children: [
              Text(type, style: TextStyle(fontWeight: FontWeight.bold, color: _getTypeColor(type))),
              const SizedBox(width: 8),
              Text('${entries.length}题', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        ...entries.map((e) => _buildQuestionCard(e)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildQuestionCard(_WrongQuestionEntry entry) {
    final isReAnswering = _reAnswerId == entry.questionId;
    final userAnswer = _userAnswers[entry.questionId];
    final reResult = _reAnswerResult[entry.questionId];
    final showExplanation = isReAnswering
        ? reResult != null
        : _showAllAnswers || _reAnswerResult.containsKey(entry.questionId);
    final q = entry.question;
    final hasOptions = q.options != null && q.options!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!isReAnswering && !_showAllAnswers) {
          _enterReAnswer(entry);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isReAnswering ? Colors.orange.shade400 : Colors.grey.shade300,
            width: isReAnswering ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getTypeColor(q.type),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(q.type, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Text(q.year, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                // 重做模式下显示提示
                if (isReAnswering)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('重做中', style: TextStyle(fontSize: 11, color: Colors.orange[700])),
                  ),
                if (!isReAnswering) ...[
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                    onPressed: () => _showAiExplanation(entry),
                    tooltip: 'AI解析',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    onPressed: () => _deleteEntry(entry),
                    tooltip: '移除',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // 题干
            Text(
              q.content,
              style: const TextStyle(fontSize: 14),
              maxLines: isReAnswering ? 10 : 2,
              overflow: isReAnswering ? null : TextOverflow.ellipsis,
            ),
            // 选项（仅在重做模式下显示为可点击，或全部答案模式）
            if (hasOptions && (isReAnswering || _showAllAnswers)) ...[
              const SizedBox(height: 8),
              if (isReAnswering && reResult == null)
                ...List.generate(q.options!.length, (i) {
                  final letter = String.fromCharCode(65 + i);
                  return GestureDetector(
                    onTap: () => _submitAnswer(entry, letter),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text('$letter. ${q.options![i]}', style: const TextStyle(fontSize: 13)),
                    ),
                  );
                }),
              // 重做结果或全部答案
              if (reResult != null || _showAllAnswers)
                ...List.generate(q.options!.length, (i) {
                  final letter = String.fromCharCode(65 + i);
                  final isCorrect = letter == q.answer;
                  final isUserPick = letter == userAnswer;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green[50] : (isUserPick && !isCorrect ? Colors.red[50] : null),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isCorrect ? Colors.green : (isUserPick && !isCorrect ? Colors.red : Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$letter. ${q.options![i]}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isCorrect ? Colors.green[800] : (isUserPick && !isCorrect ? Colors.red[800] : null),
                              fontWeight: isCorrect ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                        if (isCorrect) const Icon(Icons.check, color: Colors.green, size: 16),
                        if (isUserPick && !isCorrect) const Icon(Icons.close, color: Colors.red, size: 16),
                      ],
                    ),
                  );
                }),
            ],
            // 答案和解析
            if (showExplanation) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: reResult == false ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '正确答案: ${q.answer}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (entry.wrongAnswer.isNotEmpty)
                      Text(
                        '上次作答: ${entry.wrongAnswer}',
                        style: TextStyle(fontSize: 12, color: Colors.red[600]),
                      ),
                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(q.explanation, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ],
                ),
              ),
            ],
            // 退出重做按钮
            if (isReAnswering)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: _exitReAnswer,
                  child: const Text('退出重做'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAnswerCard() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('答题卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _allEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _allEntries[index];
                    final isActive = _reAnswerId == entry.questionId;
                    final isReanswered = _reAnswerResult.containsKey(entry.questionId);
                    final reCorrect = _reAnswerResult[entry.questionId] == true;

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _reAnswerId = entry.questionId;
                          _userAnswers = {};
                          _reAnswerResult = {};
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.orange[100]
                              : isReanswered
                                  ? (reCorrect ? Colors.green[100] : Colors.red[100])
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isActive
                                ? Colors.orange
                                : isReanswered
                                    ? (reCorrect ? Colors.green : Colors.red)
                                    : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.orange[900] : Colors.grey[700],
                              ),
                            ),
                            Text(
                              entry.question.type.substring(0, 2),
                              style: TextStyle(fontSize: 9, color: _getTypeColor(entry.question.type)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WrongQuestionEntry {
  final int wqId;
  final int questionId;
  final Question question;
  final String wrongAnswer;
  final String addTime;

  _WrongQuestionEntry({
    required this.wqId,
    required this.questionId,
    required this.question,
    required this.wrongAnswer,
    required this.addTime,
  });
}
