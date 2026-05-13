# 英语四级备考 APP（AI 增强版）完整开发指南

---

## 一、整体开发要求

基于**Flutter最新稳定版**开发一款**轻量化、无广告、离线优先\+AI增强**的大学英语四级备考APP，支持Android/iOS双端原生运行。

- 代码结构清晰，模块化设计，关键逻辑添加详细注释

- UI界面简洁易用，适配主流手机屏幕尺寸

- 所有基础备考数据本地存储，无需复杂后端服务器

- 可直接编译运行，无明显BUG，后期可扩展云端功能

- **新增：集成大模型API实现AI智能学习功能**

- **AI功能与基础功能完全解耦，关闭API后基础功能仍可正常使用**

---

## 二、技术栈指定

|功能模块|技术选型|用途说明|
|---|---|---|
|前端框架|Flutter|跨端开发，一套代码运行安卓/iOS|
|本地数据库|sqflite|存储单词、真题、做题记录、错题本|
|状态管理|Provider|全局状态管理，简单易维护|
|音频播放|just\_audio|听力音频播放，支持倍速、循环|
|本地缓存|shared\_preferences|存储用户设置、学习记录、打卡数据|
|**HTTP客户端**|**dio**|**大模型API网络请求**|
|**大模型API**|**Anthropic Claude API**|**AI智能学习核心**|

---

## 三、核心功能模块开发明细

### （一）词汇记忆模块（最高优先级）

1. **完整词库**

    - 内置大学英语四级4500\+考纲词汇

    - 按**高频核心词、中频词、低频词、超纲词**分层

    - 每个单词包含：单词、英式音标、美式音标、词性、中文释义、真题例句、常见搭配、词形变形

2. **智能记忆**

    - 基于艾宾浩斯遗忘曲线的自动复习算法

    - 支持自定义每日背诵单词量（10\-200词）

    - 多种记忆模式：单词卡片翻转、听音识词、选词填空、拼写默写

    - 自动标记掌握程度（未学/学习中/已掌握/已遗忘）

3. **生词本**

    - 自动收录背诵错误、标记\&\#34;不熟\&\#34;的单词

    - 支持手动收藏/移除单词

    - 生词本一键复习、批量清空、按掌握程度筛选

4. **学习统计**

    - 每日背诵单词数、学习时长统计

    - 连续打卡天数、累计学习天数

    - 简易学习日历，可视化展示学习进度

5. **✨ AI词汇增强功能**

    - **AI单词讲解**：点击单词卡片上的\&\#34;AI讲解\&\#34;按钮，大模型生成个性化单词讲解

    - **AI造句子**：根据用户输入的场景，生成包含该单词的实用句子

    - **AI同义词辨析**：对比易混淆单词的用法区别

    - **AI词根词缀分析**：拆解单词的词根词缀，帮助记忆

### （二）四级真题题库模块

1. **完整题库**

    - 内置近10年英语四级全套真题

    - 拆分六大题型：听力、选词填空、长篇阅读、仔细阅读、翻译、写作

    - 支持分题型专项刷题、整套试卷模拟刷题

2. **做题功能**

    - 选项勾选、题目标记、答案隐藏

    - 提交后自动批改，每题附带**详细解析、考点分析、错误选项排除原因**

    - 做题进度自动保存，支持继续上次做题

3. **错题本**

    - 自动收录所有做错的题目

    - 按题型、年份筛选错题

    - 错题重做、移除错题、清空错题本

4. **✨ AI题库增强功能**

    - **AI题目深度解析**：对用户做错的题目，大模型生成更详细的解题思路和知识点讲解

    - **AI相似题生成**：根据错题自动生成3\-5道相似题目进行强化练习

    - **AI长难句分析**：点击阅读文章中的长难句，大模型自动拆解语法结构和翻译

    - **AI阅读总结**：生成阅读文章的核心内容摘要和主旨大意

### （三）听力专项模块

1. **音频播放**

    - 配套近10年四级真题听力音频

    - 音频与原文同步高亮展示

    - 播放控制：倍速播放\(0\.5x/0\.75x/1\.0x/1\.25x/1\.5x/2\.0x\)、单句循环、段落循环、进度拖动

