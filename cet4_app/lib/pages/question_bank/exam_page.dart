import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../database/db_helper.dart';

/// 考试流程状态
enum _ExamFlowState { start, running, paused, finished }

/// 四级考试部分
enum _ExamPart { writing, listening, reading, translation }

/// 真实四级考试试卷页面（全真模拟模式）
class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> with WidgetsBindingObserver {
  final DbHelper _dbHelper = DbHelper();
  final Map<int, String> _answers = {};
  final Map<int, bool> _markedQuestions = {};
  final Map<int, TextEditingController> _writingControllers = {};
  final PageController _pageController = PageController();

  // 考试状态
  _ExamFlowState _flowState = _ExamFlowState.start;
  int _currentIndex = 0;
  bool _isLoading = true;

  // 倒计时相关
  static const int _totalSeconds = 125 * 60; // 125分钟
  int _remainingSeconds = _totalSeconds;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _isPaused = false;

  // 题目数据
  List<_ExamSection> _sections = [];
  List<_ExamQuestion> _allQuestions = [];
  String _examYear = '';

  // 各部分时间限制（秒）
  static const Map<_ExamPart, int> _partTimeLimits = {
    _ExamPart.writing: 30 * 60,
    _ExamPart.listening: 25 * 60,
    _ExamPart.reading: 40 * 60,
    _ExamPart.translation: 30 * 60,
  };

