import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/word.dart';
import '../models/question.dart';
import '../models/exam.dart';

class JsonLoader {
  // 加载词库数据
  static Future<List<Word>> loadWords() async {
    try {
      final String response = await rootBundle.loadString('assets/data/words.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => Word.fromJson(json)).toList();
    } catch (e) {
      print('加载词库失败: $e');
      return [];
    }
  }

  // 加载题目数据
  static Future<List<Question>> loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/data/questions.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => Question.fromJson(json)).toList();
    } catch (e) {
      print('加载题目失败: $e');
      return [];
    }
  }

  // 加载考试数据
  static Future<List<Exam>> loadExams() async {
    try {
      final String response = await rootBundle.loadString('assets/data/exams.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => Exam.fromJson(json)).toList();
    } catch (e) {
      print('加载考试数据失败: $e');
      return [];
    }
  }

  // 按年份加载题目
  static Future<List<Question>> loadQuestionsByYear(String year) async {
    final questions = await loadQuestions();
    return questions.where((q) => q.year == year).toList();
  }

  // 按类型加载题目
  static Future<List<Question>> loadQuestionsByType(String type) async {
    final questions = await loadQuestions();
    return questions.where((q) => q.type == type).toList();
  }

  // 按级别加载单词
  static Future<List<Word>> loadWordsByLevel(String level) async {
    final words = await loadWords();
    return words.where((w) => w.level == level).toList();
  }
}