2. **精听功能**

    - 听力刷题模式：听音频→答题→对答案→看原文精听

    - 标注听力重点词汇、长难句解析

    - 支持隐藏原文，纯听力练习

3. **✨ AI听力增强功能**

    - **AI听力逐句翻译**：点击听力原文中的任意句子，大模型生成精准翻译

    - **AI听力技巧讲解**：针对不同听力题型，大模型提供针对性的解题技巧

    - **AI听力跟读评分**：用户跟读听力原文，大模型评估发音准确度（可选）

### （四）作文\&amp;翻译专项模块

1. **作文板块**

    - 四级高频作文类型：议论文、图表类、书信类、名言哲理类

    - 提供满分范文、万能开头结尾、高级句型模板、高级替换词库

    - 写作思路拆解、评分标准说明

    - 支持用户手动输入写作内容，本地保存草稿

2. **翻译板块**

    - 收录四级常考翻译话题：中国文化、历史、社会、经济、教育、科技

    - 附带标准译文、重点词组翻译、语法知识点讲解

    - 支持用户手动输入翻译内容，本地保存草稿

3. **✨ AI作文\&amp;翻译批改功能（核心增值功能）**

    - **AI作文智能批改**：

        - 按照四级作文评分标准（内容、结构、语言、语法）进行打分

        - 逐句标注语法错误、拼写错误、用词不当

        - 提供修改建议和润色后的版本

        - 分析作文的优点和不足

        - 给出提升建议

    - **AI翻译智能批改**：

        - 对比用户翻译与标准译文的差异

        - 指出翻译错误和不准确的地方

        - 提供更地道的翻译表达

        - 讲解翻译技巧和常用句型

### （五）全真模拟考试模块

1. **全真模拟**

    - 完全还原四级考试流程、考试时间、题型分值分布

    - 开启考试后进入倒计时模式，时间到自动交卷

    - 支持中途暂停、保存考试进度

2. **成绩分析**

    - 考试结束自动打分，生成详细成绩单

    - 统计各题型正确率、得分率、做题时长

    - 识别薄弱题型，智能推荐针对性专项练习

3. **✨ AI考试分析功能**

    - **AI全面考试报告**：大模型生成个性化的考试分析报告

    - **AI学习计划制定**：根据考试成绩和薄弱点，制定为期1\-4周的个性化学习计划

    - **AI考前预测**：基于历年真题和考试趋势，预测本次考试的重点和难点

### （六）AI智能助手模块（新增独立模块）

1. **四级专属AI聊天助手**

    - 可以回答任何关于英语四级备考的问题

    - 支持语音输入和文字输入

    - 可以生成自定义的模拟题

    - 可以进行英语对话练习

    - 可以解释任何语法知识点

2. **API设置功能**

    - 用户可以在设置页面输入自己的Claude API密钥

    - 支持选择不同的Claude模型（Claude 3 Haiku/Sonnet/Opus）

    - 支持设置API请求超时时间

    - 显示API使用量和剩余额度

### （七）通用辅助功能

- 每日学习打卡，累计打卡天数展示

- 完全离线使用：所有基础功能均本地存储，AI功能需要联网

- 界面设置：深色/浅色模式、字体大小调节、音效开关

- 数据管理：支持学习数据一键备份、恢复、清空

- 锁屏背单词功能（可选）

---

## 四、APP页面结构

### 底部导航栏（6个主页面）

1. **首页**：今日学习进度、打卡入口、快速入口（背单词、刷真题、练听力）

2. **词汇**：词库选择、开始背单词、生词本、学习统计

3. **题库**：真题列表、分题型刷题、错题本、做题记录

4. **听力**：听力真题列表、听力播放页、精听模式

5. **✨ AI助手**：AI聊天界面、API设置

6. **我的**：个人信息、学习统计、设置、数据管理

### 次级页面

- 单词背诵页、单词详情页（含AI讲解按钮）

- 真题做题页、答案解析页（含AI深度解析按钮）

- 听力播放页、听力原文页（含AI逐句翻译按钮）

- 作文模板页、作文编辑页（含AI批改按钮）

- 翻译题库页、翻译编辑页（含AI批改按钮）

