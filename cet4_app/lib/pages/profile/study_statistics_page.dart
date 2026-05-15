import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/db_helper.dart';

class StudyStatisticsPage extends StatefulWidget {
  const StudyStatisticsPage({super.key});

  @override
  State<StudyStatisticsPage> createState() => _StudyStatisticsPageState();
}

class _StudyStatisticsPageState extends State<StudyStatisticsPage>
    with SingleTickerProviderStateMixin {
  static const Color _primaryColor = Color(0xFF4F46E5);

  late TabController _tabController;
  final DbHelper _dbHelper = DbHelper();

  bool _isLoading = true;

  int _totalStudyDays = 0;
  int _totalLearnedWords = 0;
  int _avgDailyDuration = 0;
  int _consecutiveCheckinDays = 0;
  double _masteryRate = 0.0;

  List<int> _weeklyWordCounts = List.filled(7, 0);
  List<int> _weeklyDurations = List.filled(7, 0);
  List<double> _monthlyTrend = List.filled(30, 0);
  List<Map<String, dynamic>> _questionTypeStats = [];
  List<double> _semesterProgress = [];
  List<double> _semesterMastery = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadKeyStats(),
      _loadWeeklyStats(),
      _loadMonthlyStats(),
      _loadSemesterStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadKeyStats() async {
    final studyRecords = await _dbHelper.query('study_records');
    final settings = await _dbHelper.query('user_settings', where: 'user_id = ?', whereArgs: [1]);

    final learnedRecords = studyRecords.where((r) => r['status'] != '未学').toList();
    _totalLearnedWords = learnedRecords.length;

    final masteredRecords = studyRecords.where((r) => r['status'] == '已掌握').toList();
    _masteryRate = studyRecords.isEmpty
        ? 0.0
        : (masteredRecords.length / studyRecords.length) * 100;

    if (settings.isNotEmpty) {
      _totalStudyDays = settings.first['total_study_days'] as int? ?? 0;
      _consecutiveCheckinDays = settings.first['checkin_days'] as int? ?? 0;
    }

    int totalDuration = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dayRecords = studyRecords.where((r) {
        if (r['last_study_time'] == null) return false;
        final t = DateTime.parse(r['last_study_time'] as String);
        return t.isAfter(dayStart) && t.isBefore(dayEnd);
      }).toList();
      totalDuration += dayRecords.length * 3;
    }
    _avgDailyDuration = _totalStudyDays > 0 ? totalDuration ~/ _totalStudyDays : 0;
  }

  Future<void> _loadWeeklyStats() async {
    final studyRecords = await _dbHelper.query('study_records');
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayRecords = studyRecords.where((r) {
        if (r['last_study_time'] == null) return false;
        final t = DateTime.parse(r['last_study_time'] as String);
        return t.isAfter(dayStart) && t.isBefore(dayEnd);
      }).toList();

      _weeklyWordCounts[i] = dayRecords.length;
      _weeklyDurations[i] = dayRecords.length * 3;
    }
  }

  Future<void> _loadMonthlyStats() async {
    final studyRecords = await _dbHelper.query('study_records');
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: 29 - i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayRecords = studyRecords.where((r) {
        if (r['last_study_time'] == null) return false;
        final t = DateTime.parse(r['last_study_time'] as String);
        return t.isAfter(dayStart) && t.isBefore(dayEnd);
      }).toList();

      _monthlyTrend[i] = dayRecords.length.toDouble();
    }

    final examRecords = await _dbHelper.query('exam_records');
    final questions = await _dbHelper.query('questions');

    final Map<String, int> typeCounts = {};
    for (final record in examRecords) {
      final qid = record['question_id'];
      final question = questions.firstWhere(
        (q) => q['id'] == qid,
        orElse: () => <String, dynamic>{},
      );
      final type = (question['type'] as String?) ?? '其他';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    _questionTypeStats = typeCounts.entries
        .map((e) => {'type': e.key, 'count': e.value})
        .toList();

    if (_questionTypeStats.isEmpty) {
      _questionTypeStats = [
        {'type': '听力', 'count': 0},
        {'type': '阅读', 'count': 0},
        {'type': '写作', 'count': 0},
        {'type': '翻译', 'count': 0},
      ];
    }
  }

  Future<void> _loadSemesterStats() async {
    final studyRecords = await _dbHelper.query('study_records');
    final now = DateTime.now();
    final semesterStart = now.subtract(const Duration(days: 120));

    final weeklyData = <int, Map<String, int>>{};
    for (final record in studyRecords) {
      if (record['last_study_time'] == null) continue;
      final t = DateTime.parse(record['last_study_time'] as String);
      if (t.isBefore(semesterStart)) continue;

      final weekDiff = t.difference(semesterStart).inDays ~/ 7;
      weeklyData.putIfAbsent(weekDiff, () => {'total': 0, 'mastered': 0});
      weeklyData[weekDiff]!['total'] = weeklyData[weekDiff]!['total']! + 1;
      if (record['status'] == '已掌握') {
        weeklyData[weekDiff]!['mastered'] = weeklyData[weekDiff]!['mastered']! + 1;
      }
    }

    final maxWeek = weeklyData.keys.isEmpty ? 0 : weeklyData.keys.reduce((a, b) => a > b ? a : b);
    _semesterProgress = [];
    _semesterMastery = [];

    int cumulative = 0;
    for (int i = 0; i <= maxWeek; i++) {
      final data = weeklyData[i] ?? {'total': 0, 'mastered': 0};
      cumulative += data['total']!;
      _semesterProgress.add(cumulative.toDouble());
      _semesterMastery.add(data['total']! > 0
          ? (data['mastered']! / data['total']!) * 100
          : 0.0);
    }

    if (_semesterProgress.isEmpty) {
      _semesterProgress = [0];
      _semesterMastery = [0];
    }
  }

  String _weekDayLabel(int index) {
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  String _monthDayLabel(int index) {
    final date = DateTime.now().subtract(Duration(days: 29 - index));
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF1A1F2E) : Colors.white;
    final textColor = isDark ? Colors.grey[300] : Colors.grey[800];
    final subTextColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '学习数据统计',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryColor,
          labelColor: _primaryColor,
          unselectedLabelColor: subTextColor,
          tabs: const [
            Tab(text: '周统计'),
            Tab(text: '月统计'),
            Tab(text: '学期统计'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(isDark, cardColor, textColor, subTextColor),
                _buildMonthlyTab(isDark, cardColor, textColor, subTextColor),
                _buildSemesterTab(isDark, cardColor, textColor, subTextColor),
              ],
            ),
    );
  }

  Widget _buildWeeklyTab(bool isDark, Color cardColor, Color? textColor, Color? subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildKeyStatsGrid(isDark, cardColor, textColor, subTextColor),
          const SizedBox(height: 20),
          _buildChartCard(
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
            title: '近7天每日学习单词数',
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_weeklyWordCounts.reduce((a, b) => a > b ? a : b) + 5).toDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => _primaryColor,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} 词',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= 7) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _weekDayLabel(value.toInt()),
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: subTextColor),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: _weeklyWordCounts[index].toDouble(),
                          color: _primaryColor,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
            title: '近7天每日学习时长（分钟）',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (_weeklyDurations.reduce((a, b) => a > b ? a : b) + 10).toDouble(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _primaryColor,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} 分钟',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= 7) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _weekDayLabel(value.toInt()),
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: subTextColor),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(7, (index) {
                        return FlSpot(index.toDouble(), _weeklyDurations[index].toDouble());
                      }),
                      isCurved: true,
                      color: _primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _primaryColor,
                            strokeWidth: 2,
                            strokeColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab(bool isDark, Color cardColor, Color? textColor, Color? subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
            title: '近30天学习趋势',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (_monthlyTrend.reduce((a, b) => a > b ? a : b) + 5).toDouble(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _primaryColor,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} 词',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= 30) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _monthDayLabel(value.toInt()),
                              style: TextStyle(fontSize: 10, color: subTextColor),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: subTextColor),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(30, (index) {
                        return FlSpot(index.toDouble(), _monthlyTrend[index]);
                      }),
                      isCurved: true,
                      color: _primaryColor,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _primaryColor.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
            title: '各题型练习次数',
            child: SizedBox(
              height: 260,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildPieSections(),
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {},
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _questionTypeStats.map((item) {
                        final colors = [
                          _primaryColor,
                          Colors.green,
                          Colors.orange,
                          Colors.red,
                          Colors.teal,
                          Colors.purple,
                        ];
                        final index = _questionTypeStats.indexOf(item);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['type'] as String,
                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item['count']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final colors = [
      _primaryColor,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.purple,
    ];

    final total = _questionTypeStats.fold<int>(0, (sum, item) => sum + (item['count'] as int));
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey[300],
          value: 1,
          title: '',
          radius: 50,
        ),
      ];
    }

    return _questionTypeStats.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final count = item['count'] as int;
      final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: count.toDouble(),
        title: '$percentage%',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildSemesterTab(bool isDark, Color cardColor, Color? textColor, Color? subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
            title: '累计学习进度',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (_semesterProgress.isNotEmpty
                          ? _semesterProgress.reduce((a, b) => a > b ? a : b)
                          : 0) +
                      20,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _primaryColor,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} 词',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= _semesterProgress.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '第${value.toInt() + 1}周',
                              style: TextStyle(fontSize: 10, color: subTextColor),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: subTextColor),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(_semesterProgress.length, (index) {
                        return FlSpot(index.toDouble(), _semesterProgress[index]);
                      }),
                      isCurved: true,
                      color: _primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _primaryColor,
                            strokeWidth: 2,
                            strokeColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
            title: '词汇掌握率变化趋势（%）',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _primaryColor,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}%',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= _semesterMastery.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '第${value.toInt() + 1}周',
                              style: TextStyle(fontSize: 10, color: subTextColor),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(fontSize: 10, color: subTextColor),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? const Color(0xFF2A2F3E) : const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(_semesterMastery.length, (index) {
                        return FlSpot(index.toDouble(), _semesterMastery[index]);
                      }),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green,
                            strokeWidth: 2,
                            strokeColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyStatsGrid(bool isDark, Color cardColor, Color? textColor, Color? subTextColor) {
    final stats = [
      {'label': '总学习天数', 'value': '$_totalStudyDays', 'icon': Icons.calendar_today_rounded, 'color': _primaryColor},
      {'label': '累计单词', 'value': '$_totalLearnedWords', 'icon': Icons.menu_book_rounded, 'color': Colors.green},
      {'label': '日均时长', 'value': '$_avgDailyDuration分钟', 'icon': Icons.timer_rounded, 'color': Colors.orange},
      {'label': '连续打卡', 'value': '$_consecutiveCheckinDays天', 'icon': Icons.local_fire_department_rounded, 'color': Colors.red},
      {'label': '掌握率', 'value': '${_masteryRate.toStringAsFixed(1)}%', 'icon': Icons.trending_up_rounded, 'color': Colors.teal},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '关键数据',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats.map((stat) {
              return Container(
                width: (MediaQuery.of(context).size.width - 64) / 2,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (stat['color'] as Color).withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 22),
                    const SizedBox(height: 10),
                    Text(
                      stat['value'] as String,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required bool isDark,
    required Color cardColor,
    required Color? textColor,
    required Color? subTextColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
