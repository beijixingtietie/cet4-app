import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/db_helper.dart';
import '../../models/word.dart';
import '../../provider/ai_provider.dart';
import '../../provider/study_provider.dart';
import '../vocabulary/word_study_page.dart';

class WordBookPage extends StatefulWidget {
  const WordBookPage({super.key});

  @override
  State<WordBookPage> createState() => _WordBookPageState();
}

class _WordBookPageState extends State<WordBookPage> {
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _searchController = TextEditingController();
  List<Word> _allBookmarkedWords = [];
  List<Word> _filteredWords = [];
  List<Map<String, dynamic>> _bookmarkRows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarkedWords();
  }

  Future<void> _loadBookmarkedWords() async {
    setState(() => _isLoading = true);
    try {
      final wqRows = await _dbHelper.query(
        'word_bookmarks',
        where: 'user_id = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );

      if (wqRows.isEmpty) {
        _allBookmarkedWords = [];
        _filteredWords = [];
        _bookmarkRows = [];
        setState(() => _isLoading = false);
        return;
      }

      _bookmarkRows = wqRows;
      final wordIds = wqRows.map((r) => r['word_id'] as int).toSet();

      // 从 words 表查所有匹配的单词
      final allWords = await _dbHelper.query('words');
      final matchedRows = allWords.where((w) => wordIds.contains(w['id'] as int)).toList();

      // 按书签创建时间排序（保持用户收藏顺序）
      final idOrder = wqRows.map((r) => r['word_id'] as int).toList();
      matchedRows.sort((a, b) {
        final aIdx = idOrder.indexOf(a['id'] as int);
        final bIdx = idOrder.indexOf(b['id'] as int);
        return aIdx.compareTo(bIdx);
      });

      _allBookmarkedWords = matchedRows.map((r) => Word.fromDbMap(r)).toList();
      _filteredWords = _allBookmarkedWords;
    } catch (e) {
      _allBookmarkedWords = [];
      _filteredWords = [];
      _bookmarkRows = [];
    }
    setState(() => _isLoading = false);
  }

  void _searchWords(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredWords = _allBookmarkedWords;
      } else {
        _filteredWords = _allBookmarkedWords.where((w) =>
          w.word.toLowerCase().contains(query.toLowerCase()) ||
          w.meaning.contains(query)
        ).toList();
      }
    });
  }

  Future<bool> _removeBookmark(Word word) async {
    try {
      await _dbHelper.delete(
        'word_bookmarks',
        where: 'word_id = ? AND user_id = ?',
        whereArgs: [word.id, 1],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _undoRemove(Map<String, dynamic> bookmarkRow) async {
    try {
      await _dbHelper.insert('word_bookmarks', bookmarkRow);
    } catch (_) {}
  }

  void _showWordDetail(Word word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      word.word,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${word.phoneticUk} | ${word.phoneticUs}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailSection('释义', word.meaning),
                  _buildDetailSection('例句', word.example),
                  _buildDetailSection('例句翻译', word.exampleTranslation),
                  _buildDetailSection('常见搭配', word.collocation),
                  _buildDetailSection('级别', word.level),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAiExplanation(word);
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('AI讲解'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _removeBookmark(word);
                          _loadBookmarkedWords();
                        },
                        icon: const Icon(Icons.bookmark_remove),
                        label: const Text('移出生词本'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 15)),
        ],
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
              title: Text('AI讲解: ${word.word}'),
              content: loading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : error != null
                      ? Text('错误: $error')
                      : SingleChildScrollView(child: Text(result ?? '')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startStudyFromBookmarks() async {
    final studyProvider = context.read<StudyProvider>();
    final words = _allBookmarkedWords;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生词本为空，请先收藏单词')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordStudyPage.withWords(words),
      ),
    );

    if (mounted) {
      studyProvider.loadTodayData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生词本'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _allBookmarkedWords.isEmpty
                ? null
                : _startStudyFromBookmarks,
            tooltip: '从生词本开始学习',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索生词...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchWords('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchWords,
            ),
          ),
          // 内容区
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? '没有找到匹配的生词'
                                  : '生词本为空',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? '试试其他关键词'
                                  : '在词汇页面点击 ♡ 收藏单词即可加入生词本',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        itemCount: _filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = _filteredWords[index];
                          final bookmarkRow = _bookmarkRows.firstWhere(
                            (r) => r['word_id'] == word.id,
                            orElse: () => <String, dynamic>{},
                          );
                          return _buildWordCard(word, bookmarkRow);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(Word word, Map<String, dynamic> bookmarkRow) {
    return Dismissible(
      key: Key('bookmark_${word.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final removedRow = Map<String, dynamic>.from(bookmarkRow);
        final success = await _removeBookmark(word);
        if (!success) return false;

        setState(() {
          _allBookmarkedWords.removeWhere((w) => w.id == word.id);
          _filteredWords.removeWhere((w) => w.id == word.id);
          _bookmarkRows.removeWhere((r) => r['word_id'] == word.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已移除「${word.word}」'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  await _undoRemove(removedRow);
                  _loadBookmarkedWords();
                },
              ),
            ),
          );
        }
        return true;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _showWordDetail(word),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.bookmark, size: 20, color: Colors.red.shade400),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(word.meaning, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  if (word.phoneticUk.isNotEmpty)
                    Text('  ${word.phoneticUk}', style: TextStyle(fontSize: 12, color: Colors.blue.shade300)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