- 模拟考试页、考试成绩单页（含AI考试分析按钮）

- AI聊天页、API设置页

- 学习统计页、设置页

---

## 五、数据格式与数据库设计

### 1\. 本地数据格式

- 所有词库、真题、范文数据均采用**JSON格式**存储在项目assets目录

- 听力音频文件存放至`assets/audio/`目录

- 无需网络请求，APP启动时自动加载本地数据

### 2\. 数据库表设计

- `words`：单词表（所有四级词汇）

- `study\_records`：单词学习记录表

- `exam\_records`：真题做题记录表

- `wrong\_questions`：错题表

- `user\_settings`：用户设置表（新增：api\_key、model\_name字段）

- `ai\_conversations`：AI对话记录表

- `ai\_corrections`：AI批改记录表

### 3\. 四级词库JSON数据结构示例

```JSON
[
  {
    "id": 1,
    "word": "abandon",
    "phonetic_uk": "/əˈbændən/",
    "phonetic_us": "/əˈbændən/",
    "audio_uk": "assets/audio/abandon_uk.mp3",
    "audio_us": "assets/audio/abandon_us.mp3",
    "type": "v.",
    "meaning": "放弃，遗弃，抛弃；放弃，中止",
    "example": "He abandoned his plan due to lack of money.",
    "example_translation": "由于资金不足，他放弃了自己的计划。",
    "collocation": "abandon oneself to 沉溺于；abandon hope 放弃希望",
    "level": "高频核心词"
  }
]
```

---

## 六、大模型API集成技术要求

### 1\. Claude API集成规范

- 使用dio库发送HTTP POST请求到Claude API端点

- 实现流式响应处理，支持打字机效果显示AI回复

- 添加错误处理机制，处理API调用失败、网络错误、额度不足等情况

- 实现请求缓存，避免重复调用相同的API请求

- 支持取消正在进行的API请求

### 2\. 各功能专属系统提示词（核心！决定AI输出质量）

#### 四级作文批改系统提示词

```Plaintext
你是一位专业的大学英语四级作文阅卷老师，拥有10年以上四级作文批改经验。请严格按照中国大学英语四级考试作文评分标准（满分15分）对用户提交的作文进行批改。

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

请用中文进行批改，不要使用英文解释。
```

#### 四级翻译批改系统提示词

```Plaintext
你是一位专业的大学英语四级翻译阅卷老师，拥有10年以上四级翻译批改经验。请严格按照中国大学英语四级考试翻译评分标准（满分15分）对用户提交的翻译进行批改。

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

请用中文进行批改，不要使用英文解释。
```

#### 单词讲解系统提示词

```Plaintext
你是一位专业的大学英语四级词汇老师。请用简洁明了的中文为用户讲解这个四级单词，帮助用户快速掌握并记住它。

讲解内容必须包括：
1. 单词的核心含义和常见用法
2. 词根词缀分析（如果有）
3. 3个最常用的固定搭配
4. 2个四级考试中常见的例句
5. 易混淆单词辨析（如果有）

语言要简洁易懂，重点突出，符合四级考试要求，不要讲解超纲内容。
```

#### 题目深度解析系统提示词

```Plaintext
你是一位专业的大学英语四级考试辅导老师。请对这道四级题目进行深度解析，帮助用户理解题目考点和解题思路。

解析内容必须包括：
1. 正确答案
2. 详细的解题思路和步骤
3. 本题考查的核心知识点
4. 错误选项的错误原因分析
5. 同类题目的解题技巧
6. 相关知识点的拓展

语言要简洁明了，重点突出，符合四级考试要求。
```

#### 长难句分析系统提示词

```Plaintext
你是一位专业的大学英语四级语法老师。请对这个四级长难句进行详细分析，帮助用户理解句子结构和含义。

分析内容必须包括：
1. 句子的准确翻译
2. 句子的主干结构
3. 句子的成分分析（主语、谓语、宾语、定语、状语等）
4. 句子中包含的语法知识点
5. 重点词汇和短语的解释

语言要简洁明了，通俗易懂，符合四级考试要求。
```

#### AI智能助手通用系统提示词

