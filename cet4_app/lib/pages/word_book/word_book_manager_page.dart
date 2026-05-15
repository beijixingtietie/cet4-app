import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../database/db_helper.dart';
import '../../models/word.dart';

/// 词书数据模型
class WordBook {
  final int id;
  final String name;
  final String source; // 'builtin' 或 'custom'
  final String? url;
  final int wordCount;
  final DateTime addedAt;

  WordBook({
    required this.id,
    required this.name,
    required this.source,
    this.url,
    required this.wordCount,
    required this.addedAt,
  });

  factory WordBook.fromJson(Map<String, dynamic> json) {
    return WordBook(
      id: json['id'] as int,
      name: json['name'] as String,
      source: json['source'] as String,
      url: json['url'] as String?,
      wordCount: json['word_count'] as int,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source': source,
      'url': url,
      'word_count': wordCount,
      'added_at': addedAt.toIso8601String(),
    };
  }
}

/// 词书持久化存储
class WordBookStorage {
  static const _key = 'word_books';

  static Future<List<WordBook>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) {
      // 首次使用，创建默认内置词书
      final builtin = WordBook(
        id: 0,
        name: 'CET4 核心词汇',
        source: 'builtin',
        url: null,
        wordCount: 0, // 将在显示时动态获取
        addedAt: DateTime.now(),
      );
      await saveBooks([builtin]);
      return [builtin];
    }
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => WordBook.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBooks(List<WordBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_key, json);
  }
}

class WordBookManagerPage extends StatefulWidget {
  const WordBookManagerPage({super.key});

  @override
  State<WordBookManagerPage> createState() => _WordBookManagerPageState();
}

