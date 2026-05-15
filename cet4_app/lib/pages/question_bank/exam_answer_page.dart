import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/question.dart';
import 'year_paper_page.dart';
import 'exam_result_page.dart';

class ExamAnswerPage extends StatefulWidget {
  final ExamPaperInfo paperInfo;
  final ExamMode mode;

  const ExamAnswerPage({
    super.key,
    required this.paperInfo,
    required this.mode,
  });

  @override
  State<ExamAnswerPage> createState() => _ExamAnswerPageState();
}

class _ExamAnswerPageState extends State<ExamAnswerPage> {
  final DbHelper _dbHelper = DbHelper();
  final Map<int, String> _answers = {};
  final Map<int, bool> _showExplanation = {};
  final Map<int, TextEditingController> _writingControllers = {};
  bool _showAllAnswers = false;
  List<Question> _questions = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  // 计时相关
  late DateTime _startTime;
  Timer? _timer;
  int _elapsedSeconds = 0;
  static const int _examTotalSeconds = 125 * 60; // 125分钟

  bool get isExamMode => widget.mode == ExamMode.exam;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _loadQuestions();
    if (isExamMode) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;
        if (_elapsedSeconds >= _examTotalSeconds) {
          _timer?.cancel();
          _autoSubmit();
        }
      });
    });
  }

  void _autoSubmit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('时间到'),
        content: Text('考试时间已到，系统将自动交卷。\n已完成 ${_answers.length} 道题目。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            child: const Text('确认交卷'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!isExamMode) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出考试'),
        content: Text('确定要退出吗？已完成 ${_answers.length} 题将被提交。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续考试')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('提交并退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (result == true) {
      _timer?.cancel();
      _submitExam();
    }
    return false;
  }

  void _submitExam() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExamResultPage(
          paperName: widget.paperInfo.name,
          answers: Map.from(_answers),
          totalQuestions: _questions.length,
          durationSeconds: _elapsedSeconds,
          mode: widget.mode == ExamMode.exam ? 'exam' : 'practice',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _writingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getWritingController(int questionId) {
    return _writingControllers.putIfAbsent(questionId, () => TextEditingController());
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      // 从 questions 表加载
      final allIds = <int>[];
      for (final list in widget.paperInfo.questions.values) {
        allIds.addAll(list);
      }

      final allQuestions = await _dbHelper.query('questions');
      _questions = allQuestions
          .where((q) => allIds.contains(q['id'] as int))
          .map((q) => Question.fromDbMap(q))
          .toList();

      // 按 ID 排序保持题目顺序
      _questions.sort((a, b) {
        final aIdx = allIds.indexOf(a.id);
        final bIdx = allIds.indexOf(b.id);
        return aIdx.compareTo(bIdx);
      });
    } catch (_) {
      _questions = [];
    }
    setState(() => _isLoading = false);
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      setState(() => _currentIndex = index);
    }
  }

  void _showAnswer() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentIndex];
    setState(() {
      _showExplanation[q.id] = true;
    });
  }

  void _submitAnswer(String letter) {
    final q = _questions[_currentIndex];
    setState(() {
      _answers[q.id] = letter;
      _showExplanation[q.id] = true;
      // 自动跳下一题
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExam = isExamMode;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.paperInfo.name, style: const TextStyle(fontSize: 14)),
        centerTitle: true,
        actions: [
          if (isExam) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _elapsedSeconds > _examTotalSeconds - 300 ? Colors.red[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatTime(_examTotalSeconds - _elapsedSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _elapsedSeconds > _examTotalSeconds - 300 ? Colors.red : Colors.orange[800],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _onWillPop,
              child: const Text('交卷', style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ] else ...[
            TextButton(
              onPressed: () => setState(() => _showAllAnswers = !_showAllAnswers),
              child: Text(_showAllAnswers ? '隐藏答案' : '全部答案', style: const TextStyle(fontSize: 13)),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: _showAnswerCard,
            tooltip: '答题卡',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(child: Text('暂无题目数据'))
              : Column(
                  children: [
                    _buildProgressBar(),
                    Expanded(child: _buildQuestionView()),
                    _buildBottomNav(),
                  ],
                ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '已答 ${_answers.length} 题',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _questions.isEmpty ? 0 : (_currentIndex + 1) / _questions.length,
            backgroundColor: Colors.grey[200],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView() {
    if (_questions.isEmpty) return const SizedBox.shrink();
    final q = _questions[_currentIndex];
    final selectedAnswer = _answers[q.id];
    final showExp = _showExplanation[q.id] == true || _showAllAnswers;
    final hasOptions = q.options != null && q.options!.isNotEmpty;
    final isExam = isExamMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题型标签
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor(q.type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(q.type, style: TextStyle(color: _typeColor(q.type), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              if (q.year.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('${q.year}年', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_border, size: 20),
                onPressed: () {},
                tooltip: '标记',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 题干
          if (q.passage != null && q.passage!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(q.passage!, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[700])),
            ),
          Text(
            '${_currentIndex + 1}. ${q.content}',
            style: const TextStyle(fontSize: 16, height: 1.7),
          ),
          const SizedBox(height: 16),
          // 选项
          if (hasOptions && !isExam)
            ...List.generate(q.options!.length, (i) {
              final letter = String.fromCharCode(65 + i);
              final isSelected = selectedAnswer == letter;
              final isCorrect = showExp && letter == q.answer;
              final isWrong = isSelected && showExp && letter != q.answer;

              return GestureDetector(
                onTap: () => _submitAnswer(letter),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green[50]
                        : isWrong
                            ? Colors.red[50]
                            : isSelected
                                ? Colors.blue[50]
                                : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green
                          : isWrong
                              ? Colors.red
                              : isSelected
                                  ? Colors.blue
                                  : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? (isCorrect ? Colors.green : Colors.blue) : Colors.grey[200],
                        ),
                        child: Center(
                          child: Text(letter, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(q.options![i], style: const TextStyle(fontSize: 15))),
                      if (isCorrect) const Icon(Icons.check, color: Colors.green, size: 18),
                      if (isWrong) const Icon(Icons.close, color: Colors.red, size: 18),
                    ],
                  ),
                ),
              );
            }),
          if (hasOptions && isExam)
            ...List.generate(q.options!.length, (i) {
              final letter = String.fromCharCode(65 + i);
              final isSelected = selectedAnswer == letter;
              return GestureDetector(
                onTap: () {
                  setState(() => _answers[q.id] = letter);
                  if (_currentIndex < _questions.length - 1) {
                    Future.delayed(const Duration(milliseconds: 200), () {
                      setState(() => _currentIndex++);
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.blue : Colors.grey[200],
                        ),
                        child: Center(child: Text(letter, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(q.options![i], style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                ),
              );
            }),
          // 写作/翻译
          if (!hasOptions)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              child: TextField(
                enabled: true,
                maxLines: null,
                minLines: q.type == '写作' ? 10 : 6,
                controller: _getWritingController(q.id),
                decoration: InputDecoration(
                  hintText: q.type == '写作' ? '请在此输入你的作文（120-180词）...' : '请在此输入你的翻译...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(14),
                ),
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
          // 答案解析
          if (showExp && !isExam) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text('正确答案：${q.answer}', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (q.explanation.isNotEmpty && q.explanation != q.answer) ...[
                    const SizedBox(height: 8),
                    Text(q.explanation, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
          if (!showExp && hasOptions && !isExam) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAnswer,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('查看答案'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, -1))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
                child: const Text('上一题'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _currentIndex < _questions.length - 1 ? () => _goToQuestion(_currentIndex + 1) : null,
                child: const Text('下一题'),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1.1,
                  ),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final answered = _answers.containsKey(q.id);
                    final isCurrent = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _goToQuestion(index);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.blue[100]
                              : answered
                                  ? Colors.blue[50]
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isCurrent ? Colors.blue : Colors.grey[300]!,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
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

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _typeColor(String type) {
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
}
