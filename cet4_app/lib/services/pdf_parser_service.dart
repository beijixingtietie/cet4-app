import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/word.dart';
import '../models/question.dart';

/// PDF 文本解析服务 — 全平台通用
/// 支持从 Uint8List（手动导入）和 Flutter assets（默认数据）读取
class PdfParserService {
  PdfParserService._();

  /// 从 PDF 字节提取所有文本
  static String _extractText(Uint8List pdfBytes) {
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  /// 从 Flutter asset 加载 PDF 并提取文本
  static Future<String> _extractTextFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return _extractText(data.buffer.asUint8List());
  }

  // ========== 词汇解析 ==========

  /// 从 Uint8List 提取单词（手动导入）
  static List<Word> extractWords(Uint8List pdfBytes) {
    final text = _extractText(pdfBytes);
    if (text.trim().isEmpty) return [];
    return _parseWordLines(text);
  }

  /// 从 Flutter asset 提取单词（默认数据自动导入）
  static Future<List<Word>> extractWordsFromAsset(String assetPath) async {
    final text = await _extractTextFromAsset(assetPath);
    if (text.trim().isEmpty) return [];
    return _parseWordLines(text);
  }

  static List<Word> _parseWordLines(String text) {
    // 主匹配模式: "序号. 单词 [音标] 词性. 释义"
    // 问题: 释义可能跨行，导致只取到第一行
    // 解决: 逐行扫描，自动合并非首行内容到上一个单词的释义
    final entryPattern = RegExp(
      r'^(\d+)[\.\s、]+(\S+)\s*\[([^\]]+)\]\s*(\S+?\.)\s*(.*)',
    );

    final lines = text.split('\n');
    final words = <Word>[];
    final seen = <String>{};
    Word? currentWord;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = entryPattern.firstMatch(trimmed);
      if (match != null) {
        // 新单词开始 — 先保存上一个
        if (currentWord != null) {
          final fixed = _fixSplitTypeAndMeaning(currentWord);
          if (!seen.contains(fixed.word.toLowerCase())) {
            seen.add(fixed.word.toLowerCase());
            words.add(Word(
              id: words.length + 1,
              word: fixed.word,
              phoneticUk: fixed.phoneticUk,
              phoneticUs: fixed.phoneticUs,
              audioUk: fixed.audioUk,
              audioUs: fixed.audioUs,
              type: fixed.type,
              meaning: fixed.meaning,
              example: fixed.example,
              exampleTranslation: fixed.exampleTranslation,
              collocation: fixed.collocation,
              level: fixed.level,
            ));
          }
        }

        final word = match.group(2)!.trim();
        if (word.length < 2 || word.length > 30) {
          currentWord = null;
          continue;
        }
        if (RegExp(r'^\d+$').hasMatch(word)) {
          currentWord = null;
          continue;
        }

        final phoneticRaw = match.group(3)!.trim();
        final phonetic = phoneticRaw.startsWith('/') ? phoneticRaw : '/$phoneticRaw/';
        final posType = match.group(4)!.trim().replaceAll(RegExp(r'\.$'), '');
        final meaning = match.group(5)!.trim();

        currentWord = Word(
          id: 0,
          word: word,
          phoneticUk: phonetic,
          phoneticUs: phonetic,
          audioUk: '',
          audioUs: '',
          type: posType,
          meaning: meaning,
          example: '',
          exampleTranslation: '',
          collocation: '',
          level: '高频核心词',
        );
      } else if (currentWord != null) {
        // 续行 — 追加到释义
        if (trimmed.length < 200 &&
            !trimmed.startsWith('Part ') &&
            !trimmed.contains('Directions:')) {
          currentWord = Word(
            id: 0,
            word: currentWord.word,
            phoneticUk: currentWord.phoneticUk,
            phoneticUs: currentWord.phoneticUs,
            audioUk: '',
            audioUs: '',
            type: currentWord.type,
            meaning: '${currentWord.meaning}${trimmed}',
            example: '',
            exampleTranslation: '',
            collocation: '',
            level: '高频核心词',
          );
        }
      }
    }

    // 最后一个单词
    if (currentWord != null) {
      final fixed = _fixSplitTypeAndMeaning(currentWord);
      if (!seen.contains(fixed.word.toLowerCase())) {
        seen.add(fixed.word.toLowerCase());
        words.add(Word(
          id: words.length + 1,
          word: fixed.word,
          phoneticUk: fixed.phoneticUk,
          phoneticUs: fixed.phoneticUs,
          audioUk: fixed.audioUk,
          audioUs: fixed.audioUs,
          type: fixed.type,
          meaning: fixed.meaning,
          example: fixed.example,
          exampleTranslation: fixed.exampleTranslation,
          collocation: fixed.collocation,
          level: fixed.level,
        ));
      }
    }

