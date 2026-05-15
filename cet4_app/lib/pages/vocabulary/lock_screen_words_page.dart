import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/db_helper.dart';
import '../../models/word.dart';
import '../../provider/study_provider.dart';
import 'package:provider/provider.dart';

class LockScreenWordsPage extends StatefulWidget {
  const LockScreenWordsPage({super.key});

  @override
  State<LockScreenWordsPage> createState() => _LockScreenWordsPageState();
}

class _LockScreenWordsPageState extends State<LockScreenWordsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DbHelper _dbHelper = DbHelper();
  final List<Word> _words = [];
  int _currentIndex = 0;
  bool _isRevealed = false;
  bool _isLoading = true;
  bool _isBookmarked = false;
  bool _isProcessing = false;
  int _correctCount = 0;
  int _wrongCount = 0;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final PageController _pageController;

  Timer? _autoHideTimer;

  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _bgColor = Color(0xFF0B0F19);
  static const Color _cardColor = Color(0xFF1A1F2E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _pageController = PageController();

    _loadWords();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWords();
    }
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      final rawWords = await _dbHelper.rawQuery('''
        SELECT w.* FROM words w
        LEFT JOIN study_records sr ON w.id = sr.word_id AND sr.user_id = 1
        WHERE sr.id IS NULL OR sr.status = '未学' OR sr.status = '学习中'
        ORDER BY RANDOM()
        LIMIT 20
      ''');

      _words.clear();
      for (final row in rawWords) {
        _words.add(Word.fromDbMap(row));
      }

      if (_words.isNotEmpty) {
        await _checkBookmarkStatus();
      }
    } catch (e) {
      debugPrint('加载锁屏单词失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkBookmarkStatus() async {
    if (_words.isEmpty) return;
    final word = _words[_currentIndex];
    try {
      final bookmarks = await _dbHelper.query(
        'word_bookmarks',
        where: 'word_id = ? AND user_id = ?',
        whereArgs: [word.id, 1],
      );
      if (mounted) {
        setState(() => _isBookmarked = bookmarks.isNotEmpty);
      }
    } catch (e) {
      debugPrint('检查收藏状态失败: $e');
    }
  }

  Future<void> _toggleBookmark() async {
    if (_words.isEmpty || _isProcessing) return;
    final word = _words[_currentIndex];
    setState(() => _isProcessing = true);

    try {
      if (_isBookmarked) {
        await _dbHelper.delete(
          'word_bookmarks',
          where: 'word_id = ? AND user_id = ?',
          whereArgs: [word.id, 1],
        );
      } else {
        await _dbHelper.insert('word_bookmarks', {
          'word_id': word.id,
          'user_id': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
      }
    } catch (e) {
      debugPrint('切换收藏失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _revealCard() {
    if (_isRevealed || _isProcessing || _words.isEmpty) return;
    setState(() => _isRevealed = true);
    _flipController.forward();
    _startAutoHideTimer();
  }

  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isRevealed) {
        _hideCard();
      }
    });
  }

  void _hideCard() {
    if (!_isRevealed) return;
    _autoHideTimer?.cancel();
    _flipController.reverse().then((_) {
      if (mounted) {
        setState(() => _isRevealed = false);
      }
    });
  }

  Future<void> _answer(bool isKnown) async {
    if (_isProcessing || !_isRevealed || _words.isEmpty) return;
    setState(() => _isProcessing = true);
    _autoHideTimer?.cancel();

    final word = _words[_currentIndex];
    final studyProvider = context.read<StudyProvider>();
    await studyProvider.updateWordStudyStatus(word.id, isKnown);

    if (isKnown) {
      _correctCount++;
    } else {
      _wrongCount++;
    }

    await _flipController.reverse();

    if (_currentIndex >= _words.length - 1) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showCompleteDialog();
      }
    } else {
      if (mounted) {
        setState(() {
          _currentIndex++;
          _isRevealed = false;
          _isProcessing = false;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        await _checkBookmarkStatus();
      }
    }
  }

  void _onPageChanged(int index) {
    if (_isRevealed) {
      _flipController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentIndex = index;
            _isRevealed = false;
          });
          _checkBookmarkStatus();
        }
      });
    } else {
      setState(() {
        _currentIndex = index;
      });
      _checkBookmarkStatus();
    }
  }

  void _showCompleteDialog() {
    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? (_correctCount / total * 100).toInt() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '本次学习完成',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('总计', '$total 个', Colors.white),
            const SizedBox(height: 8),
            _buildSummaryRow('认识', '$_correctCount 个', Colors.green),
            const SizedBox(height: 8),
            _buildSummaryRow('不认识', '$_wrongCount 个', Colors.red),
            const SizedBox(height: 8),
            _buildSummaryRow('正确率', '$accuracy%', _primaryColor),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('退出', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
                _wrongCount = 0;
                _isRevealed = false;
              });
              _pageController.jumpToPage(0);
              _loadWords();
            },
            style: FilledButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('再来一组'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出锁屏模式', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要退出锁屏背单词模式吗？',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续学习', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoHideTimer?.cancel();
    _flipController.dispose();
    _pageController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: _bgColor,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                )
              : _words.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: const Icon(Icons.check_circle_outline, size: 64, color: _primaryColor),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无单词可学习',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '请先导入单词数据',
            style: TextStyle(color: Colors.grey),
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
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _words.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildWordCard(_words[index]);
            },
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentIndex + 1} / ${_words.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isProcessing ? null : _toggleBookmark,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isBookmarked ? Icons.star : Icons.star_border,
                color: _isBookmarked ? Colors.amber : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(Word word) {
    return GestureDetector(
      onTap: _revealCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_flipAnimation.value * 3.14159),
                child: _flipAnimation.value < 0.5
                    ? _buildCardFront(word)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildCardBack(word),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(Word word) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 500),
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (word.phoneticUs.isNotEmpty || word.phoneticUk.isNotEmpty)
            Text(
              word.phoneticUs.isNotEmpty ? word.phoneticUs : word.phoneticUk,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, size: 20, color: _primaryColor.withOpacity(0.8)),
                const SizedBox(width: 10),
                Text(
                  '点击显示释义',
                  style: TextStyle(
                    color: _primaryColor.withOpacity(0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Word word) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 500),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                word.word,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (word.phoneticUs.isNotEmpty || word.phoneticUk.isNotEmpty)
              Center(
                child: Text(
                  word.phoneticUs.isNotEmpty ? word.phoneticUs : word.phoneticUk,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _buildInfoSection('释义', word.meaning, Icons.translate, Colors.green),
            if (word.type.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                word.type,
                style: TextStyle(
                  fontSize: 13,
                  color: _primaryColor.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (word.example.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildInfoSection('例句', word.example, Icons.format_quote, Colors.blue),
              if (word.exampleTranslation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  word.exampleTranslation,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
              ],
            ],
            if (word.collocation.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildInfoSection('搭配', word.collocation, Icons.link, Colors.orange),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon, Color color) {
    return Column(
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final progress = _words.isEmpty ? 0.0 : (_currentIndex + 1) / _words.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          if (_isRevealed && !_isProcessing)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _answer(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.15),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 20),
                          SizedBox(width: 6),
                          Text(
                            '不认识',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _answer(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 20),
                          SizedBox(width: 6),
                          Text(
                            '认识',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (_isProcessing)
            const SizedBox(
              height: 52,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _primaryColor,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 52),
        ],
      ),
    );
  }
}
