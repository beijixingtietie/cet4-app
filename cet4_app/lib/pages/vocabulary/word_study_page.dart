import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/study_provider.dart';
import '../../models/word.dart';

class WordStudyPage extends StatefulWidget {
  final List<Word>? preloadedWords;

  const WordStudyPage({super.key, this.preloadedWords});

  WordStudyPage.withWords(List<Word> words, {super.key})
      : preloadedWords = words;

  @override
  State<WordStudyPage> createState() => _WordStudyPageState();
}

class _WordStudyPageState extends State<WordStudyPage>
    with SingleTickerProviderStateMixin {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _isRevealed = false;
  bool _isAnswering = false;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _isComplete = false;
  bool _isLoading = true;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _primaryLight = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWords();
    });
  }

  void _loadWords() {
    final widgetWords = widget.preloadedWords;
    if (widgetWords != null && widgetWords.isNotEmpty) {
      _words = widgetWords;
      setState(() => _isLoading = false);
      return;
    }

    final studyProvider = context.read<StudyProvider>();
    final rawWords = studyProvider.todayWords;

    if (rawWords.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    _words = rawWords.map((row) {
      return Word(
        id: row['id'] as int? ?? 0,
        word: row['word'] as String? ?? '',
        phoneticUk: row['phonetic_uk'] as String? ?? '',
        phoneticUs: row['phonetic_us'] as String? ?? '',
        audioUk: row['audio_uk'] as String? ?? '',
        audioUs: row['audio_us'] as String? ?? '',
        type: row['type'] as String? ?? '',
        meaning: row['meaning'] as String? ?? '',
        example: row['example'] as String? ?? '',
        exampleTranslation: row['example_translation'] as String? ?? '',
        collocation: row['collocation'] as String? ?? '',
        level: row['level'] as String? ?? '',
      );
    }).toList();

    setState(() => _isLoading = false);
  }

  void _revealCard() {
    if (_isRevealed || _isAnswering || _isComplete) return;
    setState(() => _isRevealed = true);
    _flipController.forward();
  }

  Future<void> _answer(bool isCorrect) async {
    if (_isAnswering || !_isRevealed || _isComplete) return;

    setState(() => _isAnswering = true);

    if (isCorrect) {
      _correctCount++;
    } else {
      _wrongCount++;
    }

    final studyProvider = context.read<StudyProvider>();
    final word = _words[_currentIndex];
    await studyProvider.updateWordStudyStatus(word.id, isCorrect);

    await _flipController.reverse();

    if (_currentIndex >= _words.length - 1) {
      setState(() {
        _isComplete = true;
        _isAnswering = false;
      });
    } else {
      setState(() {
        _currentIndex++;
        _isRevealed = false;
        _isAnswering = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_isComplete) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1a1f2e) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('确定退出吗？'),
            ],
          ),
          content: Text('你已完成 ${_currentIndex + 1}/${_words.length} 个单词，退出后进度将丢失。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('继续背诵'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0B0F19) : _primaryColor,
          elevation: 0,
          title: const Text('单词背诵'),
          centerTitle: true,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primaryColor))
            : _words.isEmpty
                ? _buildEmptyState(isDark)
                : _isComplete
                    ? _buildCompleteSummary(isDark)
                    : _buildStudyContent(isDark),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded, size: 64, color: _primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            '今日无需背诵的单词',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有单词都已完成学习，明天再来吧！',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('返回词汇页'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyContent(bool isDark) {
    final word = _words[_currentIndex];
    final progress = (_currentIndex + (_isRevealed ? 1 : 0)) / _words.length;

    return Column(
      children: [
        _buildProgressBar(progress, isDark),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '第 ${_currentIndex + 1}/${_words.length} 个',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _buildCountBadge(Icons.check_circle_rounded, '$_correctCount', Colors.green),
                  const SizedBox(width: 12),
                  _buildCountBadge(Icons.cancel_rounded, '$_wrongCount', Colors.red),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildStudyCard(word, isDark),
        const Spacer(),
        if (_isRevealed && !_isAnswering) _buildAnswerButtons(),
        if (_isAnswering)
          const Padding(
            padding: EdgeInsets.only(bottom: 40.0),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCountBadge(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF1a1f2e) : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyCard(Word word, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GestureDetector(
        onTap: _revealCard,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_flipAnimation.value * 3.14159),
              child: _flipAnimation.value < 0.5
                  ? _buildCardFront(word, isDark)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateX(3.14159),
                      child: _buildCardBack(word, isDark),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardFront(Word word, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1f2e) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]!,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryColor, _primaryLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word.word,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word.phoneticUk,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 20, color: _primaryColor),
                const SizedBox(width: 10),
                Text(
                  '点击卡片查看释义',
                  style: TextStyle(color: _primaryColor, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Word word, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1f2e) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]!,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  word.word,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoBlock(
              '释义',
              word.meaning,
              Icons.translate_rounded,
              Colors.green,
              isDark,
            ),
            if (word.example.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoBlock(
                '例句',
                word.example,
                Icons.format_quote_rounded,
                Colors.blue,
                isDark,
                subtitle: word.exampleTranslation.isNotEmpty ? word.exampleTranslation : null,
              ),
            ],
            if (word.collocation.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoBlock(
                '常见搭配',
                word.collocation,
                Icons.link_rounded,
                Colors.orange,
                isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock(String title, String content, IconData icon, Color color, bool isDark, {String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[200] : Colors.black87,
                  height: 1.5,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () => _answer(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, size: 20),
                    SizedBox(width: 6),
                    Text(
                      '不认识',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () => _answer(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 20),
                    SizedBox(width: 6),
                    Text(
                      '认识',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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

  Widget _buildCompleteSummary(bool isDark) {
    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? (_correctCount / total * 100).toInt() : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _primaryLight],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              '背诵完成！',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '本次共学习 $total 个单词',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1a1f2e) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]!,
                ),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('总计', '$total 个单词', _primaryColor, isDark),
                  Divider(height: 24, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]),
                  _buildSummaryRow('认识', '$_correctCount 个', Colors.green, isDark),
                  Divider(height: 24, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]),
                  _buildSummaryRow('不认识', '$_wrongCount 个', Colors.red, isDark),
                  Divider(height: 24, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]),
                  _buildSummaryRow(
                    '正确率',
                    '$accuracy%',
                    accuracy >= 60 ? Colors.green : Colors.orange,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '已根据遗忘曲线为您安排复习计划',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '错误的单词将在明天再次出现',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('返回词汇页', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.black87,
                  ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
