import 'package:flutter/material.dart';
import '../../database/db_helper.dart';

class ExamResultPage extends StatefulWidget {
  final String paperName;
  final Map<int, String> answers;
  final int totalQuestions;
  final int durationSeconds;
  final String mode; // 'practice' or 'exam'

  const ExamResultPage({
    super.key,
    required this.paperName,
    required this.answers,
    required this.totalQuestions,
    required this.durationSeconds,
    required this.mode,
  });

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  final DbHelper _dbHelper = DbHelper();
  int _correctCount = 0;
  int _wrongCount = 0;
  Map<String, int> _typeStats = {};
  bool _isCalculating = true;

  @override
  void initState() {
    super.initState();
    _calculateResults();
  }

  Future<void> _calculateResults() async {
    final allQuestions = await _dbHelper.query('questions');
    final qMap = <int, Map<String, dynamic>>{};
    for (final q in allQuestions) {
      qMap[q['id'] as int] = q;
    }

    int correct = 0;
    int wrong = 0;
    final typeStats = <String, int>{};

    for (final entry in widget.answers.entries) {
      final q = qMap[entry.key];
      final type = (q?['type'] as String?) ?? '其他';
      typeStats[type] = (typeStats[type] ?? 0) + 1;

      if (q != null && entry.value == q['answer']) {
        correct++;
      } else {
        wrong++;
        // 写入错题本
        try {
          await _dbHelper.insert('wrong_questions', {
            'question_id': entry.key,
            'user_id': 1,
            'user_answer': entry.value,
            'add_time': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }

    setState(() {
      _correctCount = correct;
      _wrongCount = wrong;
      _typeStats = typeStats;
      _isCalculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? (_correctCount / total * 100).toInt() : 0;
    final mins = widget.durationSeconds ~/ 60;
    final secs = widget.durationSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩单'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isCalculating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 成绩卡片
                  Card(
                    elevation: 4,
                    color: accuracy >= 60 ? Colors.green[50] : Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            accuracy >= 60 ? Icons.emoji_events : Icons.school,
                            size: 56,
                            color: accuracy >= 60 ? Colors.amber : Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.mode == 'exam' ? '考试完成' : '练习完成',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.paperName,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statCol('总计', '${widget.answers.length}/$total', Colors.blue),
                              _statCol('正确', '$_correctCount', Colors.green),
                              _statCol('错误', '$_wrongCount', Colors.red),
                              _statCol('正确率', '$accuracy%', accuracy >= 60 ? Colors.green : Colors.orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 用时
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '用时 ${mins}分${secs}秒',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 各题型统计
                  if (_typeStats.isNotEmpty) ...[
                    const Text('各题型答题情况', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: _typeStats.entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key),
                                  Text('${e.value} 题答完', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 操作按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('返回题库', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
