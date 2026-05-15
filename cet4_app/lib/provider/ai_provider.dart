import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/claude_api.dart';
import '../database/db_helper.dart';

class AiProvider with ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();
  ClaudeApiService? _apiService;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _conversations = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isApiConfigured => _apiService != null;
  List<Map<String, dynamic>> get conversations => _conversations;

  /// 初始化API服务
  void initApi(
    String apiKey, {
    String? baseUrl,
    String model = ClaudeApiService.defaultModel,
    int timeoutSeconds = 60,
  }) {
    _apiService = ClaudeApiService(
      apiKey: apiKey,
      baseUrl: baseUrl ?? ClaudeApiService.defaultBaseUrl,
      model: model,
      timeoutSeconds: timeoutSeconds,
    );
    notifyListeners();
  }

  /// 清除API配置
  void clearApi() {
    _apiService = null;
    notifyListeners();
  }

  /// 发送普通请求（可选 JSON mode + cancelToken）
  Future<String> sendMessage(
    String prompt, {
    String systemPrompt = "",
    bool responseFormatJson = false,
    CancelToken? cancelToken,
  }) async {
    if (_apiService == null) {
      throw Exception('请先在设置中配置Claude API密钥');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 保存用户消息
      await _saveMessage('user', prompt);

      final result = await _apiService!.sendMessage(
        prompt,
        systemPrompt: systemPrompt,
        responseFormatJson: responseFormatJson,
        cancelToken: cancelToken,
      );

      // 保存AI回复
      await _saveMessage('assistant', result);

      _isLoading = false;
      notifyListeners();
      await loadConversations();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 发送流式请求
  Stream<String> sendMessageStream(
    String prompt, {
    String systemPrompt = "",
    String? requestId,
  }) {
    if (_apiService == null) {
      throw Exception('请先在设置中配置Claude API密钥');
    }

    // 保存用户消息
    _saveMessage('user', prompt);

    return _apiService!.sendMessageStream(
      prompt,
      systemPrompt: systemPrompt,
      requestId: requestId,
    );
  }

  /// 取消请求
  void cancelRequest(String requestId) {
    _apiService?.cancelRequest(requestId);
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 保存消息到数据库
  Future<void> _saveMessage(String role, String content) async {
    try {
      await _dbHelper.insert('ai_conversations', {
        'user_id': 1,
        'role': role,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('保存消息失败: $e');
    }
  }

  /// 加载对话记录
  Future<void> loadConversations() async {
    try {
      _conversations = await _dbHelper.query(
        'ai_conversations',
        where: 'user_id = ?',
        whereArgs: [1],
        orderBy: 'timestamp ASC',
      );
      notifyListeners();
    } catch (e) {
      print('加载对话记录失败: $e');
    }
  }

  /// 保存一条助手消息（供Agent执行后手动保存）
  Future<void> saveAssistantMessage(String content) async {
    await _saveMessage('assistant', content);
    await loadConversations();
  }

  /// 删除最近一条助手消息（用于替换Agent原始JSON响应）
  Future<void> deleteLastAssistantMessage() async {
    try {
      final list = await _dbHelper.query(
        'ai_conversations',
        where: 'user_id = ?',
        whereArgs: [1],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (list.isNotEmpty && list.first['role'] == 'assistant') {
        await _dbHelper.delete('ai_conversations', where: 'id = ?', whereArgs: [list.first['id']]);
        await loadConversations();
      }
    } catch (e) {
      print('删除消息失败: $e');
    }
  }

  /// 清空对话记录
  Future<void> clearConversations() async {
    try {
      await _dbHelper.delete('ai_conversations', where: 'user_id = ?', whereArgs: [1]);
      _conversations = [];
      notifyListeners();
    } catch (e) {
      print('清空对话记录失败: $e');
    }
  }

  /// AI单词讲解
  Future<String> explainWord(String word) async {
    const systemPrompt = '''你是一位专业的大学英语四级词汇老师。请用简洁明了的中文为用户讲解这个四级单词，帮助用户快速掌握并记住它。

讲解内容必须包括：
1. 单词的核心含义和常见用法
2. 词根词缀分析（如果有）
3. 3个最常用的固定搭配
4. 2个四级考试中常见的例句
5. 易混淆单词辨析（如果有）

语言要简洁易懂，重点突出，符合四级考试要求，不要讲解超纲内容。''';

    return await sendMessage('请讲解单词: $word', systemPrompt: systemPrompt);
  }

  /// AI题目深度解析
  Future<String> explainQuestion(String question, String answer) async {
    const systemPrompt = '''你是一位专业的大学英语四级考试辅导老师。请对这道四级题目进行深度解析，帮助用户理解题目考点和解题思路。

解析内容必须包括：
1. 正确答案
2. 详细的解题思路和步骤
3. 本题考查的核心知识点
4. 错误选项的错误原因分析
5. 同类题目的解题技巧
6. 相关知识点的拓展

语言要简洁明了，重点突出，符合四级考试要求。''';

    return await sendMessage(
      '题目: $question\n正确答案: $answer',
      systemPrompt: systemPrompt,
    );
  }

  /// 测试 API 连接
  static Future<String> testConnection({
    required String apiKey,
    String baseUrl = ClaudeApiService.defaultBaseUrl,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get(
        '/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          final models = (data['data'] as List).take(5).map((m) => m['id'] ?? '').where((s) => s.isNotEmpty).join(', ');
          return '✅ 连接成功！可用模型: $models...';
        }
        return '✅ 连接成功（服务器响应正常）';
      }
      return '服务器返回状态码 ${response.statusCode}';
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时，请检查 Base URL 是否正确';
        case DioExceptionType.receiveTimeout:
          return '响应超时';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401) return 'API密钥无效 (401)';
          if (code == 404) return '端点不存在 (404)，请检查 Base URL';
          return '服务器错误 ($code)';
        default:
          return '网络错误: ${e.message}';
      }
    } catch (e) {
      return '连接失败: $e';
    }
  }

  /// AI作文批改
  Future<String> correctWriting(String topic, String content) async {
    const systemPrompt = '''你是一位专业的大学英语四级作文阅卷老师，拥有10年以上四级作文批改经验。请严格按照中国大学英语四级考试作文评分标准（满分15分）对用户提交的作文进行批改。

评分标准：
- 13-15分：切题，表达思想清楚，文字通顺，连贯性好，基本上无语言错误
- 10-12分：切题，表达思想清楚，文字较通顺，连贯性较好，有少量语言错误
- 7-9分：基本切题，表达思想基本清楚，文字尚连贯，有较多语言错误
- 4-6分：基本切题，表达思想不够清楚，文字连贯性差，有较多严重语言错误
- 1-3分：偏离主题，思想表达不清，文字支离破碎，语言错误很多
- 0分：未作答或作文与题目无关

批改要求：
1. 首先给出总分和各维度得分（内容3分、结构3分、语言6分、语法3分）
2. 逐句标注作文中的所有错误：语法错误、拼写错误、用词不当、搭配错误、句式单一
3. 对每一处错误给出具体的修改建议和正确的表达
4. 提供一篇完整的润色后的范文
5. 分析这篇作文的优点和不足之处
6. 给出针对性的提升建议
7. 语言要专业、客观、鼓励性强，符合四级考试要求

请用中文进行批改，不要使用英文解释。''';

    return await sendMessage(
      '作文题目: $topic\n\n我的作文:\n$content',
      systemPrompt: systemPrompt,
    );
  }

  /// AI翻译批改
  Future<String> correctTranslation(String original, String translation) async {
    const systemPrompt = '''你是一位专业的大学英语四级翻译阅卷老师，拥有10年以上四级翻译批改经验。请严格按照中国大学英语四级考试翻译评分标准（满分15分）对用户提交的翻译进行批改。

评分标准：
- 13-15分：译文准确表达了原文意思，用词贴切，行文流畅，无明显语言错误
- 10-12分：译文基本表达了原文意思，用词较贴切，行文较流畅，有少量语言错误
- 7-9分：译文勉强表达了原文意思，用词不够准确，行文不够流畅，有较多语言错误
- 4-6分：译文仅表达了部分原文意思，用词不准确，行文不流畅，有较多严重语言错误
- 1-3分：译文支离破碎，大部分句子意思表达不清，语言错误很多
- 0分：未作答或翻译与原文无关

批改要求：
1. 首先给出总分
2. 逐句对比用户翻译与标准译文，指出所有不准确的地方
3. 对每一处错误给出具体的修改建议和更地道的表达
4. 标注翻译中的重点词汇和固定搭配
5. 讲解相关的翻译技巧和常用句型
6. 分析这篇翻译的优点和不足之处
7. 给出针对性的提升建议

请用中文进行批改，不要使用英文解释。''';

    return await sendMessage(
      '原文: $original\n\n我的翻译:\n$translation',
      systemPrompt: systemPrompt,
    );
  }
}
