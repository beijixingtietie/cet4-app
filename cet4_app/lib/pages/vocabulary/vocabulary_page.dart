import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/study_provider.dart';
import '../../provider/ai_provider.dart';
import '../../models/word.dart';
import '../../utils/json_loader.dart';
import '../../database/db_helper.dart';
import '../word_book/word_book_page.dart';
import '../import/pdf_import_page.dart';
import 'word_study_page.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage>
    with SingleTickerProviderStateMixin {
  final DbHelper _dbHelper = DbHelper();
  List<Word> _words = [];
  List<Word> _filteredWords = [];
  Set<int> _bookmarkedWordIds = {};
  String _selectedLevel = '全部';
  bool _isLoading = true;
  int _dailyGoal = 10;
  int? _selectedWordId;
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _primaryLight = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadWords();
    _loadBookmarks();
    _loadDailyGoal();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      final dbData = await _dbHelper.query('words');
      if (dbData.isNotEmpty) {
        _words = dbData.map((m) => Word.fromDbMap(m)).toList();
        debugPrint('Vocabulary: loaded ${_words.length} words from DB');
      } else {
        _words = await JsonLoader.loadWords();
        debugPrint('Vocabulary: DB empty, loaded ${_words.length} words from JSON');
      }
    } catch (e) {
      debugPrint('Vocabulary: DB load failed ($e), falling back to JSON');
      _words = await JsonLoader.loadWords();
    }
    _filteredWords = _words;
    setState(() => _isLoading = false);
    _animationController.forward();
  }

  Future<void> _loadBookmarks() async {
    try {
      final records = await _dbHelper.query(
        'word_bookmarks',
        where: 'user_id = ?',
        whereArgs: [1],
      );
      setState(() {
        _bookmarkedWordIds = records.map((r) => r['word_id'] as int).toSet();
      });
    } catch (e) {
      // 表可能不存在，忽略
    }
  }

  Future<void> _toggleBookmark(Word word) async {
    try {
      if (_bookmarkedWordIds.contains(word.id)) {
        await _dbHelper.delete(
          'word_bookmarks',
          where: 'word_id = ? AND user_id = ?',
          whereArgs: [word.id, 1],
        );
        setState(() => _bookmarkedWordIds.remove(word.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('已从生词本移除'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        await _dbHelper.insert('word_bookmarks', {
          'word_id': word.id,
          'user_id': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        setState(() => _bookmarkedWordIds.add(word.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('已加入生词本'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _filterByLevel(String level) {
    setState(() {
      _selectedLevel = level;
      if (level == '全部') {
        _filteredWords = _words;
      } else {
        _filteredWords = _words.where((w) => w.level == level).toList();
      }
    });
  }

  void _searchWords(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredWords = _selectedLevel == '全部'
            ? _words
            : _words.where((w) => w.level == _selectedLevel).toList();
      } else {
        _filteredWords = _words.where((w) {
          return w.word.toLowerCase().contains(query.toLowerCase()) ||
              w.meaning.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildGradientHeader(isDark),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildSearchBar(isDark),
                  _buildFilterChips(isDark),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _primaryColor)),
                )
              : _filteredWords.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: Text('没有找到匹配的单词')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildWordCard(_filteredWords[index], isDark, index);
                          },
                          childCount: _filteredWords.length,
                        ),
                      ),
                    ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildFloatingButton(),
    );
  }

  Widget _buildGradientHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF0B0F19) : _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1a1f2e), const Color(0xFF0B0F19)]
                  : [_primaryColor, _primaryLight],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '词汇记忆',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Row(
                        children: [
                          _buildHeaderIconButton(
                            Icons.bookmark_rounded,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const WordBookPage()),
                              ).then((_) => _loadBookmarks());
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIconButton(
                            Icons.upload_file_rounded,
                            () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PdfImportPage(
                                      initialType: ImportType.vocabulary),
                                ),
                              );
                              if (mounted) {
                                await _loadWords();
                                await _loadBookmarks();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIconButton(
                            Icons.bar_chart_rounded,
                            () => _showStudyStats(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '共 ${_words.length} 个单词 · 今日目标 $_dailyGoal 词',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildQuickStat(
                        Icons.menu_book_rounded,
                        '${_words.length}',
                        '总词汇',
                      ),
                      const SizedBox(width: 16),
                      _buildQuickStat(
                        Icons.bookmark_rounded,
                        '${_bookmarkedWordIds.length}',
                        '生词本',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索单词...',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[500]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    _searchWords('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1a1f2e) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        onChanged: _searchWords,
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['全部', '高频核心词', '中频词', '低频词', '超纲词'];
    final colors = [
      _primaryColor,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: List.generate(filters.length, (index) {
          final label = filters[index];
          final isSelected = _selectedLevel == label;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) => _filterByLevel(label),
                backgroundColor: isDark ? const Color(0xFF1a1f2e) : Colors.white,
                selectedColor: colors[index].withOpacity(0.15),
                checkmarkColor: colors[index],
                labelStyle: TextStyle(
                  color: isSelected ? colors[index] : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? colors[index].withOpacity(0.3) : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWordCard(Word word, bool isDark, int index) {
    final isBookmarked = _bookmarkedWordIds.contains(word.id);
    final isSelected = _selectedWordId == word.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1f2e) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? _primaryColor.withOpacity(0.3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _selectedWordId = word.id);
            _showWordDetail(word);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.text_fields_rounded,
                        size: 18,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        word.word,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                    Material(
                      color: isBookmarked
                          ? Colors.red.withOpacity(0.1)
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _toggleBookmark(word),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 20,
                            color: isBookmarked ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[500]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (word.meaning.isNotEmpty)
                      Text(
                        word.meaning,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[300] : Colors.black87,
                            ),
                        softWrap: true,
                      ),
                    if (word.phoneticUk.isNotEmpty)
                      Text(
                        '  ${word.phoneticUk}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _primaryColor.withOpacity(0.7),
                            ),
                      ),
                  ],
                ),
                if (word.level.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLevelColor(word.level).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word.level,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getLevelColor(word.level),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case '高频核心词':
        return Colors.orange;
      case '中频词':
        return Colors.blue;
      case '低频词':
        return Colors.green;
      case '超纲词':
        return Colors.purple;
      default:
        return _primaryColor;
    }
  }

  Widget _buildFloatingButton() {
    return FloatingActionButton.extended(
      onPressed: _startTodayStudy,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      highlightElevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text('开始背诵 ($_dailyGoal词)'),
    );
  }

  void _showWordDetail(Word word) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBookmarked = _bookmarkedWordIds.contains(word.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1a1f2e) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
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
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${word.phoneticUk} | ${word.phoneticUs}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection('释义', word.meaning, Icons.translate_rounded, _primaryColor, isDark),
                    _buildDetailSection('例句', word.example, Icons.format_quote_rounded, Colors.blue, isDark),
                    _buildDetailSection('例句翻译', word.exampleTranslation, Icons.translate_rounded, Colors.teal, isDark),
                    _buildDetailSection('常见搭配', word.collocation, Icons.link_rounded, Colors.orange, isDark),
                    _buildDetailSection('级别', word.level, Icons.flag_rounded, Colors.green, isDark),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAiExplanation(word);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                            label: const Text('AI讲解'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _toggleBookmark(word);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isBookmarked
                                  ? Colors.red.withOpacity(0.1)
                                  : (isDark ? const Color(0xFF2a2f3e) : Colors.grey[100]),
                              foregroundColor: isBookmarked ? Colors.red : (isDark ? Colors.white : Colors.black87),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            icon: Icon(
                              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                              size: 20,
                            ),
                            label: Text(isBookmarked ? '移出生词本' : '加入生词本'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon, Color color, bool isDark) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
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
          ],
        ),
      ),
    );
  }

  void _showAiExplanation(Word word) {
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
              aiProvider.explainWord(word.word).then((data) {
                setState(() {
                  result = data;
                  loading = false;
                });
              }).catchError((e) {
                setState(() {
                  error = e.toString();
                  loading = false;
                });
              });
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1a1f2e)
                  : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: _primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('AI讲解: ${word.word}'),
                ],
              ),
              content: loading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: _primaryColor)),
                    )
                  : error != null
                      ? Text('错误: $error')
                      : SingleChildScrollView(child: Text(result ?? '')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStudyStats() {
    final studyProvider = context.read<StudyProvider>();
    final progress = studyProvider.studyProgress;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1a1f2e) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('学习统计'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem('未学单词', '${progress['not_learned'] ?? 0}', Colors.grey),
              _buildStatItem('学习中', '${progress['learning'] ?? 0}', Colors.blue),
              _buildStatItem('已掌握', '${progress['mastered'] ?? 0}', Colors.green),
              _buildStatItem('已遗忘', '${progress['forgotten'] ?? 0}', Colors.red),
              const Divider(),
              _buildStatItem('今日已学', '${studyProvider.todayStudyCount}', _primaryColor),
              _buildStatItem('待复习', '${studyProvider.todayReviewCount}', Colors.orange),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
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
              Text(label),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _loadDailyGoal() async {
    try {
      final settings = await _dbHelper.query('user_settings', where: 'user_id = ?', whereArgs: [1]);
      if (settings.isNotEmpty) {
        setState(() => _dailyGoal = settings.first['daily_word_count'] as int? ?? 10);
      }
    } catch (_) {}
  }

  Future<void> _startTodayStudy() async {
    final studyProvider = context.read<StudyProvider>();
    await _loadDailyGoal();
    await studyProvider.loadTodayWords(_dailyGoal);

    if (!mounted) return;

    if (studyProvider.todayWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无需要学习的单词，都已完成！')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WordStudyPage()),
    );

    if (mounted) {
      studyProvider.loadTodayData();
    }
  }
}