    if (words.isEmpty) {
      // 回退：旧的单行匹配（兼容不同格式的 PDF）
      return _parseWordLinesFallback(text, seen);
    }

    return words;
  }

  /// 修复词性被拆断到释义中的问题
  /// 如: type="n.危" meaning="险" → type="n." meaning="危险"
  static Word _fixSplitTypeAndMeaning(Word w) {
    var type = w.type;
    var meaning = w.meaning;

    // 如果释义以中文字符开头，说明词性没有被拆断
    if (meaning.isNotEmpty && !RegExp(r'^[一-鿿]').hasMatch(meaning)) {
      // 释义开头不是中文，可能还有词性残余
      // 尝试把释义开头的英文/标点部分并回词性
    }

    // 检查 type 是否以不完整的中文结尾（最常见的问题）
    final typeLastChar = type.isNotEmpty ? type[type.length - 1] : '';
    if (RegExp(r'[一-鿿]').hasMatch(typeLastChar)) {
      // type 末尾有中文 → 被拆断了
      // 从末尾开始找，把中文字符移到 meaning 前面
      var splitIdx = type.length;
      while (splitIdx > 0 && RegExp(r'[一-鿿]').hasMatch(type[splitIdx - 1])) {
        splitIdx--;
      }
      // 保持 type 中的英文/符号/词性标记部分
      final trailing = type.substring(splitIdx);
      type = type.substring(0, splitIdx);
      meaning = '$trailing$meaning';
    }

    // 清理 type 末尾的句点和多余空格
    type = type.replaceAll(RegExp(r'\.$'), '').trim();
    // 保证 type 末尾有句点（如 n. v. adj.）
    if (type.isNotEmpty && !type.endsWith('.') && RegExp(r'^[a-z]+$').hasMatch(type)) {
      type = '$type.';
    }

    meaning = meaning.trim();
    if (meaning.length > 200) {
      meaning = '${meaning.substring(0, 197)}...';
    }

    return Word(
      id: w.id,
      word: w.word,
      phoneticUk: w.phoneticUk,
      phoneticUs: w.phoneticUs,
      audioUk: w.audioUk,
      audioUs: w.audioUs,
      type: type,
      meaning: meaning,
      example: w.example,
      exampleTranslation: w.exampleTranslation,
      collocation: w.collocation,
      level: w.level,
    );
  }

  /// 旧版单行匹配回退（兼容不同格式的 PDF）
  static List<Word> _parseWordLinesFallback(String text, Set<String> seen) {
    final pattern = RegExp(
      r'(\d+)[\.\s]+(\S+)\s*\[([^\]]+)\]\s*(\S+?)\.?\s*(.+)',
      multiLine: true,
    );

    final words = <Word>[];
    final localSeen = Set<String>.from(seen);

    for (final match in pattern.allMatches(text)) {
      final word = match.group(2)!.trim();
      if (word.length < 2 || word.length > 30) continue;
      if (RegExp(r'^\d+$').hasMatch(word)) continue;
      if (localSeen.contains(word.toLowerCase())) continue;
      localSeen.add(word.toLowerCase());

      final phoneticRaw = match.group(3)!.trim();
      final phonetic = phoneticRaw.startsWith('/') ? phoneticRaw : '/$phoneticRaw/';
      final posType = match.group(4)!.trim().replaceAll(RegExp(r'\.$'), '');
      final meaning = match.group(5)!.trim();
      if (meaning.length > 200) continue;

      final w = Word(
        id: words.length + 1,
        word: word,
        phoneticUk: phonetic,
        phoneticUs: phonetic,
        audioUk: '',
        audioUs: '',
        type: posType,
        meaning: meaning,
        example: '',
        exampleTranslation: '',
        collocation: '',
        level: '高频核心词',
      );

      final fixed = _fixSplitTypeAndMeaning(w);
      words.add(fixed);
    }

    return words;
  }

  // ========== 真题解析 ==========

  /// 从 Uint8List 提取题目（手动导入）
  static List<Question> extractQuestions(Uint8List pdfBytes, String yearRange) {
    final text = _extractText(pdfBytes);
    if (text.trim().isEmpty) return [];
    return _parseQuestionLines(text, yearRange);
  }

  /// 从 Flutter asset 提取题目（默认数据自动导入）
  static Future<List<Question>> extractQuestionsFromAsset(
    String assetPath,
    String yearRange,
  ) async {
    final text = await _extractTextFromAsset(assetPath);
    if (text.trim().isEmpty) return [];
    return _parseQuestionLines(text, yearRange);
  }

  static List<Question> _parseQuestionLines(String text, String yearRange) {
    final questions = <Question>[];
    int qid = 1;

    // --- 写作 ---
    final writePattern = RegExp(
      r'write\s+(?:a(?:n)?|an?|the)\s+.*?([\s\S]{20,200}?)You should write',
      caseSensitive: false,
    );
    for (final match in writePattern.allMatches(text)) {
      final topic = match.group(1)!.trim();
      final year = _extractYear(text, match.start, yearRange);
      final content = 'Directions: $topic';
      if (!questions.any((q) => q.type == '写作' && q.content == content)) {
        questions.add(Question(
          id: qid++, type: '写作', year: year,
          content: content,
          answer: '(参考范文请查阅真题解析)',
          explanation: '${year}年6月/12月四级真题写作',
        ));
      }
    }

    // --- 翻译 ---
    final transPattern = RegExp(
      r'(?:Translation|翻译).*?(?:Directions.*?)?([一-鿿][\s\S]{30,300}?)(?=You have|Part\s*[IV]|$)',
      caseSensitive: false,
    );
    for (final match in transPattern.allMatches(text)) {
      final content = match.group(1)!.trim();
      final hasChinese = RegExp(r'[一-鿿]').hasMatch(content);
      if (hasChinese && !questions.any((q) =>
          q.type == '翻译' && q.content.startsWith(content.substring(0, content.length.clamp(0, 30))))) {
        final year = _extractYear(text, match.start, yearRange);
        questions.add(Question(
          id: qid++, type: '翻译', year: year,
          content: content,
          answer: '(参考译文请查阅真题解析)',
          explanation: '${year}年四级真题翻译',
        ));
      }
    }

    // --- 仔细阅读 ---
    final passagePattern = RegExp(
      r'Passage\s+(?:One|Two|Questions.*?are based on).*?([\s\S]{200,2000}?)(?:\d+\.\s*What|Questions\s*\d+|\d+\.\s*$)',
      caseSensitive: false,
    );
    for (final passageMatch in passagePattern.allMatches(text)) {
      final passage = passageMatch.group(1)!.trim();
      final year = _extractYear(text, passageMatch.start, yearRange);
      final qPattern = RegExp(
        r'(\d+)\.\s*(What\s[^?\n]+?\??|Why\s[^?\n]+?\??|How\s[^?\n]+?\??|Which\s[^?\n]+?\??)',
        caseSensitive: false,
      );
      for (final qm in qPattern.allMatches(passage).take(3)) {
        final qText = qm.group(2)!.trim();
        if (!questions.any((q) => q.type == '仔细阅读' && q.content == qText)) {
          questions.add(Question(
            id: qid++, type: '仔细阅读', year: year,
            content: qText, passage: passage,
            options: ['A', 'B', 'C', 'D'],
            answer: '(参考答案请查阅真题解析)',
            explanation: '${year}年四级真题仔细阅读 Passage',
          ));
        }
      }
    }

    // --- 听力 ---
    final listeningPattern = RegExp(
      r'(?:Section\s*[ABC].*?Listening|听力理解|Listening Comprehension).*?([\s\S]{100,1000}?)(?=Section|Part\s*[IV]|$)',
      caseSensitive: false,
    );
    for (final match in listeningPattern.allMatches(text)) {
      final content = match.group(1)!.trim();
      final itemPattern = RegExp(r'(\d+)\.\s*([\s\S]{20,200}?)(?=\d+\.\s*|$)');
      for (final item in itemPattern.allMatches(content)) {
        final qContent = item.group(2)!.trim();
        if (qContent.length < 10) continue;
        final year = _extractYear(text, match.start, yearRange);
        if (!questions.any((q) => q.type == '听力' && q.content == qContent)) {
          questions.add(Question(
            id: qid++, type: '听力', year: year,
            content: qContent,
            options: ['A', 'B', 'C', 'D'],
            answer: '(参考答案请查阅真题解析)',
            explanation: '${year}年四级真题听力',
          ));
        }
      }
    }

    return questions;
  }

  // ========== 工具 ==========

  static String _extractYear(String text, int position, String yearRange) {
    final start = position.clamp(0, text.length);
    final end = (position + 200).clamp(0, text.length);
    final nearby = text.substring(start, end);
    final yearMatch = RegExp(r'(20\d{2})年').firstMatch(nearby);
    if (yearMatch != null) return yearMatch.group(1)!;
    return yearRange.split('-').first;
  }
}
