import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cet4_app/database/db_helper.dart';
import 'package:cet4_app/database/memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordBook DB queries', () {
    late DbHelper dbHelper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DbHelper();
      // 强制重建 MemoryStorage 状态
      final memory = MemoryStorage();
      await memory.clearAll();
    });

    test('insert and query bookmarks with word matching', () async {
      // 插入测试单词
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': '测试', 'type': 'n.',
        'phonetic_uk': '/test/', 'phonetic_us': '/test/',
        'audio_uk': '', 'audio_us': '', 'example': 'This is a test.',
        'example_translation': '这是一个测试。', 'collocation': 'run a test', 'level': '高频核心词',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'abandon', 'meaning': '放弃', 'type': 'v.',
        'phonetic_uk': '/əˈbændən/', 'phonetic_us': '/əˈbændən/',
        'audio_uk': '', 'audio_us': '', 'example': 'They abandoned the plan.',
        'example_translation': '他们放弃了计划。', 'collocation': 'abandon oneself to', 'level': '高频核心词',
      });

      // 插入书签
      await dbHelper.insert('word_bookmarks', {
        'id': 1, 'word_id': 1, 'user_id': 1, 'created_at': '2026-05-01T00:00:00.000',
      });
      await dbHelper.insert('word_bookmarks', {
        'id': 2, 'word_id': 2, 'user_id': 1, 'created_at': '2026-05-02T00:00:00.000',
      });

      // 查询书签
      final bookmarks = await dbHelper.query('word_bookmarks', where: 'user_id = ?', whereArgs: [1]);
      expect(bookmarks.length, 2);

      // 通过书签ID匹配单词
      final wordIds = bookmarks.map((r) => r['word_id'] as int).toSet();
      expect(wordIds, {1, 2});

      final allWords = await dbHelper.query('words');
      final bookmarked = allWords.where((w) => wordIds.contains(w['id'] as int)).toList();
      expect(bookmarked.length, 2);
    });

    test('remove bookmark should not affect words table', () async {
      // 插入数据
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': '测试', 'type': 'n.',
        'phonetic_uk': '/test/', 'phonetic_us': '/test/',
        'audio_uk': '', 'audio_us': '', 'example': 'This is a test.',
        'example_translation': '这是一个测试。', 'collocation': 'run a test', 'level': '高频核心词',
      });
      await dbHelper.insert('word_bookmarks', {
        'id': 1, 'word_id': 1, 'user_id': 1, 'created_at': '2026-05-01T00:00:00.000',
      });

      // 删除书签
      await dbHelper.delete('word_bookmarks', where: 'word_id = ? AND user_id = ?', whereArgs: [1, 1]);

      final remaining = await dbHelper.query('word_bookmarks', where: 'user_id = ?', whereArgs: [1]);
      expect(remaining.length, 0);

      // words 表不受影响
      final words = await dbHelper.query('words');
      expect(words.length, 1);
    });

    test('undo remove by re-inserting bookmark', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': '测试', 'type': 'n.',
        'phonetic_uk': '/test/', 'phonetic_us': '/test/',
        'audio_uk': '', 'audio_us': '', 'example': 'This is a test.',
        'example_translation': '这是一个测试。', 'collocation': 'run a test', 'level': '高频核心词',
      });
      await dbHelper.insert('word_bookmarks', {
        'id': 1, 'word_id': 1, 'user_id': 1, 'created_at': '2026-05-01T00:00:00.000',
      });

      // 删除
      await dbHelper.delete('word_bookmarks', where: 'word_id = ? AND user_id = ?', whereArgs: [1, 1]);
      var remaining = await dbHelper.query('word_bookmarks', where: 'user_id = ?', whereArgs: [1]);
      expect(remaining.length, 0);

      // 撤销：重新插入
      await dbHelper.insert('word_bookmarks', {
        'id': 1, 'word_id': 1, 'user_id': 1, 'created_at': '2026-05-01T00:00:00.000',
      });
      remaining = await dbHelper.query('word_bookmarks', where: 'user_id = ?', whereArgs: [1]);
      expect(remaining.length, 1);
    });
  });
}