class _WordBookManagerPageState extends State<WordBookManagerPage> {
  final DbHelper _dbHelper = DbHelper();
  List<WordBook> _books = [];
  int _totalWords = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);

    try {
      _books = await WordBookStorage.loadBooks();

      // 更新内置词书的单词数量
      final allWords = await _dbHelper.query('words');
      _totalWords = allWords.length;

      // 更新内置词书的 wordCount
      for (int i = 0; i < _books.length; i++) {
        if (_books[i].source == 'builtin') {
          _books[i] = WordBook(
            id: _books[i].id,
            name: _books[i].name,
            source: _books[i].source,
            url: _books[i].url,
            wordCount: _totalWords,
            addedAt: _books[i].addedAt,
          );
        }
      }
      await WordBookStorage.saveBooks(_books);
    } catch (e) {
      debugPrint('加载词书失败: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _showAddBookDialog() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加词书'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '词书名称',
                    hintText: '例如: 考研高频词汇',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'JSON 数据 URL',
                    hintText: 'https://example.com/words.json',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'URL 应返回符合 Word 模型的 JSON 数组',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('下载'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) return;

    final name = nameController.text.trim();
    final url = urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写词书名称和URL')),
        );
      }
      return;
    }

    await _downloadAndImportWords(name, url);
  }

  Future<void> _downloadAndImportWords(String name, String url) async {
    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 30);

      final response = await dio.get(url);

      if (response.statusCode != 200) {
        throw Exception('服务器返回 ${response.statusCode}');
      }

      final data = response.data;
      if (data is! List) {
        throw Exception('数据格式不正确，需要 JSON 数组');
      }

      int imported = 0;
      int skipped = 0;

      // 获取已有单词用于去重
      final existingWords = await _dbHelper.query('words');
      final existingWordTexts = existingWords
          .map((w) => (w['word'] as String).toLowerCase())
          .toSet();

      final newId = _books.isEmpty ? 1 : _books.map((b) => b.id).reduce((a, b) => a > b ? a : b) + 1;

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;

        try {
          final word = Word(
            id: item['id'] as int? ?? DateTime.now().millisecondsSinceEpoch + imported,
            word: item['word'] as String? ?? '',
            phoneticUk: item['phonetic_uk'] as String? ?? '',
            phoneticUs: item['phonetic_us'] as String? ?? '',
            audioUk: item['audio_uk'] as String? ?? '',
            audioUs: item['audio_us'] as String? ?? '',
            type: item['type'] as String? ?? '',
            meaning: item['meaning'] as String? ?? '',
            example: item['example'] as String? ?? '',
            exampleTranslation: item['example_translation'] as String? ?? '',
            collocation: item['collocation'] as String? ?? '',
            level: item['level'] as String? ?? '自定义',
          );

          if (word.word.isEmpty || word.meaning.isEmpty) {
            skipped++;
            continue;
          }

          // 去重
          if (existingWordTexts.contains(word.word.toLowerCase())) {
            skipped++;
            continue;
          }

          await _dbHelper.insert('words', word.toJson());
          existingWordTexts.add(word.word.toLowerCase());
          imported++;
        } catch (_) {
          skipped++;
        }
      }

      // 保存词书记录
      final book = WordBook(
        id: newId,
        name: name,
        source: 'custom',
        url: url,
        wordCount: imported,
        addedAt: DateTime.now(),
      );
      _books.add(book);
      await WordBookStorage.saveBooks(_books);

      // 关闭加载对话框
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 $imported 个新单词，跳过 $skipped 个重复/无效单词'),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      await _loadBooks();
    } catch (e) {
      // 关闭加载对话框
      if (mounted) Navigator.pop(context);

      String errorMsg = '下载失败';
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            errorMsg = '连接超时，请检查网络和URL';
            break;
          case DioExceptionType.badResponse:
            errorMsg = '服务器错误: ${e.response?.statusCode}';
            break;
          default:
            errorMsg = '无法访问URL: ${e.message}';
        }
      } else {
        errorMsg = e.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  Future<void> _deleteBook(WordBook book) async {
    if (book.source == 'builtin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内置词书不可删除')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除词书'),
        content: Text('确定要删除"${book.name}"吗？已导入的单词不会从词库中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _books.removeWhere((b) => b.id == book.id);
      await WordBookStorage.saveBooks(_books);
      await _loadBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除"${book.name}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词书管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddBookDialog,
            tooltip: '添加词书',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAutoAllocateCard(),
                const SizedBox(height: 12),
                if (_books.isEmpty) _buildEmptyState() else ..._books.map(_buildBookCard),
              ],
            ),
    );
  }

  Widget _buildAutoAllocateCard() {
    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  '智能分配',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _getDailyGoal(),
              builder: (context, snapshot) {
                final goal = snapshot.data ?? 10;
                return Text(
                  '根据你的每日目标（$goal 词），自动从词库中随机选取未学习的单词',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _autoAllocateWords,
                icon: const Icon(Icons.shuffle),
                label: const Text('分配今日单词'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getDailyGoal() async {
    try {
      final settings = await _dbHelper.query('user_settings', where: 'user_id = ?', whereArgs: [1]);
      if (settings.isNotEmpty) {
        return settings.first['daily_word_count'] as int? ?? 10;
      }
    } catch (_) {}
    return 10;
  }

  Future<void> _autoAllocateWords() async {
    if (!mounted) return;
    final goal = await _getDailyGoal();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 获取未学习单词，按目标数量随机选取
      final unlearned = await _dbHelper.rawQuery('''
        SELECT w.* FROM words w
        LEFT JOIN study_records sr ON w.id = sr.word_id AND sr.user_id = 1
        WHERE sr.id IS NULL OR sr.status = '未学'
        ORDER BY RANDOM()
        LIMIT ?
      ''', [goal]);

      if (mounted) Navigator.pop(context); // close loading

      if (!mounted) return;

      if (unlearned.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词库中没有未学习的单词了！')),
        );
        return;
      }

      // 展示分配结果
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('今日单词 (${unlearned.length}/$goal)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: unlearned.length,
              itemBuilder: (_, i) {
                final w = unlearned[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue[100],
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(
                    w['word'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    w['meaning'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // 跳转到词汇页面开始学习
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('单词已就绪！请前往「背单词」页面开始学习'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('开始学习'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分配失败: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有词书',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加在线词书',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(WordBook book) {
    final isBuiltin = book.source == 'builtin';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isBuiltin ? Colors.blue[100] : Colors.green[100],
          child: Icon(
            isBuiltin ? Icons.school : Icons.language,
            color: isBuiltin ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(
          book.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isBuiltin
              ? '内置词库 · ${book.wordCount} 个单词'
              : '${book.wordCount} 个单词 · ${book.url ?? ""}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isBuiltin
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteBook(book),
                tooltip: '删除',
              ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${book.name}: ${book.wordCount} 个单词'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
