import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'database/db_helper.dart';
import 'database/memory_storage.dart';
import 'provider/study_provider.dart';
import 'provider/user_provider.dart';
import 'provider/ai_provider.dart';
import 'provider/navigation_provider.dart';
import 'services/pdf_parser_service.dart';
import 'services/notification_service.dart';
import 'utils/json_loader.dart';

/// 数据版本号 — 修改此值会强制重新导入默认数据
const _dataVersion = 2;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预初始化内存存储
  try {
    await MemoryStorage().init();
  } catch (e) {
    debugPrint('MemoryStorage init warning: $e');
  }

  // 检查数据版本，过期则清除旧数据强制重新种子
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt('data_version') ?? 0;
    if (savedVersion < _dataVersion) {
      debugPrint('Data version $savedVersion < $_dataVersion — clearing old data');
      final db = DbHelper();
      await db.delete('words');
      await db.delete('questions');
      await prefs.setInt('data_version', _dataVersion);
    }
  } catch (e) {
    debugPrint('Version check warning: $e');
  }

  // ======== 默认数据自动导入 ========
  await _seedDefaultData();

  // 初始化用户设置
  UserProvider userProvider;
  try {
    userProvider = UserProvider();
    await userProvider.initUserSettings();
  } catch (e) {
    debugPrint('UserProvider init failed (using defaults): $e');
    userProvider = UserProvider();
  }

  // 初始化通知服务
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('NotificationService init warning: $e');
  }

  // 全局错误捕获
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError caught: ${details.exception}');
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => StudyProvider()),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (_) {
          final aiProvider = AiProvider();
          if (userProvider.isApiConfigured) {
            aiProvider.initApi(
              userProvider.apiKey!,
              baseUrl: userProvider.baseUrl,
              model: userProvider.modelName,
              timeoutSeconds: userProvider.apiTimeout,
            );
          }
          return aiProvider;
        }),
      ],
      child: const Cet4App(),
    ),
  );
}

/// 自动从 assets 导入默认数据（仅在数据库为空时执行）
Future<void> _seedDefaultData() async {
  final dbHelper = DbHelper();

  // --- 词汇：优先从捆绑的 PDF 导入，失败则回退到 JSON ---
  try {
    final existingWords = await dbHelper.query('words');
    if (existingWords.isEmpty) {
      debugPrint('Words table empty — importing defaults...');
      List<Map<String, dynamic>> wordList;

      try {
        // 尝试从捆绑的 PDF 解析
        const pdfPath = 'assets/pdf/2026年6月英语四级1500核心词.pdf';
        final words = await PdfParserService.extractWordsFromAsset(pdfPath);
        if (words.isNotEmpty) {
          wordList = words.map((w) => w.toJson()).toList();
          debugPrint('Seeded ${wordList.length} words from bundled PDF');
        } else {
          throw Exception('PDF parsed 0 words');
        }
      } catch (pdfError) {
        // PDF 解析失败，回退到 JSON
        debugPrint('PDF seed failed ($pdfError), falling back to JSON');
        final words = await JsonLoader.loadWords();
        wordList = words.map((w) => w.toJson()).toList();
        debugPrint('Seeded ${wordList.length} words from JSON fallback');
      }

      if (wordList.isNotEmpty) {
        await dbHelper.batchInsert('words', wordList);
      }
    } else {
      debugPrint('Words: ${existingWords.length} already loaded, skip seed');
    }
  } catch (e) {
    debugPrint('Word seeding error: $e');
  }

  // --- 题库：从预提取的 JSON 导入（真题 PDF 过大不适合捆绑） ---
  try {
    final existingQuestions = await dbHelper.query('questions');
    if (existingQuestions.isEmpty) {
      debugPrint('Questions table empty — importing from JSON...');
      final questions = await JsonLoader.loadQuestions();
      if (questions.isNotEmpty) {
        final qList = questions.map((q) => q.toDbMap()).toList();
        await dbHelper.batchInsert('questions', qList);
        debugPrint('Seeded ${qList.length} questions from JSON');
      }
    } else {
      debugPrint('Questions: ${existingQuestions.length} already loaded, skip seed');
    }
  } catch (e) {
    debugPrint('Question seeding error: $e');
  }
}
