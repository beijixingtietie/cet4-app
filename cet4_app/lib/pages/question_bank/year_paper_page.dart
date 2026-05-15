import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../models/question.dart';
import 'exam_answer_page.dart';

enum ExamMode { practice, exam }

class ExamPaperInfo {
  final String id;
  final String year;
  final String month;
  final int paper;
  final String name;
  final Map<String, List<int>> questions;

  ExamPaperInfo({
    required this.id,
    required this.year,
    required this.month,
    required this.paper,
    required this.name,
    required this.questions,
  });

  factory ExamPaperInfo.fromJson(Map<String, dynamic> json) {
    final qMap = <String, List<int>>{};
    if (json['questions'] is Map) {
      for (final entry in (json['questions'] as Map).entries) {
        qMap[entry.key as String] = List<int>.from(entry.value as List);
      }
    }
    return ExamPaperInfo(
      id: json['id'] as String,
      year: json['year'] as String,
      month: json['month'] as String,
      paper: json['paper'] as int,
      name: json['name'] as String,
      questions: qMap,
    );
  }

  int get totalQuestions => questions.values.fold(0, (sum, list) => sum + list.length);
}

class YearPaperPage extends StatefulWidget {
  final ExamMode mode;
  const YearPaperPage({super.key, required this.mode});

  @override
  State<YearPaperPage> createState() => _YearPaperPageState();
}

class _YearPaperPageState extends State<YearPaperPage> {
  List<ExamPaperInfo> _papers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    try {
      final json = await rootBundle.loadString('assets/data/exams_index.json');
      final list = jsonDecode(json) as List;
      _papers = list.map((e) => ExamPaperInfo.fromJson(e)).toList();
    } catch (_) {
      _papers = [];
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ??
        (isDark ? Colors.white : Colors.black87);
    final textSecondary = isDark ? Colors.white60 : Colors.grey[600];
    final isExam = widget.mode == ExamMode.exam;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, isDark, isExam),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _papers.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Text(
                          '暂无真题数据',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: textSecondary,
                              ),
                        ),
                      ),
                    )
                  : _buildPaperList(isDark, cardColor, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isExam) {
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
        bottom: 24,
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
                      isExam ? '模拟考试' : '练习模式',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '选择一套真题开始',
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

  Widget _buildPaperList(
    bool isDark,
    Color cardColor,
    Color? textPrimary,
    Color? textSecondary,
  ) {
    final grouped = <String, List<ExamPaperInfo>>{};
    for (final p in _papers) {
      grouped.putIfAbsent(p.year, () => []).add(p);
    }
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final year = years[index];
            final papers = grouped[year]!;
            return _buildYearGroup(
              year,
              papers,
              isDark,
              cardColor,
              textPrimary,
              textSecondary,
            );
          },
          childCount: years.length,
        ),
      ),
    );
  }

  Widget _buildYearGroup(
    String year,
    List<ExamPaperInfo> papers,
    bool isDark,
    Color cardColor,
    Color? textPrimary,
    Color? textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF4F46E5).withOpacity(0.15)
                : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$year年',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  fontSize: 14,
                ),
          ),
        ),
        ...papers.map(
          (p) => _buildPaperCard(
            p,
            isDark,
            cardColor,
            textPrimary,
            textSecondary,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPaperCard(
    ExamPaperInfo paper,
    bool isDark,
    Color cardColor,
    Color? textPrimary,
    Color? textSecondary,
  ) {
    final isExam = widget.mode == ExamMode.exam;
    final iconColor = isExam ? const Color(0xFFE11D48) : const Color(0xFF4F46E5);
    final iconBgColor = isExam ? const Color(0xFFFFF1F2) : const Color(0xFFEEF2FF);

    final typeTags = [
      _TypeTag(label: '写作', color: const Color(0xFF4F46E5)),
      _TypeTag(label: '听力', color: const Color(0xFF14B8A6)),
      _TypeTag(label: '阅读', color: const Color(0xFFF97316)),
      _TypeTag(label: '翻译', color: const Color(0xFF8B5CF6)),
    ];

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _enterExam(paper),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withOpacity(0.12) : iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isExam ? Icons.timer_rounded : Icons.edit_note_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${paper.totalQuestions} 题',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: typeTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? tag.color.withOpacity(0.12)
                                : tag.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? tag.color.withOpacity(0.9)
                                  : tag.color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.grey[350],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterExam(ExamPaperInfo paper) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamAnswerPage(
          paperInfo: paper,
          mode: widget.mode,
        ),
      ),
    );
  }
}

class _TypeTag {
  final String label;
  final Color color;
  _TypeTag({required this.label, required this.color});
}