```Plaintext
你是一位专业的大学英语四级备考助手，专门为准备英语四级考试的学生提供帮助。

你的职责包括：
1. 回答任何关于英语四级考试的问题
2. 解释英语语法知识点
3. 生成四级模拟题
4. 提供学习方法和备考建议
5. 进行简单的英语对话练习

请用简洁明了的中文回答问题，重点突出，符合四级考试要求，不要回答与四级备考无关的问题。
```

### 3\. 完整的Claude API调用代码模板（含流式响应\+错误处理）

```Dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ClaudeApiService {
  static const String baseUrl = 'https://api.anthropic.com/v1';
  static const String defaultModel = 'claude-3-haiku-20240307';
  static const int defaultMaxTokens = 2048;
  static const double defaultTemperature = 0.7;

  final String apiKey;
  final String model;
  final Dio _dio = Dio();
  final Map<String, String> _cache = {};
  final Map<String, CancelToken> _cancelTokens = {};

  ClaudeApiService({
    required this.apiKey,
    this.model = defaultModel,
  }) {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  /// 发送普通请求（非流式）
  Future<String> sendMessage(
    String prompt, {
    String systemPrompt = "",
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
    bool useCache = true,
  }) async {
    // 检查缓存
    final cacheKey = '$systemPrompt|$prompt';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final response = await _dio.post(
        '/messages',
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'max_tokens': maxTokens,
          'temperature': temperature,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        },
      );

      final result = response.data['content'][0]['text'] as String;
      
      // 存入缓存
      if (useCache) {
        _cache[cacheKey] = result;
      }

      return result;
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('API调用失败: ${e.toString()}');
    }
  }

  /// 发送流式请求（打字机效果）
  Stream<String> sendMessageStream(
    String prompt, {
    String systemPrompt = "",
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
    String? requestId,
  }) {
    final controller = StreamController<String>();
    final cancelToken = CancelToken();
    
    if (requestId != null) {
      _cancelTokens[requestId] = cancelToken;
    }

    _dio.post(
      '/messages',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
      data: {
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'system': systemPrompt,
        'stream': true,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      },
    ).then((response) {
      response.data.stream.listen(
        (data) {
          try {
            final lines = String.fromCharCodes(data).split('\n');
            for (final line in lines) {
              if (line.startsWith('data: ')) {
                final jsonData = line.substring(6);
                if (jsonData == '[DONE]') {
                  controller.close();
                  return;
                }
                
                final event = jsonDecode(jsonData);
                if (event['type'] == 'content_block_delta') {
                  final text = event['delta']['text'] as String;
                  controller.add(text);
                }
              }
            }
          } catch (e) {
            debugPrint('解析流式响应失败: $e');
          }
        },
        onError: (e) {
          if (e is DioException && e.type == DioExceptionType.cancel) {
            controller.close();
          } else {
            controller.addError(_handleDioError(e));
            controller.close();
          }
        },
        onDone: () {
          controller.close();
          if (requestId != null) {
            _cancelTokens.remove(requestId);
          }
        },
      );
    }).catchError((e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        controller.close();
      } else {
        controller.addError(_handleDioError(e));
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 取消正在进行的请求
  void cancelRequest(String requestId) {
    if (_cancelTokens.containsKey(requestId)) {
      _cancelTokens[requestId]!.cancel();
      _cancelTokens.remove(requestId);
    }
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
  }

  /// 处理Dio错误
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络连接后重试';
      case DioExceptionType.sendTimeout:
        return '发送请求超时，请检查网络连接后重试';
      case DioExceptionType.receiveTimeout:
        return '接收响应超时，请检查网络连接后重试';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        
        if (statusCode == 401) {
          return 'API密钥无效，请检查您的Claude API密钥';
        } else if (statusCode == 403) {
          return 'API权限不足，请检查您的账户权限';
        } else if (statusCode == 429) {
          return '请求过于频繁，请稍后再试';
        } else if (statusCode == 500) {
          return '服务器内部错误，请稍后再试';
        } else {
          return 'API调用失败: ${responseData?['error']?['message'] ?? '未知错误'}';
        }
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络错误，请检查网络连接后重试';
    }
  }
}
```

### 4\. AI状态管理模板（Provider）

