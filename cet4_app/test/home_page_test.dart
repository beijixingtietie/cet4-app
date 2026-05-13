import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cet4_app/database/db_helper.dart';
import 'package:cet4_app/database/memory_storage.dart';
import 'package:cet4_app/provider/study_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudyProvider forecast', () {
    late DbHelper dbHelper;
    late StudyProvider studyProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbHelper = DbHelper();
      await MemoryStorage().clearAll();
      studyProvider = StudyProvider();
    });

    test('review forecast is empty when no records exist', () async {
      await studyProvider.loadTodayData();
      final forecast = studyProvider.reviewForecast;
      expect(forecast.length, 7);
      expect(forecast.every((c) => c == 0), isTrue);
    });

    test('review forecast counts records in next 7 days', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Insert study records with various next_review_time values
      await dbHelper.insert('study_records', {
        'id': 1, 'word_id': 1, 'user_id': 1,
        'status': '学习中', 'correct_count': 1, 'wrong_count': 0,
        'last_study_time': now.toIso8601String(),
        'next_review_time': today.add(const Duration(days: 1)).toIso8601String(), // tomorrow
      });
      await dbHelper.insert('study_records', {
        'id': 2, 'word_id': 2, 'user_id': 1,
        'status': '学习中', 'correct_count': 1, 'wrong_count': 0,
        'last_study_time': now.toIso8601String(),
        'next_review_time': today.add(const Duration(days: 1)).toIso8601String(), // tomorrow
      });
      await dbHelper.insert('study_records', {
        'id': 3, 'word_id': 3, 'user_id': 1,
        'status': '学习中', 'correct_count': 2, 'wrong_count': 0,
        'last_study_time': now.toIso8601String(),
        'next_review_time': today.add(const Duration(days: 3)).toIso8601String(), // D+3
      });

      await studyProvider.loadTodayData();
      final forecast = studyProvider.reviewForecast;

      expect(forecast[1], 2); // tomorrow: 2 records
      expect(forecast[3], 1); // D+3: 1 record
    });

    test('category progress getters return correct values', () async {
      final testNow = DateTime.now();
      await dbHelper.insert('words', {
        'id': 1, 'word': 'a', 'meaning': '', 'type': '',
        'phonetic_uk': '', 'phonetic_us': '', 'audio_uk': '', 'audio_us': '',
        'example': '', 'example_translation': '', 'collocation': '', 'level': '',
      });
      await dbHelper.insert('study_records', {
        'id': 1, 'word_id': 1, 'user_id': 1,
        'status': '已掌握', 'correct_count': 3, 'wrong_count': 0,
        'last_study_time': testNow.toIso8601String(),
        'next_review_time': testNow.add(const Duration(days: 7)).toIso8601String(),
      });

      await studyProvider.loadTodayData();
      expect(studyProvider.masteredCount, 1);
      expect(studyProvider.totalWordsCount, 1);
    });
  });
}
