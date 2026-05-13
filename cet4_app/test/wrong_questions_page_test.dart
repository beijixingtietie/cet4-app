import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cet4_app/database/db_helper.dart';
import 'package:cet4_app/database/memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WrongQuestions DB queries', () {
    late DbHelper dbHelper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DbHelper();
      await MemoryStorage().clearAll();
    });

    Future<void> seedTestData() async {
      // 插入题目
      await dbHelper.insert('questions', {
        'id': 1, 'type': '听力', 'year': '2024',
        'content': 'What is the main idea of the passage?',
        'passage': '', 'options': '["A. Climate change","B. Technology","C. Education","D. Health"]',
        'answer': 'A', 'explanation': '文章主要讨论气候变化。', 'audio_url': '',
      });
      await dbHelper.insert('questions', {
        'id': 2, 'type': '仔细阅读', 'year': '2023',
        'content': 'The author suggests that...',
        'passage': '', 'options': '["A. Option A","B. Option B","C. Option C","D. Option D"]',
        'answer': 'B', 'explanation': '作者建议选择B。', 'audio_url': '',
      });
      await dbHelper.insert('questions', {
        'id': 3, 'type': '翻译', 'year': '2022',
        'content': 'Translate: China has a long history.',
        'passage': '', 'options': '',
        'answer': '中国拥有悠久的历史。', 'explanation': '注意时态和词汇选择。', 'audio_url': '',
      });

      // 插入错题记录
      await dbHelper.insert('wrong_questions', {
        'id': 1, 'question_id': 1, 'user_id': 1, 'user_answer': 'B', 'add_time': '2026-05-01T00:00:00.000',
      });
      await dbHelper.insert('wrong_questions', {
        'id': 2, 'question_id': 2, 'user_id': 1, 'user_answer': 'C', 'add_time': '2026-05-02T00:00:00.000',
      });
    }

    test('should load wrong questions with question data', () async {
      await seedTestData();

      final wq = await dbHelper.query('wrong_questions', where: 'user_id = ?', whereArgs: [1]);
      expect(wq.length, 2);

      final qIds = wq.map((r) => r['question_id'] as int).toSet();
      final allQ = await dbHelper.query('questions');
      final matched = allQ.where((q) => qIds.contains(q['id'] as int)).toList();
      expect(matched.length, 2);
    });

    test('should group questions by type', () async {
      await seedTestData();

      final wq = await dbHelper.query('wrong_questions', where: 'user_id = ?', whereArgs: [1]);
      final qIds = wq.map((r) => r['question_id'] as int).toSet();
      final allQ = await dbHelper.query('questions');
      final matched = allQ.where((q) => qIds.contains(q['id'] as int)).toList();

      // 分组
      final sections = <String, List<Map<String, dynamic>>>{};
      for (final q in matched) {
        sections.putIfAbsent(q['type'] as String, () => []).add(q);
      }

      expect(sections.length, 2); // 听力 + 仔细阅读
      expect(sections['听力']!.length, 1);
      expect(sections['仔细阅读']!.length, 1);
    });

    test('should delete wrong question record', () async {
      await seedTestData();

      await dbHelper.delete('wrong_questions', where: 'question_id = ? AND user_id = ?', whereArgs: [1, 1]);

      final remaining = await dbHelper.query('wrong_questions', where: 'user_id = ?', whereArgs: [1]);
      expect(remaining.length, 1);
      expect(remaining.first['question_id'], 2);

      // questions 表不受影响
      final questions = await dbHelper.query('questions');
      expect(questions.length, 3);
    });
  });
}
