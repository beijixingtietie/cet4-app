import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cet4_app/database/db_helper.dart';
import 'package:cet4_app/database/memory_storage.dart';
import 'package:cet4_app/utils/batch_word_filler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatchWordFiller', () {
    late DbHelper dbHelper;
    late BatchWordFiller filler;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DbHelper();
      await MemoryStorage().clearAll();
      filler = BatchWordFiller();
    });

    test('init loads all words from DB', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'apple', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'banana', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final msg = await filler.init();
      expect(msg, contains('2 个单词'));
      expect(filler.totalWords, 2);
    });

    test('nextBatch returns words in chunks of batchSize', () async {
      // 插入 60 个单词（50 + 10 = 2 批）
      for (int i = 0; i < 60; i++) {
        await dbHelper.insert('words', {
          'id': i + 1,
          'word': 'word$i',
          'meaning': '', 'type': '',
          'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
          'example': '', 'example_translation': '', 'collocation': '', 'level': '',
        });
      }

      await filler.init();
      expect(filler.totalBatches, 2); // 60/50 = 2 batches

      final batch1 = filler.nextBatch();
      expect(batch1, isNotNull);
      expect(batch1!.length, 50);
      filler.recordBatchResult(50 * 5, 0, []);

      final batch2 = filler.nextBatch();
      expect(batch2, isNotNull);
      expect(batch2!.length, 10);
      filler.recordBatchResult(10 * 5, 0, []);

      final batch3 = filler.nextBatch();
      expect(batch3, isNull);
      expect(filler.isRunning, false);
    });

    test('progress message reflects current state', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      await filler.init();
      expect(filler.progressMessage, contains('已处理 0/1'));

      filler.nextBatch();
      filler.recordBatchResult(5, 0, []);
      expect(filler.progressMessage, contains('已处理 1/1'));
      expect(filler.progressMessage, contains('即将处理第 1/1 批'));
    });

    test('completionMessage shows summary', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      await filler.init();
      filler.nextBatch();
      filler.recordBatchResult(5, 0, []);

      final msg = filler.completionMessage;
      expect(msg, contains('所有批次处理完成'));
    });

    test('failed words are tracked', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'bad', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      await filler.init();
      filler.nextBatch();
      filler.recordBatchResult(3, 2, ['bad']);

      expect(filler.failedWords, ['bad']);
    });

    test('buildBatchPrompt includes words', () {
      final prompt = filler.buildBatchPrompt(['apple', 'banana']);
      expect(prompt, contains('apple'));
      expect(prompt, contains('banana'));
      expect(prompt, contains('batch_update_words'));
      expect(prompt, contains('type'));
      expect(prompt, contains('meaning'));
    });
  });
}