```Dart
import 'package:flutter/foundation.dart';
import '../utils/claude_api.dart';

class AiProvider with ChangeNotifier {
  ClaudeApiService? _apiService;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isApiConfigured => _apiService != null;

  /// 初始化API服务
  void initApi(String apiKey, {String model = ClaudeApiService.defaultModel}) {
    _apiService = ClaudeApiService(apiKey: apiKey, model: model);
    notifyListeners();
  }

  /// 清除API配置
  void clearApi() {
    _apiService = null;
    notifyListeners();
  }

  /// 发送普通请求
  Future<String> sendMessage(
    String prompt, {
    String systemPrompt = "",
  }) async {
    if (_apiService == null) {
      throw Exception('请先在设置中配置Claude API密钥');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService!.sendMessage(
        prompt,
        systemPrompt: systemPrompt,
      );
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
}
```

---

## 七、项目目录结构要求

```Plaintext
lib/
├── main.dart                  // 项目入口
├── app.dart                   // 应用根组件
├── pages/                     // 所有页面
│   ├── home/                  // 首页
│   ├── vocabulary/            // 词汇模块
│   ├── question_bank/         // 题库模块
│   ├── listening/             // 听力模块
│   ├── ai_assistant/          // ✨ AI助手模块
│   └── profile/               // 个人中心
├── components/                // 公共组件
│   ├── word_card.dart         // 单词卡片组件
│   ├── question_item.dart     // 题目组件
│   ├── audio_player.dart      // 音频播放器组件
│   └── ai_message_bubble.dart // ✨ AI消息气泡组件
├── models/                    // 数据模型
│   ├── word.dart              // 单词模型
│   ├── question.dart          // 题目模型
│   ├── exam.dart              // 考试模型
│   └── ai_message.dart        // ✨ AI消息模型
├── database/                  // 数据库操作
│   ├── db_helper.dart         // 数据库帮助类
│   └── tables/                // 数据表定义
├── provider/                  // 状态管理
│   ├── study_provider.dart    // 学习状态管理
│   ├── user_provider.dart     // 用户状态管理
│   └── ai_provider.dart       // ✨ AI状态管理
├── utils/                     // 工具类
│   ├── ebisu_algorithm.dart   // 艾宾浩斯算法
│   ├── json_loader.dart       // JSON数据加载器
│   └── claude_api.dart        // ✨ Claude API工具类
└── assets/                    // 本地资源
    ├── data/                  // JSON数据（词库、真题、范文）
    └── audio/                 // 听力音频文件
```

---

## 八、代码与交付要求

1. 项目结构严格按照上述目录组织，模块化管理

2. 代码简洁易懂，关键逻辑添加详细中文注释

3. UI界面采用Material Design风格，简约美观

4. 实现所有核心功能逻辑，无明显BUG

5. 提供完整的项目运行说明文档

6. 列出所有依赖包及安装命令

7. 标注核心功能代码位置，方便后续修改和扩展

---

## 九、安全与隐私注意事项

1. **API密钥安全**：用户的API密钥必须使用`shared\_preferences`加密存储在本地，绝对不能硬编码在代码中

2. **功能解耦**：所有AI功能必须与基础功能完全解耦，当用户未配置API密钥时，所有AI相关按钮和入口自动隐藏

3. **加载状态**：所有AI请求必须显示加载动画，流式响应必须实现打字机效果

4. **错误处理**：所有API调用失败必须显示友好的错误提示，允许用户重试

5. **请求取消**：用户离开页面时必须自动取消正在进行的API请求，避免资源浪费

6. **缓存机制**：对重复的请求（如单词讲解、题目解析）进行缓存，减少API调用次数

7. 所有AI对话内容仅在本地存储，用户可以随时删除

8. 不收集任何用户的学习数据和个人信息

9. 提供明确的隐私政策说明

10. 提醒用户保护好自己的API密钥，不要泄露给他人

---

## 十、后续扩展建议

1. 支持更多大模型API（OpenAI GPT、Google Gemini、DeepSeek等）

2. 添加云端同步功能，支持多设备数据同步

3. 添加社区功能，用户可以分享学习经验和AI批改结果

4. 添加单词发音评分功能

5. 添加视频课程功能

> （注：文档部分内容可能由 AI 生成）
