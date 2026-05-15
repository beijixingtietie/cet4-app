import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_images.dart';
import '../../models/word.dart';
import '../../provider/study_provider.dart';
import '../../provider/user_provider.dart';
import '../../provider/navigation_provider.dart';
import '../vocabulary/word_study_page.dart';
import '../question_bank/year_paper_page.dart';
import '../question_bank/exam_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static Uint8List? _decodeBase64(String str) {
    try {
      return base64.decode(str);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final studyProvider = context.watch<StudyProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, isDark, userProvider, studyProvider),
          ),
          SliverToBoxAdapter(
            child: _buildDailyProgress(context, studyProvider, userProvider, isDark),
          ),
          SliverToBoxAdapter(
            child: _buildMotivation(context, isDark, studyProvider),
          ),
          SliverToBoxAdapter(
            child: _buildQuickActions(context, isDark),
          ),
          SliverToBoxAdapter(
            child: _buildStatsGrid(context, studyProvider, isDark),
          ),
          SliverToBoxAdapter(
            child: _buildReviewForecast(context, studyProvider, isDark),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, UserProvider userProvider, StudyProvider studyProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 6) greeting = '夜深了';
    else if (hour < 9) greeting = '早上好';
    else if (hour < 12) greeting = '上午好';
    else if (hour < 14) greeting = '中午好';
    else if (hour < 18) greeting = '下午好';
    else greeting = '晚上好';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      color: isDark ? colorScheme.onSurface.withOpacity(0.6) : colorScheme.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CET4备考助手',
                    style: TextStyle(
                      color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: const Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${studyProvider.checkinDays}天',
                    style: TextStyle(
                      color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgress(BuildContext context, StudyProvider provider, UserProvider userProvider, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = provider.studyProgress;
    final todayCount = provider.todayStudyCount;
    final reviewCount = provider.reviewWords.length;
    final total = progress['total'] ?? 0;
    final mastered = progress['mastered'] ?? 0;
    final progressPercent = userProvider.dailyWordGoal > 0
        ? (todayCount / userProvider.dailyWordGoal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '今日学习',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$todayCount 词',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: progressPercent,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(progressPercent * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          '完成度',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _StatCard(value: '$total', label: '累计学习', isDark: isDark)),
                        Expanded(child: _StatCard(value: '$mastered', label: '已掌握', isDark: isDark)),
                        Expanded(child: _StatCard(value: '$reviewCount', label: '待复习', isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? mastered / total : 0,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getAccuracyColor(total > 0 ? (mastered / total * 100) : 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _AnimatedButton(
              onPressed: () => _startStudy(context, provider),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 20, color: colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    '开始学习',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivation(BuildContext context, bool isDark, StudyProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final todayCount = provider.todayStudyCount;
    String message;
    if (todayCount == 0) {
      message = '今天还没有开始学习，快来背单词吧！';
    } else if (todayCount < 10) {
      message = '今天已经背了$todayCount个单词，继续加油！';
    } else if (todayCount < 30) {
      message = '太棒了！已背$todayCount个单词，保持节奏！';
    } else {
      message = '学习达人！已背$todayCount个单词，你是最棒的！';
    }

    final bannerBytes = _decodeBase64(kBannerDecoration);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(isDark ? 0.25 : 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (bannerBytes != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Image.memory(
                bannerBytes,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                cacheWidth: 80,
                cacheHeight: 80,
                opacity: const AlwaysStoppedAnimation(0.9),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF5B8DEF) : colorScheme.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = [
      _ActionItem(
        icon: Icons.book,
        label: '背单词',
        subtitle: '今日词汇',
        gradientColors: const [Color(0xFF165DFF), Color(0xFF3B82F6)],
        backgroundImage: kCardBackgroundWord,
        onTap: () => _startStudy(context, context.read<StudyProvider>()),
      ),
      _ActionItem(
        icon: Icons.error_outline,
        label: '错题本',
        subtitle: '查漏补缺',
        gradientColors: const [Color(0xFFEF4444), Color(0xFFF87171)],
        backgroundImage: kCardBackgroundWrong,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamPage()));
        },
      ),
      _ActionItem(
        icon: Icons.article,
        label: '新题型',
        subtitle: '专项练习',
        gradientColors: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        backgroundImage: kCardBackgroundExam,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamPage()));
        },
      ),
      _ActionItem(
        icon: Icons.bookmark_border,
        label: '生词本',
        subtitle: '重点标记',
        gradientColors: const [Color(0xFF10B981), Color(0xFF34D399)],
        backgroundImage: kCardBackgroundWordbook,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamPage()));
        },
      ),
      _ActionItem(
        icon: Icons.smart_toy_outlined,
        label: 'AI助手',
        subtitle: '智能答疑',
        gradientColors: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        backgroundImage: kCardBackgroundAI,
        onTap: () {
          context.read<NavigationProvider>().setIndex(3);
        },
      ),
      _ActionItem(
        icon: Icons.timer,
        label: '模拟考试',
        subtitle: '真题演练',
        gradientColors: const [Color(0xFF165DFF), Color(0xFF3B82F6)],
        backgroundImage: kCardBackgroundMock,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const YearPaperPage(mode: ExamMode.exam)));
        },
      ),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速入口',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0,
                children: actions.map((action) => _ActionCard(action: action, isDark: isDark)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, StudyProvider provider, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = provider.studyProgress['total'] ?? 0;
    final mastered = provider.studyProgress['mastered'] ?? 0;
    final learning = provider.studyProgress['learning'] ?? 0;
    final forgotten = provider.studyProgress['forgotten'] ?? 0;
    final accuracy = total > 0 ? (mastered / total * 100).toStringAsFixed(1) : '0.0';
    final accuracyValue = total > 0 ? mastered / total * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习概览',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _OverviewItem(value: '$total', label: '总词汇', isDark: isDark)),
              Expanded(child: _OverviewItem(value: '$accuracy%', label: '掌握率', isDark: isDark, valueColor: _getAccuracyColor(accuracyValue))),
              Expanded(child: _OverviewItem(value: '$learning', label: '学习中', isDark: isDark)),
              Expanded(child: _OverviewItem(value: '$forgotten', label: '需复习', isDark: isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewForecast(BuildContext context, StudyProvider provider, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final forecast = provider.reviewForecast;
    if (forecast.isEmpty) return const SizedBox.shrink();

    final dayLabels = ['今天', '明天', '后天', '3天后', '4天后', '5天后', '6天后'];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '复习预测',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: forecast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final count = forecast[index];
                final isToday = index == 0;
                return Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: isToday
                        ? colorScheme.primary
                        : (isDark ? const Color(0xFF1E293B) : colorScheme.surface),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday
                        ? null
                        : Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: colorScheme.onSurface.withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabels[index],
                        style: TextStyle(
                          fontSize: 11,
                          color: isToday
                              ? colorScheme.onPrimary.withOpacity(0.8)
                              : (isDark ? colorScheme.onSurface.withOpacity(0.6) : colorScheme.secondary),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? colorScheme.onPrimary
                              : (isDark ? colorScheme.onSurface : colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _startStudy(BuildContext context, StudyProvider provider) async {
    final colorScheme = Theme.of(context).colorScheme;
    await provider.loadTodayWords(10);
    if (!context.mounted) return;
    final words = provider.todayWords;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.celebration, color: colorScheme.onPrimary, size: 20),
              const SizedBox(width: 8),
              Text('今日单词已全部完成！太棒了！', style: TextStyle(color: colorScheme.onPrimary)),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final wordList = words.map((w) => Word.fromDbMap(w)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WordStudyPage.withWords(wordList)),
    );
  }

  Color _getAccuracyColor(double value) {
    if (value < 60) return const Color(0xFFEF4444);
    if (value < 80) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _StatCard({required this.value, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? colorScheme.onSurface.withOpacity(0.6) : colorScheme.secondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final String backgroundImage;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.backgroundImage,
    required this.onTap,
  });
}

class _ActionCard extends StatefulWidget {
  final _ActionItem action;
  final bool isDark;

  const _ActionCard({required this.action, required this.isDark});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final isDark = widget.isDark;
    final colorScheme = Theme.of(context).colorScheme;
    final bgBytes = action.backgroundImage.isNotEmpty ? HomePage._decodeBase64(action.backgroundImage) : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          action.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.onSurface.withOpacity(_isHovered ? (isDark ? 0.3 : 0.1) : (isDark ? 0.2 : 0.05)),
                      blurRadius: _isHovered ? 16 : 12,
                      offset: Offset(0, _isHovered ? 8 : 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      if (bgBytes != null)
                        Positioned.fill(
                          child: Image.memory(
                            bgBytes,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            opacity: const AlwaysStoppedAnimation(0.1),
                            cacheWidth: 400,
                            cacheHeight: 400,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: action.gradientColors,
                                ),
                              ),
                              child: Icon(action.icon, color: colorScheme.onPrimary, size: 24),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? colorScheme.onSurface : colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  action.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: isDark ? colorScheme.onSurface.withOpacity(0.6) : colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _AnimatedButton({required this.onPressed, required this.child});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;
  final Color? valueColor;

  const _OverviewItem({
    required this.value,
    required this.label,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: valueColor ?? colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? colorScheme.onSurface.withOpacity(0.6) : colorScheme.secondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
