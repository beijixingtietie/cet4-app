import 'package:flutter/material.dart';
import '../wrong_questions/wrong_questions_page.dart';
import 'year_paper_page.dart';

class ExamHomePage extends StatelessWidget {
  const ExamHomePage({super.key});

  static const Color _primary = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ??
        (isDark ? Colors.white : Colors.black87);
    final textSecondary = isDark ? Colors.white60 : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, isDark),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                Text(
                  '选择练习模式',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                _buildModeCard(
                  context,
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.edit_note_rounded,
                  title: '练习模式',
                  subtitle: '逐题作答，随时查看答案与解析',
                  iconBgColor: const Color(0xFFEEF2FF),
                  iconColor: _primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const YearPaperPage(mode: ExamMode.practice)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildModeCard(
                  context,
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.timer_rounded,
                  title: '模拟考试模式',
                  subtitle: '全真计时考试，不可查看答案，时间到自动交卷',
                  iconBgColor: const Color(0xFFFFF1F2),
                  iconColor: const Color(0xFFE11D48),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const YearPaperPage(mode: ExamMode.exam)),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  '快捷入口',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickCard(
                        context,
                        isDark: isDark,
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        icon: Icons.history_rounded,
                        title: '历史记录',
                        iconBgColor: const Color(0xFFF0FDFA),
                        iconColor: const Color(0xFF14B8A6),
                        onTap: _showHistory,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickCard(
                        context,
                        isDark: isDark,
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        icon: Icons.error_outline_rounded,
                        title: '错题本',
                        iconBgColor: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFF97316),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WrongQuestionsPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '四级题库',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '历年真题 · 模拟考试 · 专项练习',
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

  Widget _buildModeCard(
    BuildContext context, {
    required bool isDark,
    required Color? cardColor,
    required Color? textPrimary,
    required Color? textSecondary,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withOpacity(0.12) : iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.grey[350], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCard(
    BuildContext context, {
    required bool isDark,
    required Color? cardColor,
    required Color? textPrimary,
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withOpacity(0.12) : iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory() {
    // TODO: 实现历史记录页面
  }
}
