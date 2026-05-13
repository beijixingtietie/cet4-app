import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cet4_app/database/db_helper.dart';
import 'package:cet4_app/database/memory_storage.dart';
import 'package:cet4_app/utils/agent_executor.dart';
import 'package:cet4_app/provider/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentExecutor', () {
    late DbHelper dbHelper;
    late AgentExecutor executor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DbHelper();
      await MemoryStorage().clearAll();
      executor = AgentExecutor();
    });

    test('tryParseCommand extracts JSON from plain text', () {
      final text = '{"action":"update_word","params":{"target":"test","field":"meaning","newValue":"测试"},"confirmMessage":"确认"}';
      final cmd = AgentExecutor.tryParseCommand(text);
      expect(cmd, isNotNull);
      expect(cmd!['action'], 'update_word');
      expect(cmd['params']['target'], 'test');
    });

    test('tryParseCommand extracts JSON from markdown code block', () {
      final text = '```json\n{"action":"delete_word","params":{"target":"hello"},"confirmMessage":"删除?"}\n```';
      final cmd = AgentExecutor.tryParseCommand(text);
      expect(cmd, isNotNull);
      expect(cmd!['action'], 'delete_word');
    });

    test('tryParseCommand returns null for plain text', () {
      final text = 'This is not a JSON command.';
      final cmd = AgentExecutor.tryParseCommand(text);
      expect(cmd, isNull);
    });

    test('execute update_word updates DB and returns success', () async {
      // 插入测试单词
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': 'old', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final cmd = {
        'action': 'update_word',
        'params': {'target': 'test', 'field': 'meaning', 'newValue': 'new'},
        'confirmMessage': 'OK',
      };

      final result = await executor.execute(cmd);
      expect(result, contains('已成功'));

      // 验证数据库已更新
      final words = await dbHelper.query('words', where: 'word = ?', whereArgs: ['test']);
      expect(words.first['meaning'], 'new');
    });

    test('execute add_word inserts and logs', () async {
      final cmd = {
        'action': 'add_word',
        'params': {'word': 'newword', 'meaning': '新词', 'type': 'n.'},
        'confirmMessage': 'OK',
      };

      final result = await executor.execute(cmd);
      expect(result, contains('已成功添加'));

      final words = await dbHelper.query('words', where: 'word = ?', whereArgs: ['newword']);
      expect(words.length, 1);
    });

    test('audit log is created after execution', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'logtest', 'meaning': 'test', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final cmd = {
        'action': 'update_word',
        'params': {'target': 'logtest', 'field': 'meaning', 'newValue': 'logged'},
        'confirmMessage': 'OK',
      };

      await executor.execute(cmd);

      final logs = await dbHelper.query('agent_logs');
      expect(logs.length, 1);
      expect(logs.first['action'], 'update_word');
    });

    test('field validation rejects empty required fields', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'validate', 'meaning': 'test', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      // 空值
      final cmd = {
        'action': 'update_word',
        'params': {'target': 'validate', 'field': 'meaning', 'newValue': ''},
        'confirmMessage': 'OK',
      };

      final result = await executor.execute(cmd);
      expect(result, contains('ERROR'));
    });

    test('batch_update_words updates multiple words at once', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'apple', 'meaning': 'old1', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'banana', 'meaning': 'old2', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final cmd = {
        'action': 'batch_update_words',
        'params': {
          'words': [
            {'target': 'apple', 'field': 'meaning', 'newValue': '苹果'},
            {'target': 'banana', 'field': 'type', 'newValue': 'n. & adj.'},
          ],
        },
        'confirmMessage': '批量更新 2 个单词',
      };

      final result = await executor.execute(cmd);
      expect(result, contains('成功更新 2 个字段'));

      final apple = await dbHelper.query('words', where: 'word = ?', whereArgs: ['apple']);
      expect(apple.first['meaning'], '苹果');

      final banana = await dbHelper.query('words', where: 'word = ?', whereArgs: ['banana']);
      expect(banana.first['type'], 'n. & adj.');
    });

    test('list_words returns word list', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'apple', 'meaning': '苹果', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': 'I like apples.', 'example_translation': '我喜欢苹果。', 'collocation': 'apple pie', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'banana', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final cmd = {
        'action': 'list_words',
        'params': {'filter': 'all', 'limit': 10},
        'confirmMessage': '查询',
      };
      final result = await executor.execute(cmd);
      expect(result, contains('apple'));
      expect(result, contains('banana'));
      expect(result, contains('2 个单词'));
    });

    test('list_words filter empty_fields works', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'full', 'meaning': 'x', 'type': 'x',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': 'x', 'example_translation': 'x', 'collocation': 'x', 'level': '',
      });
      await dbHelper.insert('words', {
        'id': 2, 'word': 'empty', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final cmd = {
        'action': 'list_words',
        'params': {'filter': 'empty_fields', 'limit': 10},
        'confirmMessage': '查询',
      };
      final result = await executor.execute(cmd);
      expect(result, contains('empty'));
      expect(result, contains('释义空'));
      expect(result, isNot(contains('full ['))); // full 不应该出现在空字段列表
    });

    test('batch_update_words single word multi-field update works', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'account', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      // 用 batch 更新同一个单词的 5 个字段
      final cmd = {
        'action': 'batch_update_words',
        'params': {
          'words': [
            {'target': 'account', 'field': 'type', 'newValue': 'n.'},
            {'target': 'account', 'field': 'meaning', 'newValue': '账户'},
            {'target': 'account', 'field': 'example', 'newValue': 'I have a bank account.'},
            {'target': 'account', 'field': 'example_translation', 'newValue': '我有一个银行账户。'},
            {'target': 'account', 'field': 'collocation', 'newValue': 'bank account'},
          ],
        },
        'confirmMessage': '填充account的5个字段',
      };

      final result = await executor.execute(cmd);
      expect(result, contains('成功更新 5 个字段'));

      final words = await dbHelper.query('words', where: 'word = ?', whereArgs: ['account']);
      final w = words.first;
      expect(w['type'], 'n.');
      expect(w['meaning'], '账户');
      expect(w['example'], 'I have a bank account.');
      expect(w['example_translation'], '我有一个银行账户。');
      expect(w['collocation'], 'bank account');
    });

    test('batch_update_words reports skipped items', () async {
      await dbHelper.insert('words', {
        'id': 1, 'word': 'test', 'meaning': 'old', 'type': 'n.',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });

      final cmd = {
        'action': 'batch_update_words',
        'params': {
          'words': [
            {'target': 'test', 'field': 'meaning', 'newValue': 'ok'},
            {'target': 'ghost', 'field': 'meaning', 'newValue': 'x'},  // 不存在
            {'target': 'test', 'field': 'meaning', 'newValue': ''},  // 空值
          ],
        },
        'confirmMessage': '批量更新',
      };

      final result = await executor.execute(cmd);
      expect(result, contains('成功更新 1 个字段'));
      expect(result, contains('跳过 2 个'));
    });
  });
}