  // 各部分分数权重（四级710分制）
  static const Map<_ExamPart, int> _partScores = {
    _ExamPart.writing: 106,
    _ExamPart.listening: 248,
    _ExamPart.reading: 248,
    _ExamPart.translation: 106,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    for (final c in _writingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台自动暂停考试
    if (_flowState == _ExamFlowState.running) {
      if (state == AppLifecycleState.paused) {
        _pauseExam();
      }
    }
  }

  // ==================== 数据加载 ====================

  Future<void> _loadExam() async {
    setState(() => _isLoading = true);

    List<Question> questions;
    try {
      final dbData = await _dbHelper.query('questions');
      if (dbData.isNotEmpty) {
        questions = dbData.map((m) => Question.fromDbMap(m)).toList();
      } else {
        questions = _buildTestData();
      }
    } catch (_) {
      questions = _buildTestData();
    }

    _buildExamStructure(questions);
    setState(() => _isLoading = false);
  }

  void _buildExamStructure(List<Question> questions) {
    final sections = <_ExamSection>[];
    _allQuestions = [];
    int globalIndex = 1;

    // Part I: Writing (30min)
    final writingQs = questions.where((q) => q.type == '写作').toList();
    if (writingQs.isNotEmpty) {
      sections.add(_ExamSection(
        part: _ExamPart.writing,
        partNo: 'I',
        title: 'Writing',
        time: '30 minutes',
        directions: 'Directions: For this part, you are allowed 30 minutes to write a short essay '
            'on the following topic. You should write at least 120 words but no more than 180 words.',
        subSections: [
          _ExamSubSection(
            questions: writingQs.map((q) => _examQ(q, globalIndex++)).toList(),
          ),
        ],
      ));
    }

    // Part II: Listening Comprehension (25min)
    final listeningQs = questions.where((q) => q.type == '听力').toList();
    if (listeningQs.isNotEmpty) {
      final third = (listeningQs.length / 3).ceil();
      sections.add(_ExamSection(
        part: _ExamPart.listening,
        partNo: 'II',
        title: 'Listening Comprehension',
        time: '25 minutes',
        directions: '',
        subSections: [
          _ExamSubSection(
            title: 'Section A',
            subTitle: 'News Reports',
            directions: 'Directions: In this section, you will hear three news reports. '
                'At the end of each news report, you will hear two or three questions. '
                'Both the news report and the questions will be spoken only once.',
            questions: listeningQs.take(third).map((q) => _examQ(q, globalIndex++)).toList(),
          ),
          _ExamSubSection(
            title: 'Section B',
            subTitle: 'Long Conversations',
            directions: 'Directions: In this section, you will hear two long conversations. '
                'At the end of each conversation, you will hear four questions.',
            questions: listeningQs.skip(third).take(third).map((q) => _examQ(q, globalIndex++)).toList(),
          ),
          _ExamSubSection(
            title: 'Section C',
            subTitle: 'Passages',
            directions: 'Directions: In this section, you will hear three passages. '
                'At the end of each passage, you will hear some questions.',
            questions: listeningQs.skip(third * 2).map((q) => _examQ(q, globalIndex++)).toList(),
          ),
        ],
      ));
    }

    // Part III: Reading Comprehension (40min)
    final readingQs = questions.where((q) => q.type == '仔细阅读' || q.type == '选词填空' || q.type == '长篇阅读').toList();
    if (readingQs.isNotEmpty) {
      sections.add(_ExamSection(
        part: _ExamPart.reading,
        partNo: 'III',
        title: 'Reading Comprehension',
        time: '40 minutes',
        directions: '',
        subSections: [
          _ExamSubSection(
            title: 'Section A',
            subTitle: 'Banked Cloze',
            directions: 'Directions: In this section, there is a passage with ten blanks. '
                'You are required to select one word for each blank from a list of choices given in a word bank.',
            questions: readingQs.where((q) => q.type == '选词填空').map((q) => _examQ(q, globalIndex++)).toList(),
          ),
          _ExamSubSection(
            title: 'Section B',
            subTitle: 'Long Reading',
            directions: 'Directions: In this section, you are going to read a passage with ten statements attached to it. '
                'Each statement contains information given in one of the paragraphs. '
                'Identify the paragraph from which the information is derived.',
            questions: readingQs.where((q) => q.type == '长篇阅读').map((q) => _examQ(q, globalIndex++)).toList(),
          ),
          _ExamSubSection(
            title: 'Section C',
            subTitle: 'Close Reading',
            directions: 'Directions: There are 2 passages in this section. Each passage is followed by some questions. '
                'For each of them there are four choices marked A, B, C, and D. '
                'You should decide on the best choice.',
            questions: readingQs.where((q) => q.type == '仔细阅读').map((q) => _examQ(q, globalIndex++)).toList(),
          ),
        ],
      ));
    }

    // Part IV: Translation (30min)
    final transQs = questions.where((q) => q.type == '翻译').toList();
    if (transQs.isNotEmpty) {
      sections.add(_ExamSection(
        part: _ExamPart.translation,
        partNo: 'IV',
        title: 'Translation',
        time: '30 minutes',
        directions: 'Directions: For this part, you are allowed 30 minutes to translate a passage from Chinese into English.',
        subSections: [
          _ExamSubSection(
            questions: transQs.map((q) => _examQ(q, globalIndex++)).toList(),
          ),
        ],
      ));
    }

    // 如果没有题目，使用测试数据
    if (sections.isEmpty) {
      final testQs = _buildTestData();
      _buildExamStructure(testQs);
      return;
    }

    _sections = sections;
    _allQuestions = sections.expand((s) => s.subSections.expand((ss) => ss.questions)).toList();

    // 提取年份
    final yearCounts = <String, int>{};
    for (final q in questions) {
      if (q.year.isNotEmpty) {
        yearCounts[q.year] = (yearCounts[q.year] ?? 0) + 1;
      }
    }
    if (yearCounts.isNotEmpty) {
      _examYear = yearCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
  }

  _ExamQuestion _examQ(Question q, int num) {
    return _ExamQuestion(
      globalNum: num,
      questionId: q.id,
      content: q.content,
      passage: q.passage,
      options: q.options,
      answer: q.answer,
      explanation: q.explanation,
      type: q.type,
      part: _getPartForType(q.type),
    );
  }

  _ExamPart _getPartForType(String type) {
    switch (type) {
      case '写作':
        return _ExamPart.writing;
      case '听力':
        return _ExamPart.listening;
      case '选词填空':
      case '长篇阅读':
      case '仔细阅读':
        return _ExamPart.reading;
      case '翻译':
        return _ExamPart.translation;
      default:
        return _ExamPart.reading;
    }
  }

  // ==================== 考试控制 ====================

  void _startExam() {
    setState(() {
      _flowState = _ExamFlowState.running;
      _remainingSeconds = _totalSeconds;
      _elapsedSeconds = 0;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() {
        _elapsedSeconds++;
        _remainingSeconds = _totalSeconds - _elapsedSeconds;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _timer?.cancel();
          _autoSubmit();
        }
      });
    });
  }

  void _pauseExam() {
    if (_flowState != _ExamFlowState.running) return;
    setState(() {
      _isPaused = true;
      _flowState = _ExamFlowState.paused;
    });
    _timer?.cancel();
  }

