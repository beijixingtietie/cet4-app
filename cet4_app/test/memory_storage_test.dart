import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cet4_app/database/db_helper.dart';
import 'package:cet4_app/database/memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryStorage sharding', () {
    late DbHelper dbHelper;
    late MemoryStorage memory;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DbHelper();
      memory = MemoryStorage();
      await memory.clearAll();
    });

    test('words are sharded by first letter', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'apple', 'meaning': '苹果', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'banana', 'meaning': '香蕉', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 3, 'word': 'abstract', 'meaning': '抽象的', 'type': 'adj.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final stats = memory.getShardStats();
      expect(stats['_a']!, 2);
      expect(stats['_b']!, 1);
    });

    test('query all words returns complete result', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': '测试', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final all = await dbHelper.query('words');
      expect(all.length, 1);
    });

    test('index cache enables fast word lookup', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'hello', 'meaning': '你好', 'type': 'interj.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      // 索引应在查询时自动建立
      final result = await dbHelper.query('words', where: 'word = ?', whereArgs: ['hello']);
      expect(result.length, 1);
      expect(result.first['meaning'], '你好');
    });

    test('batchInsert correctly shards words', () async {
      await dbHelper.batchInsert('words', [
        {
          'id': 1, 'word': 'cat', 'meaning': '猫', 'type': 'n.',
          'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
          'example': '', 'example_translation': '', 'collocation': '', 'level': '',
        },
        {
          'id': 2, 'word': 'dog', 'meaning': '狗', 'type': 'n.',
          'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
          'example': '', 'example_translation': '', 'collocation': '', 'level': '',
        },
        {
          'id': 3, 'word': 'zebra', 'meaning': '斑马', 'type': 'n.',
          'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
          'example': '', 'example_translation': '', 'collocation': '', 'level': '',
        },
      ]);

      final stats = memory.getShardStats();
      expect(stats['_c']!, 1);
      expect(stats['_d']!, 1);
      expect(stats['_z']!, 1);

      final all = await dbHelper.query('words');
      expect(all.length, 3);
    });

    test('delete from words table works across shards', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'keep', 'meaning': '保留', 'type': 'v.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'delete', 'meaning': '删除', 'type': 'v.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      await dbHelper.delete('words', where: 'word = ?', whereArgs: ['delete']);
      final remaining = await dbHelper.query('words');
      expect(remaining.length, 1);
      expect(remaining.first['word'], 'keep');
    });
  });
}