  void _resumeExam() {
    if (_flowState != _ExamFlowState.paused) return;
    setState(() {
      _isPaused = false;
      _flowState = _ExamFlowState.running;
    });
    _startTimer();
  }

  void _autoSubmit() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text('考试时间到'),
          ],
        ),
        content: Text(
          '125分钟考试时间已结束，系统将自动交卷。\n\n'
          '已完成 ${_answers.length} / ${_allQuestions.length} 道题目。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finishExam();
            },
            child: const Text('查看成绩'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.assignment_turned_in, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            const Text('确认交卷'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您确定要交卷吗？'),
            const SizedBox(height: 12),
            _buildConfirmStat('已答题目', '${_answers.length} / ${_allQuestions.length}'),
            _buildConfirmStat('未答题目', '${_allQuestions.length - _answers.length}'),
            _buildConfirmStat('标记题目', '${_markedQuestions.values.where((v) => v).length}'),
            _buildConfirmStat('剩余时间', _formatTime(_remainingSeconds)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续考试'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('确认交卷'),
          ),
        ],
      ),
    );

    if (result == true) {
      _finishExam();
    }
  }

  Widget _buildConfirmStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _finishExam() {
    _timer?.cancel();
    setState(() => _flowState = _ExamFlowState.finished);
  }

  // ==================== 答题操作 ====================

  void _selectAnswer(String letter) {
    if (_currentIndex >= _allQuestions.length) return;
    final q = _allQuestions[_currentIndex];
    setState(() {
      _answers[q.globalNum] = letter;
    });
  }

  void _toggleMark() {
    if (_currentIndex >= _allQuestions.length) return;
    final q = _allQuestions[_currentIndex];
    setState(() {
      _markedQuestions[q.globalNum] = !(_markedQuestions[q.globalNum] ?? false);
    });
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _allQuestions.length) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goToNext() {
    if (_currentIndex < _allQuestions.length - 1) {
      _goToQuestion(_currentIndex + 1);
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _goToQuestion(_currentIndex - 1);
    }
  }

  TextEditingController _getWritingController(int globalNum) {
    return _writingControllers.putIfAbsent(globalNum, () => TextEditingController());
  }

  // ==================== 成绩计算 ====================

  Map<String, dynamic> _calculateScore() {
    final partCorrect = <_ExamPart, int>{};
    final partTotal = <_ExamPart, int>{};

    for (final q in _allQuestions) {
      partTotal[q.part] = (partTotal[q.part] ?? 0) + 1;
      final userAnswer = _answers[q.globalNum];
      if (userAnswer != null && userAnswer.toUpperCase() == q.answer.toUpperCase()) {
        partCorrect[q.part] = (partCorrect[q.part] ?? 0) + 1;
      }
    }

    // 计算各部分得分（按正确率分配满分）
    final partScores = <_ExamPart, int>{};
    int totalScore = 0;
    for (final part in _ExamPart.values) {
      final total = partTotal[part] ?? 0;
      final correct = partCorrect[part] ?? 0;
      final maxScore = _partScores[part] ?? 0;
      final score = total > 0 ? (correct / total * maxScore).round() : 0;
      partScores[part] = score;
      totalScore += score;
    }

    return {
      'totalScore': totalScore,
      'partScores': partScores,
      'partCorrect': partCorrect,
      'partTotal': partTotal,
      'elapsedSeconds': _elapsedSeconds,
    };
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    switch (_flowState) {
      case _ExamFlowState.start:
        return _buildStartPage(isDark, bgColor);
      case _ExamFlowState.running:
      case _ExamFlowState.paused:
        return _buildExamPage(isDark, bgColor);
      case _ExamFlowState.finished:
        return _buildResultPage(isDark, bgColor);
    }
  }

  // ---------- 开始页 ----------

  Widget _buildStartPage(bool isDark, Color bgColor) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white60 : Colors.grey[600];
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildExamHeader(isDark),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 考试说明卡片
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '考试说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.timer_outlined, '考试时长', '125 分钟'),
                        _buildInfoRow(Icons.format_list_numbered, '题目总数', '${_allQuestions.length} 题'),
                        _buildInfoRow(Icons.score_outlined, '满分', '710 分'),
                        _buildInfoRow(Icons.rule_folder_outlined, '及格线', '425 分'),
                        const Divider(height: 32),
                        Text(
                          '考试流程',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFlowStep('1', '写作', '30 分钟', const Color(0xFF4F46E5)),
                        _buildFlowStep('2', '听力理解', '25 分钟', const Color(0xFF14B8A6)),
                        _buildFlowStep('3', '阅读理解', '40 分钟', const Color(0xFFF97316)),
                        _buildFlowStep('4', '翻译', '30 分钟', const Color(0xFF8B5CF6)),
                        const Divider(height: 32),
                        Text(
                          '注意事项',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNoticeItem('考试开始后倒计时自动运行，不可重置'),
                        _buildNoticeItem('可暂停考试，暂停时倒计时停止'),
                        _buildNoticeItem('切换至其他应用自动暂停考试'),
                        _buildNoticeItem('时间到系统将自动交卷'),
                        _buildNoticeItem('交卷后可查看成绩与错题回顾'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startExam,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('开始考试', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('返回', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamHeader(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 28,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '全真模拟考试',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _examYear.isNotEmpty ? '$_examYear年 大学英语四级考试' : '大学英语四级考试',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.85),
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep(String number, String title, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 考试页面 ----------

  Widget _buildExamPage(bool isDark, Color bgColor) {
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final isWarning = _remainingSeconds <= 300; // 最后5分钟警告

    return WillPopScope(
      onWillPop: () async {
        _pauseExam();
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('退出考试'),
            content: const Text('退出后考试进度将丢失，确定要退出吗？'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  _resumeExam();
                },
                child: const Text('继续考试'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('退出', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (result == true) {
          _timer?.cancel();
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Column(
            children: [
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isWarning ? Colors.red : const Color(0xFF4F46E5),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '剩余时间',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            // 暂停/继续按钮
            IconButton(
              icon: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: const Color(0xFF4F46E5),
              ),
              onPressed: _isPaused ? _resumeExam : _pauseExam,
              tooltip: _isPaused ? '继续考试' : '暂停考试',
            ),
            // 答题卡
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, color: Color(0xFF4F46E5)),
              onPressed: _showAnswerCard,
              tooltip: '答题卡',
            ),
            // 交卷
            TextButton(
              onPressed: _confirmSubmit,
              child: Text(
                '交卷',
                style: TextStyle(
                  color: isWarning ? Colors.red : const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isPaused ? _buildPausedOverlay(cardColor, textPrimary) : _buildQuestionContent(cardColor, textPrimary),
        bottomNavigationBar: _isPaused ? null : _buildExamBottomBar(),
      ),
    );
  }

  Widget _buildPausedOverlay(Color cardColor, Color textPrimary) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_filled,
              size: 64,
              color: const Color(0xFF4F46E5).withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              '考试已暂停',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '倒计时已停止，点击继续恢复考试',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resumeExam,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('继续考试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent(Color cardColor, Color textPrimary) {
    return Column(
      children: [
        // 进度条
        _buildProgressIndicator(),
        // 题目内容
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allQuestions.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildQuestionCard(_allQuestions[index], cardColor, textPrimary),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.transparent,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_allQuestions.length}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '已答 ${_answers.length} 题',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _allQuestions.isEmpty ? 0 : (_currentIndex + 1) / _allQuestions.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_ExamQuestion q, Color cardColor, Color textPrimary) {
    final selectedAnswer = _answers[q.globalNum];
    final hasOptions = q.options != null && q.options!.isNotEmpty;
    final isMarked = _markedQuestions[q.globalNum] ?? false;
    final currentPart = _getCurrentPart();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题型标签栏
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _partColor(q.part).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _partLabel(q.part),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _partColor(q.part),
                  ),
                ),
              ),
              if (currentPart != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Part ${currentPart.partNo}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
              const Spacer(),
              // 标记按钮
              GestureDetector(
                onTap: _toggleMark,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMarked ? Colors.orange.withOpacity(0.12) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 14,
                        color: isMarked ? Colors.orange : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMarked ? '已标记' : '标记',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMarked ? Colors.orange : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 题干
          if (q.passage != null && q.passage!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                q.passage!,
                style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey[700]),
              ),
            ),
          Text(
            '${q.globalNum}. ${q.content}',
            style: TextStyle(fontSize: 16, height: 1.7, color: textPrimary),
          ),
          const SizedBox(height: 20),
          // 选项
          if (hasOptions)
            ...List.generate(q.options!.length, (i) {
              final letter = String.fromCharCode(65 + i);
              final isSelected = selectedAnswer == letter;
              return GestureDetector(
                onTap: () => _selectAnswer(letter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[200],
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q.options![i],
                          style: TextStyle(
                            fontSize: 15,
                            color: textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          // 写作/翻译输入框
          if (!hasOptions)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: TextField(
                maxLines: null,
                minLines: q.type == '写作' ? 12 : 8,
                controller: _getWritingController(q.globalNum),
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    _answers[q.globalNum] = value;
                  } else {
                    _answers.remove(q.globalNum);
                  }
                },
                decoration: InputDecoration(
                  hintText: q.type == '写作'
                      ? '请在此输入你的作文（120-180词）...'
                      : '请在此输入你的翻译...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(fontSize: 15, height: 1.7, color: textPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExamBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _currentIndex > 0 ? _goToPrevious : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('上一题'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _currentIndex < _allQuestions.length - 1 ? _goToNext : _confirmSubmit,
                icon: Icon(
                  _currentIndex < _allQuestions.length - 1 ? Icons.arrow_forward_rounded : Icons.assignment_turned_in,
                  size: 18,
                ),
                label: Text(_currentIndex < _allQuestions.length - 1 ? '下一题' : '交卷'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 答题卡 ----------

  void _showAnswerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '答题卡',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 图例
              Row(
                children: [
                  _buildLegend(const Color(0xFF4F46E5), '已答'),
                  const SizedBox(width: 20),
                  _buildLegend(Colors.orange, '标记'),
                  const SizedBox(width: 20),
                  _buildLegend(Colors.grey[300]!, '未答'),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // 按部分分组显示
              Expanded(
                child: ListView.builder(
                  itemCount: _sections.length,
                  itemBuilder: (context, sectionIndex) {
                    final section = _sections[sectionIndex];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Part ${section.partNo}  ${section.title}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _partColor(section.part),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: section.subSections.expand((ss) => ss.questions).map((q) {
                            final answered = _answers.containsKey(q.globalNum);
                            final marked = _markedQuestions[q.globalNum] ?? false;
                            final isCurrent = q.globalNum - 1 == _currentIndex;
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _goToQuestion(q.globalNum - 1);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: answered
                                      ? const Color(0xFF4F46E5).withOpacity(0.15)
                                      : marked
                                          ? Colors.orange.withOpacity(0.15)
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFF4F46E5)
                                        : answered
                                            ? const Color(0xFF4F46E5)
                                            : marked
                                                ? Colors.orange
                                                : Colors.grey[300]!,
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${q.globalNum}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                      color: answered
                                          ? const Color(0xFF4F46E5)
                                          : marked
                                              ? Colors.orange
                                              : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmSubmit();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('确认交卷', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // ---------- 成绩报告页 ----------

  Widget _buildResultPage(bool isDark, Color bgColor) {
    final result = _calculateScore();
    final totalScore = result['totalScore'] as int;
    final partScores = result['partScores'] as Map<_ExamPart, int>;
    final partCorrect = result['partCorrect'] as Map<_ExamPart, int>;
    final partTotal = result['partTotal'] as Map<_ExamPart, int>;
    final elapsed = result['elapsedSeconds'] as int;
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);

    final isPass = totalScore >= 425;
    final mins = elapsed ~/ 60;
    final secs = elapsed % 60;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildResultHeader(totalScore, isPass, mins, secs),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 各部分得分
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '各部分得分',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._ExamPart.values.map((part) {
                        final score = partScores[part] ?? 0;
                        final correct = partCorrect[part] ?? 0;
                        final total = partTotal[part] ?? 0;
                        final maxScore = _partScores[part] ?? 0;
                        return _buildPartScoreItem(
                          part,
                          score,
                          maxScore,
                          correct,
                          total,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 统计信息
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '考试统计',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('总题数', '${_allQuestions.length}'),
                      _buildStatRow('已答题数', '${_answers.length}'),
                      _buildStatRow('未答题数', '${_allQuestions.length - _answers.length}'),
                      _buildStatRow('总用时', '$mins分$secs秒'),
                      _buildStatRow('平均每题用时', _allQuestions.isEmpty ? '-' : '${(elapsed / _allQuestions.length).round()}秒'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 错题回顾
                if (_answers.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '错题回顾',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._buildWrongQuestions(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('返回题库', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _flowState = _ExamFlowState.start;
                        _answers.clear();
                        _markedQuestions.clear();
                        _writingControllers.clear();
                        _currentIndex = 0;
                        _remainingSeconds = _totalSeconds;
                        _elapsedSeconds = 0;
                        _isPaused = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('再考一次', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(int totalScore, bool isPass, int mins, int secs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPass
              ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
              : [const Color(0xFFF59E0B), const Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 32,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  '成绩报告',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$totalScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    '总分',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPass ? '恭喜通过！' : '继续加油！',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '用时 $mins 分 $secs 秒',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartScoreItem(
    _ExamPart part,
    int score,
    int maxScore,
    int correct,
    int total,
  ) {
    final accuracy = total > 0 ? (correct / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _partColor(part).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _partIcon(part),
                color: _partColor(part),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _partLabel(part),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: maxScore > 0 ? score / maxScore : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_partColor(part)),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _partColor(part),
                ),
              ),
              Text(
                '$correct/$total ($accuracy%)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _buildWrongQuestions() {
    final wrongQs = <Widget>[];
    for (final q in _allQuestions) {
      final userAnswer = _answers[q.globalNum];
      if (userAnswer == null) continue;
      if (userAnswer.toUpperCase() != q.answer.toUpperCase()) {
        wrongQs.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _partColor(q.part).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _partLabel(q.part),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _partColor(q.part),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '第${q.globalNum}题',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.content,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '你的答案: ',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      userAnswer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '正确答案: ',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      q.answer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    if (wrongQs.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
                const SizedBox(height: 12),
                Text(
                  '太棒了！没有错题',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return wrongQs;
  }

  // ==================== 辅助方法 ====================

  _ExamSection? _getCurrentPart() {
    for (final section in _sections) {
      for (final ss in section.subSections) {
        for (final q in ss.questions) {
          if (q.globalNum - 1 == _currentIndex) {
            return section;
          }
        }
      }
    }
    return null;
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _partLabel(_ExamPart part) {
    switch (part) {
      case _ExamPart.writing:
        return '写作';
      case _ExamPart.listening:
        return '听力';
      case _ExamPart.reading:
        return '阅读';
      case _ExamPart.translation:
        return '翻译';
    }
  }

  Color _partColor(_ExamPart part) {
    switch (part) {
      case _ExamPart.writing:
        return const Color(0xFF4F46E5);
      case _ExamPart.listening:
        return const Color(0xFF14B8A6);
      case _ExamPart.reading:
        return const Color(0xFFF97316);
      case _ExamPart.translation:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _partIcon(_ExamPart part) {
    switch (part) {
      case _ExamPart.writing:
        return Icons.edit_note_rounded;
      case _ExamPart.listening:
        return Icons.headphones_rounded;
      case _ExamPart.reading:
        return Icons.menu_book_rounded;
      case _ExamPart.translation:
        return Icons.translate_rounded;
    }
  }

  // ==================== 测试数据 ====================

  List<Question> _buildTestData() {
    return [
      Question(
        id: 1, type: '写作', year: '2024',
        content: 'Directions: For this part, you are allowed 30 minutes to write a short essay on the topic of '
            '"The Impact of Artificial Intelligence on College Education". '
            'You should write at least 120 words but no more than 180 words.',
        answer: '参考范文：Artificial intelligence is revolutionizing college education in profound ways...',
        explanation: '写作评分标准：内容切题、表达清楚、语言正确、结构合理。',
      ),
      Question(
        id: 2, type: '听力', year: '2024',
        content: 'What is the news report mainly about?',
        options: ['A. A new iPhone that can read your mind.',
          'B. A new smart phone that changes shape.',
          'C. A new electronic device that tracks your sleep.',
          'D. A new wearable device that monitors health conditions.'],
        answer: 'D', explanation: '新闻主要介绍了一款新型可穿戴设备，用于监测用户健康状况。',
      ),
      Question(
        id: 3, type: '听力', year: '2024',
        content: 'What is the special feature of the new device?',
        options: ['A. It can diagnose diseases without seeing a doctor.',
          'B. It can monitor blood pressure continuously.',
          'C. It can analyze blood samples instantly.',
          'D. It can track multiple health indicators simultaneously.'],
        answer: 'D', explanation: '该设备的特殊之处在于能够同时追踪多个健康指标。',
      ),
      Question(
        id: 4, type: '听力', year: '2024',
        content: 'When will the device be available to the public?',
        options: ['A. Next month.', 'B. In six months.',
          'C. Early next year.', 'D. Later this year.'],
        answer: 'C', explanation: '新闻提及该设备将在明年初面向公众发布。',
      ),
      Question(
        id: 5, type: '听力', year: '2024',
        content: 'What are the two speakers mainly discussing?',
        options: ['A. Their summer vacation plans.',
          'B. A research project assignment.',
          'C. A campus job opportunity.',
          'D. Their course schedule for next semester.'],
        answer: 'B', explanation: '对话围绕教授布置的研究项目作业展开。',
      ),
      Question(
        id: 6, type: '听力', year: '2024',
        content: 'What does the woman suggest they do?',
        options: ['A. Meet with the professor for advice.',
          'B. Divide the work between them.',
          'C. Extend the deadline of the project.',
          'D. Work on the project together in the library.'],
        answer: 'B', explanation: '女士建议两人分工合作完成项目。',
      ),
      Question(
        id: 7, type: '仔细阅读', year: '2024',
        passage: 'Climate change has become one of the most pressing issues of our time. '
            'Rising global temperatures, extreme weather events, and melting ice caps are just '
            'a few of the consequences that scientists have been warning about for decades.',
        content: 'What is the main idea of the passage?',
        options: ['A. Climate change is a serious global problem.',
          'B. Scientists have been wrong about climate change.',
          'C. Global temperatures are decreasing.',
          'D. Ice caps are not actually melting.'],
        answer: 'A', explanation: '文章主旨是气候变化是一个严重的全球性问题。',
      ),
      Question(
        id: 8, type: '仔细阅读', year: '2024',
        content: 'According to the passage, which of the following is a consequence of climate change?',
        options: ['A. Decreasing sea levels.',
          'B. More stable weather patterns.',
          'C. Extreme weather events.',
          'D. Colder winters worldwide.'],
        answer: 'C', explanation: '文中明确提到极端天气事件是气候变化的后果之一。',
      ),
      Question(
        id: 9, type: '仔细阅读', year: '2024',
        content: 'What can be inferred about the scientists mentioned in the passage?',
        options: ['A. They have recently changed their views.',
          'B. They have been warning about climate issues for many years.',
          'C. They disagree with each other about the causes.',
          'D. They focus mainly on ice cap studies.'],
        answer: 'B', explanation: '科学家们已经对气候变化问题警告了几十年。',
      ),
      Question(
        id: 10, type: '翻译', year: '2024',
        content: '中国传统文化博大精深，源远流长。其中，书法作为中国艺术瑰宝之一，不仅是一种书写方式，更是一种表达情感和审美的艺术形式。',
        answer: 'Traditional Chinese culture is profound and extensive with a long history. Among them, '
            'calligraphy, as one of the treasures of Chinese art, is not only a way of writing, '
            'but also an art form that expresses emotions and aesthetics.',
        explanation: '翻译要点：博大精深→profound and extensive；源远流长→with a long history；艺术瑰宝→art treasure。',
      ),
    ];
  }
}

// ==================== 数据模型 ====================

class _ExamSection {
  final _ExamPart part;
  final String partNo;
  final String title;
  final String time;
  final String directions;
  final List<_ExamSubSection> subSections;

  _ExamSection({
    required this.part,
    required this.partNo,
    required this.title,
    required this.time,
    required this.directions,
    required this.subSections,
  });
}

class _ExamSubSection {
  final String title;
  final String subTitle;
  final String directions;
  final List<_ExamQuestion> questions;

  _ExamSubSection({
    this.title = '',
    this.subTitle = '',
    this.directions = '',
    this.questions = const [],
  });
}

class _ExamQuestion {
  final int globalNum;
  final int questionId;
  final String content;
  final String? passage;
  final List<String>? options;
  final String answer;
  final String explanation;
  final String type;
  final _ExamPart part;

  _ExamQuestion({
    required this.globalNum,
    required this.questionId,
    required this.content,
    this.passage,
    this.options,
    required this.answer,
    required this.explanation,
    required this.type,
    required this.part,
  });
}
