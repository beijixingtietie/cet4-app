# CET4 备考助手 — 项目技术文档（AI 可读）

> 仅保留纯技术信息，无介绍性文字。结构化 Markdown，AI/开发者可直接使用。

---

## 1. 项目基本信息

| 属性 | 值 |
|------|-----|
| 项目名称 | CET4 备考助手 |
| 技术栈 | Flutter 3.41.9 + Dart 3.11.5 |
| 状态管理 | Provider (ChangeNotifier) |
| 数据存储 | MemoryStorage — 内存 Map + SharedPreferences JSON 持久化，非 SQLite |
| HTTP 客户端 | Dio 5.4.0 |
| PDF 解析 | syncfusion_flutter_pdf 26.1.35 |
| 图表 | fl_chart 0.69.0 |
| 文件选择 | file_picker 8.0.0 |
| 支持平台 | Android / Web |
| 版本 | 1.0.0+1 |
| Dart SDK | >=3.0.0 <4.0.0 |

---

## 2. 完整项目文件树

```
cet4_app/
├── pubspec.yaml                              # 依赖配置（7 个直接依赖）
├── lib/
│   ├── main.dart                             # 入口：Provider 注册 + 数据种子
│   ├── app.dart                              # MaterialApp：主题/字体缩放/路由
│   │
│   ├── models/
│   │   ├── word.dart                         # Word + StudyRecord 模型
│   │   ├── question.dart                     # Question + WrongQuestion + ExamRecord
│   │   └── exam.dart                         # Exam + ExamSection + ExamResult
│   │
│   ├── provider/
│   │   ├── user_provider.dart                # 用户设置：主题/字体/目标/API/清空数据
│   │   ├── study_provider.dart               # 学习状态：单词/复习/打卡/进度/7天预测
│   │   ├── ai_provider.dart                  # AI 对话：API 调用/消息持久化/JSON mode
│   │   └── navigation_provider.dart          # 底部导航栏索引（5 个 tab）
│   │
│   ├── database/
│   │   ├── db_helper.dart                    # 数据库门面（单例），全部委托给 MemoryStorage
│   │   ├── memory_storage.dart               # ★ 核心存储：分片/索引/懒加载/自动迁移
│   │   └── tables/                           # 旧 SQLite 存根文件（不再使用，9 个文件）
│   │
│   ├── pages/
│   │   ├── home/home_page.dart               # 首页：打卡/进度/快速入口/环形图/柱状图
│   │   ├── vocabulary/
│   │   │   ├── vocabulary_page.dart          # 词汇列表：搜索/筛选/收藏/详情
│   │   │   └── word_study_page.dart          # 背单词：翻卡动画/正确错误/总结
│   │   ├── question_bank/exam_page.dart      # 真题试卷：Part I-IV/答题卡/答案
│   │   ├── ai_assistant/
│   │   │   └── ai_assistant_page.dart        # ★ AI 聊天：Agent 系统提示词/JSON 解析/确认
│   │   ├── profile/profile_page.dart         # 个人中心：统计/设置/备份/清空
│   │   ├── word_book/
│   │   │   ├── word_book_page.dart           # ★ 生词本：DB 查询/搜索/左滑删除/开始学习
│   │   │   └── word_book_manager_page.dart   # 词书管理：在线下载/智能分配
│   │   ├── wrong_questions/
│   │   │   └── wrong_questions_page.dart     # ★ 错题本：分组/重做/答题卡/统计
│   │   └── import/pdf_import_page.dart       # PDF 导入（词汇/题库）
│   │
│   ├── utils/
│   │   ├── claude_api.dart                   # OpenAI 兼容 HTTP 客户端 + JSON mode
│   │   ├── agent_executor.dart               # ★ Agent 解析器：快照/校验/审计/回滚
│   │   ├── ebbinghaus_algorithm.dart         # 艾宾浩斯算法 [1,2,4,7,15,30] 天
│   │   └── json_loader.dart                 # JSON 资源文件加载器
│   │
│   ├── components/                           # 可复用组件（word_card/question_item/ai_message_bubble）
│   └── services/
│       └── pdf_parser_service.dart           # PDF 文本提取 + 词汇/题目结构化解析
│
├── assets/
│   ├── data/                                 # words.json / questions.json / exams.json
│   ├── audio/
│   └── pdf/                                  # 捆绑的默认 PDF 词库
│
├── android/app/src/main/AndroidManifest.xml  # INTERNET + 明文流量 + 存储权限
│
└── test/
    ├── widget_test.dart
    ├── word_book_page_test.dart              # 生词本 DB 操作测试
    ├── wrong_questions_page_test.dart        # 错题本 DB 操作测试
    ├── memory_storage_test.dart              # 分片/索引/懒加载测试
    ├── agent_executor_test.dart              # Agent 解析/校验/审计测试
    └── home_page_test.dart                   # 复习预测/进度统计测试
```

---

## 3. 数据库设计

### 3.1 存储架构（MemoryStorage v2）

```
MemoryStorage (单例)
├── 小表（8 个，init 时全量加载）
│   ├── user_settings    → SharedPreferences key: "mem_user_settings"
│   ├── word_bookmarks   → "mem_word_bookmarks"
│   ├── wrong_questions  → "mem_wrong_questions"
│   ├── study_records    → "mem_study_records"
│   ├── ai_conversations → "mem_ai_conversations"
│   ├── ai_corrections   → "mem_ai_corrections"
│   ├── exam_records     → "mem_exam_records"
│   └── questions        → "mem_questions"
│
├── words 表（分片懒加载 + 索引）
│   ├── mem_words_a  (apple, abandon, abstract...)
│   ├── mem_words_b  (banana, book, break...)
│   ├── ...
│   ├── mem_words_z  (zebra, zone...)
│   └── mem_words__other  (非字母开头)
│
├── 索引缓存（内存）
│   ├── _wordIdIndex:   Map<int, Map>     — O(1) ID 查找
│   └── _wordTextIndex: Map<String, Map>  — O(1) 单词名查找
│
└── 自动迁移：首次访问时自动将旧 mem_words 拆分到分片
```

### 3.2 表结构

#### `words` — 单词表（1500+ 条，分片存储）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 自增主键 |
| word | String | 单词 |
| phonetic_uk | String | 英式音标 |
| phonetic_us | String | 美式音标 |
| audio_uk | String | 英式发音 URL |
| audio_us | String | 美式发音 URL |
| type | String | 词性 (n./v./adj./adv.等) |
| meaning | String | 中文释义 |
| example | String | 例句 |
| example_translation | String | 例句翻译 |
| collocation | String | 常见搭配 |
| level | String | 级别：高频核心词/中频词/低频词/超纲词 |

#### `questions` — 真题表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 自增主键 |
| type | String | 题型：听力/选词填空/长篇阅读/仔细阅读/翻译/写作 |
| year | String | 年份 |
| content | String | 题干 |
| passage | String | 阅读文章内容 |
| options | String | 选项(JSON数组字符串) |
| answer | String | 正确答案 |
| explanation | String | 解析 |
| audio_url | String | 听力音频 URL |

#### `study_records` — 学习记录表（艾宾浩斯算法驱动）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 自增主键 |
| word_id | int | 外键→words.id |
| user_id | int | 固定为 1 |
| status | String | 未学/学习中/已掌握/已遗忘 |
| correct_count | int | 正确次数（决定复习间隔） |
| wrong_count | int | 错误次数 |
| last_study_time | String | 最后学习时间(ISO8601) |
| next_review_time | String | 下次复习时间(ISO8601) |

#### `user_settings` — 用户设置表
| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | int | 固定为 1 |
| base_url | String | API Base URL |
| api_key | String | API 密钥 |
| model_name | String | 模型名称 |
| api_timeout | int | API 超时秒数 |
| daily_word_count | int | 每日背词目标 (10-200，默认10) |
| theme_mode | String | system/light/dark |
| font_size | double | 字体缩放 (0.8-1.5) |
| sound_enabled | int | 音效开关 0/1 |
| checkin_days | int | 连续打卡天数 |
| total_study_days | int | 总学习天数 |
| last_checkin_date | String | 上次打卡日期 |

#### `word_bookmarks` — 生词本
| 字段 | 说明 |
|------|------|
| word_id | 外键→words.id |
| user_id | 固定为 1 |
| created_at | 收藏时间 |

#### `wrong_questions` — 错题本
| 字段 | 说明 |
|------|------|
| question_id | 外键→questions.id |
| user_id | 固定为 1 |
| user_answer | 用户错误答案 |
| add_time | 收录时间 |

#### `ai_conversations` — AI 对话历史
| 字段 | 说明 |
|------|------|
| role | user/assistant |
| content | 消息内容 |
| timestamp | 时间戳 |

#### `agent_logs` — Agent 操作审计
| 字段 | 说明 |
|------|------|
| action | 操作类型 |
| params | JSON 参数 |
| result | 执行结果 |
| action_id | 操作 ID |
| timestamp | 时间戳 |

---

## 4. Provider 状态管理

### 4.1 注册树（main.dart）

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => NavigationProvider()),
    ChangeNotifierProvider(create: (_) => StudyProvider()),
    ChangeNotifierProvider.value(value: userProvider),
    ChangeNotifierProvider(create: (_) {
      final aiProvider = AiProvider();
      if (userProvider.isApiConfigured) {
        aiProvider.initApi(userProvider.apiKey!, baseUrl: userProvider.baseUrl, ...);
      }
      return aiProvider;
    }),
  ],
  child: const Cet4App(),
)
```

### 4.2 数据种子流程

```
启动 → WidgetsFlutterBinding.ensureInitialized()
→ MemoryStorage().init()      // 加载 8 个小表，words 懒加载
→ 版本检查(_dataVersion=2)     // 版本过期则清空旧数据
→ _seedDefaultData()
  → words 表为空 → 优先从 assets/pdf/ 解析 → 失败回退到 assets/data/words.json
  → questions 表为空 → 从 assets/data/questions.json 加载
→ UserProvider.initUserSettings()  // 无记录插入默认值，有则加载
→ runApp
```

---

## 5. 核心功能实现

### 5.1 背单词功能

```
词汇页点击"开始背诵(N词)" → loadTodayWords(goal)
  → rawQuery("SELECT ... FROM words LEFT JOIN study_records ... WHERE status='未学' ORDER BY RANDOM() LIMIT ?")
  → 跳转 WordStudyPage
  → 翻卡动画 → 点击"认识"→正确 / "不认识"→错误
  → updateWordStudyStatus(wordId, isCorrect)
  → EbbinghausAlgorithm.updateStudyRecord() 计算 next_review_time
  → 全部完成 → 总结页 → 返回词汇页 → loadTodayData() 刷新
```

**艾宾浩斯算法核心：**

```dart
class EbbinghausAlgorithm {
  static const List<int> _reviewIntervals = [1, 2, 4, 7, 15, 30]; // 天

  static DateTime calculateNextReviewTime(int correctCount, DateTime lastStudyTime) {
    int idx = correctCount.clamp(0, _reviewIntervals.length - 1);
    return lastStudyTime.add(Duration(days: _reviewIntervals[idx]));
  }

  static Map<String, dynamic> updateStudyRecord({
    bool isCorrect, int currentCorrectCount, int currentWrongCount, String currentStatus,
  }) {
    // 正确 → correctCount++ → ≥3 次 → 已掌握
    // 错误 → wrongCount++ → 已遗忘，correctCount 归零
  }
}
```

### 5.2 刷题功能

```
题库页 → 从 questions 表加载 → 按题型/Part 分组
→ Part I Writing / Part II Listening / Part III Reading / Part IV Translation
→ 用户点击选项 → 记录答案 → 自动显示解析
→ 答题卡网格视图（底部弹窗）→ 已答/未答 着色
→ 底部"上一题/下一题"导航
```

### 5.3 打卡统计逻辑

```
loadTodayData()
→ 统计今日已学单词数(todayStudyCount)
→ 读取每日目标(daily_word_count)
→ if todayStudyCount >= dailyGoal:
    _dailyGoalReached = true
    _autoCheckin() → checkin_days++, total_study_days++
    首页 consumeGoalReached() → 弹出恭喜弹窗(仅一次)
→ 计算未来 7 天复习预测(reviewForecast)
   遍历 study_records.next_review_time → 按天分桶[0-6]
```

### 5.4 内置 AI Agent 实现原理 ★

**完整流程图：**

```
用户发送自然语言 "把abandon的释义改成放弃"
  ↓
_sendMessage() 打包：
  systemPrompt = _agentSystemPrompt (含 Agent 编辑指令)
  responseFormatJson: true → API 请求 body 中加入 "response_format":{"type":"json_object"}
  ↓
AI 返回纯 JSON：
{"action":"update_word","params":{"target":"abandon","field":"meaning","newValue":"放弃"},"confirmMessage":"将abandon的释义修改为：放弃"}
  ↓
AgentExecutor.tryParseCommand(response) — 3 种策略：
  1. jsonDecode 整个文本
  2. 正则提取 ```json ... ``` 代码块
  3. 正则匹配 {...\"action\"...} 内嵌 JSON
  ↓
命中 → deleteLastAssistantMessage() 删除原始 JSON
  ↓
_handleAgentCommand() → 确认弹窗（图标 + 颜色 + 操作类型标题 + 确认信息）
  ↓
用户确认 → AgentExecutor().execute(command, userProvider)
  ↓
execute() 内部流程：
  1. 生成 actionId
  2. 字段校验(_validateWordFields) → 必填检查 + 字段名合法性
  3. 操作前快照(_takeSnapshot) → 保存原始记录到 _snapshots Map
  4. 执行 DB 操作(update/insert/delete)
  5. 审计日志(_auditLog) → 写入 agent_logs 表
  6. 返回结果文本
  ↓
结果显示在聊天气泡 + saveAssistantMessage() 持久化
  ↓
支持 rollback(actionId) 回滚操作
```

**Agent 系统提示词（_agentSystemPrompt，第 41-55 行）：**

```
你是CET4备考助手的内置编辑Agent。根据用户指令自动切换工作模式：

【Agent编辑模式】当用户要求增删改词库/题库数据时，只返回纯JSON（不要加```json```标记，不要任何额外文字）：

可修改的单词字段：word(单词), meaning(释义), phonetic_uk(英式音标), phonetic_us(美式音标), type(词性), example(例句), example_translation(例句翻译), collocation(搭配), level(级别)
可修改的题目字段：content(题干), options(选项), answer(答案), explanation(解析), type(题型), year(年份)

JSON格式（必须包含action、params、confirmMessage三个字段）：
{"action":"update_word","params":{"target":"要改的单词","field":"字段名","newValue":"新内容"},"confirmMessage":"用户可见的确认信息"}
{"action":"add_word","params":{"word":"单词","meaning":"释义","type":"词性","phonetic_uk":"音标","example":"例句","example_translation":"例句翻译","collocation":"搭配","level":"级别"},"confirmMessage":"用户可见的确认信息"}
{"action":"delete_word","params":{"target":"要删的单词"},"confirmMessage":"用户可见的确认信息"}
{"action":"update_question","params":{"target":"题目关键词","field":"字段名","newValue":"新内容"},"confirmMessage":"用户可见的确认信息"}
{"action":"set_daily_goal","params":{"newValue":30},"confirmMessage":"用户可见的确认信息"}

【普通辅导模式】用户提问、咨询、练习等非修改类问题时，作为专业的大学英语四级备考老师正常回复。用简洁中文，重点突出，符合四级考试要求。
```

**AgentExecutor 核心实现（agent_executor.dart）：**

```dart
class AgentExecutor {
  final DbHelper _dbHelper = DbHelper();
  final Map<String, _SnapshotEntry> _snapshots = {};
  static const int _maxSnapshots = 50;

  // 字段映射（支持中英文）
  static const Map<String, String> _wordFieldMapping = {
    'meaning': 'meaning', '释义': 'meaning',
    'phonetic': 'phonetic_uk', '音标': 'phonetic_uk',
    'type': 'type', '词性': 'type',
    'example': 'example', '例句': 'example',
    'collocation': 'collocation', '搭配': 'collocation',
    'level': 'level', '级别': 'level',
  };

  // 3 种 JSON 解析策略
  static Map<String, dynamic>? tryParseCommand(String text) { ... }

  // 执行入口 — 快照 → 校验 → 执行 → 审计
  Future<String> execute(Map<String, dynamic> command, {UserProvider? up}) async {
    final actionId = _generateActionId();
    String result;
    try {
      switch (command['action']) {
        case 'update_word':  result = await _updateWord(params, actionId);
        case 'add_word':     result = await _addWord(params, actionId);
        case 'delete_word':  result = await _deleteWord(params, actionId);
        case 'update_question': result = await _updateQuestion(params, actionId);
        case 'set_daily_goal':  result = await _setDailyGoal(params, up, actionId);
      }
    } catch (e) { result = '操作执行失败: $e'; }
    await _auditLog(action, params, result, actionId);  // 写入 agent_logs
    return result;
  }

  // 快照 + 校验 + 执行
  Future<String> _updateWord(Map params, String actionId) async {
    // 1. 校验必填字段
    if (newValue == null || newValue.toString().trim().isEmpty) return 'ERROR: 字段值不能为空';
    // 2. 校验字段名
    final dbField = _wordFieldMapping[field];
    if (dbField == null) return 'ERROR: 不支持的字段「$field」';
    // 3. 查找单词 + 快照
    final matched = words.where(...).toList();
    await _takeSnapshot(actionId, 'update_word', params, matched);
    // 4. 执行更新
    await _dbHelper.update('words', {dbField: newValueStr}, where: 'word = ?', ...);
    return '已成功...';
  }

  // 回滚
  Future<String> rollback(String actionId) async { ... }
}
```

### 5.5 MemoryStorage 性能优化核心

```
问题：1500+ 词全量序列化为一个 SharedPreferences key
      → 每次修改序列化全部数据

优化：
1. 分片：a-z + _other 共 27 个分片
2. 增量写入：_saveWordsShard(sliceKey) 只写变更分片
3. 索引缓存：_wordIdIndex + _wordTextIndex → O(1) 查找
4. 懒加载：init() 只加载 8 个小表，words 首次访问时加载
5. 自动迁移：_migrateWordsIfNeeded() 检测旧 mem_words 并拆分

代码片段：
void _ensureWordsLoaded() {
  if (_wordsLoaded) return;
  _migrateWordsIfNeeded();  // 自动迁移旧格式
  for (final sliceKey in _allWordShardKeys()) {
    _loadTable(_shardTableName(sliceKey));  // 加载 mem_words_a, mem_words_b...
  }
  _wordsLoaded = true;
}

// 插入 → 自动分片 + 增量持久化
Future<int> insert(String table, Map data, {bool saveNow = true}) async {
  if (_shardableTables.contains(table)) {
    final sliceKey = _shardKeyForWord(row['word']);
    _tables[shardName]!.add(row);
    if (saveNow) await _saveWordsShard(sliceKey);  // 只写一个分片
  }
}

// 索引加速查询
Future<List<Map>> query(String table, {String? where, List? whereArgs}) async {
  if (where == 'word = ?') {
    _ensureWordsIndexBuilt();
    final hit = _wordTextIndex[whereArgs[0].toLowerCase()];
    return hit != null ? [Map.from(hit)] : [];  // O(1)
  }
  // 否则扫描所有分片
}
```

---

## 6. API 接口说明

### 6.1 OpenAI 兼容格式

```
Method:  POST
URL:    {baseUrl}/chat/completions
Headers:
  Authorization: Bearer {apiKey}
  Content-Type:  application/json

Request (普通模式):
{
  "model": "gpt-4o-mini",
  "max_tokens": 2048,
  "temperature": 0.7,
  "messages": [
    {"role": "system", "content": "{系统提示词}"},
    {"role": "user", "content": "{用户消息}"}
  ]
}

Request (Agent JSON 模式):
{
  "model": "gpt-4o-mini",
  "max_tokens": 2048,
  "temperature": 0.7,
  "response_format": {"type": "json_object"},
  "messages": [...]
}

Response:
{
  "choices": [{"message": {"content": "{AI回复}"}}]
}
```

### 6.2 配置存储

- 位置：`user_settings` 表的 `base_url`、`api_key`、`model_name`、`api_timeout` 字段
- 默认值：`base_url=https://api.openai.com/v1`，`model=gpt-4o-mini`，`timeout=60s`
- 用户可在"我的" → "API 设置"修改，支持任何 OpenAI 兼容接口（DeepSeek/Ollama/酒馆等）

### 6.3 ClaudeApiService 错误码映射

| HTTP 状态码 | 中文错误提示 |
|-------------|-------------|
| 401 | API密钥无效 |
| 403 | API权限不足 |
| 429 | 请求过于频繁 |
| 500 | 服务器内部错误 |
| 超时 | 连接超时/发送超时/接收超时 |
| 网络错误 | 网络错误，请检查连接 |

---

## 7. 已知问题和待办事项

### 7.1 已知 Bug

| # | 描述 | 位置 | 严重程度 |
|---|------|------|----------|
| 1 | MemoryStorage rawQuery 不支持复杂 SQL（嵌套查询/聚合函数） | memory_storage.dart | 中 |
| 2 | Android SharedPreferences 大 JSON 读写有单 key 1MB 限制（分片后已缓解） | memory_storage.dart | 低 |
| 3 | PDF 导入对格式不规范的 PDF 识别率低 | pdf_parser_service.dart | 中 |
| 4 | widget_test.dart 未注入 Provider 导致测试失败 | test/widget_test.dart | 低 |

### 7.2 待办功能

| # | 描述 | 优先级 |
|---|------|--------|
| 1 | 听力音频播放功能（audio_url 已有，无播放器） | 中 |
| 2 | 模拟考试模式（限时全真模拟） | 中 |
| 3 | 学习提醒通知（本地推送） | 中 |
| 4 | AI 流式响应（SSE 已实现，AI 聊天页未使用） | 低 |
| 5 | 数据云同步（跨设备） | 低 |
| 6 | 学习数据趋势图表（周/月/学期统计） | 低 |

---

## 8. 打包发布注意事项

### 8.1 Android 打包

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
cd cet4_app
flutter clean && flutter pub get
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # → Google Play AAB
```

### 8.2 Web 构建

```bash
flutter build web --release         # → build/web/
flutter run -d web-server --web-port 8080 --release
```

### 8.3 检查清单

- [x] `usesCleartextTraffic=true` 保留（支持 HTTP API）
- [x] `INTERNET` 权限存在
- [x] assets 目录包含 JSON/PDF 数据文件
- [x] 无 `dart:io` 引用
- [x] 无 `kIsWeb` 条件分支
- [x] `debugPrint()` 保留（全平台兼容）
- [x] `_dataVersion=2` 确保新版本清空旧格式数据

---

## 9. 词汇页面核心代码（vocabulary_page.dart:256-335）

```dart
Widget _buildWordCard(Word word) {
  final isBookmarked = _bookmarkedWordIds.contains(word.id);
  final isSelected = _selectedWordId == word.id;

  return GestureDetector(
    onTap: () {
      setState(() => _selectedWordId = word.id);
      _showWordDetail(word);
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300, width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：单词 + 收藏按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(word.word,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  softWrap: true, overflow: TextOverflow.clip,
                ),
              ),
              GestureDetector(
                onTap: () => _toggleBookmark(word),
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 22, color: isBookmarked ? Colors.red : Colors.grey[400],
                ),
              ),
            ],
          ),
          // 第二行：词性(灰) + 释义(黑) + 音标(蓝) — Wrap 自动换行
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (word.type.isNotEmpty)
                Text('${word.type} ', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              if (word.meaning.isNotEmpty)
                Text(word.meaning, style: const TextStyle(fontSize: 14, color: Colors.black87), softWrap: true),
              if (word.phoneticUk.isNotEmpty)
                Text('  ${word.phoneticUk}', style: TextStyle(fontSize: 13, color: Colors.blue.shade300)),
            ],
          ),
        ],
      ),
    ),
  );
}
```

---

## 10. AI 助手页面核心代码（ai_assistant_page.dart）

### 10.1 _sendMessage + Agent 检测（第 57-94 行）

```dart
Future<void> _sendMessage() async {
  final message = _messageController.text.trim();
  if (message.isEmpty) return;
  setState(() { _messages.add({'role': 'user', 'content': message}); _isLoading = true; });
  _messageController.clear(); _scrollToBottom();

  try {
    final aiProvider = context.read<AiProvider>();
    final response = await aiProvider.sendMessage(
      message,
      systemPrompt: _agentSystemPrompt,
      responseFormatJson: true,  // JSON mode 强制 AI 返回合法 JSON
    );
    if (!mounted) return;

    final command = AgentExecutor.tryParseCommand(response);

    if (command != null) {
      await aiProvider.deleteLastAssistantMessage();
      setState(() => _isLoading = false);
      await _handleAgentCommand(command, aiProvider);
    } else {
      setState(() { _messages.add({'role': 'assistant', 'content': response}); _isLoading = false; });
    }
    _scrollToBottom();
  } catch (e) { /* error handling */ }
}
```

### 10.2 _handleAgentCommand 确认弹窗（第 106-169 行）

```dart
Future<void> _handleAgentCommand(Map<String, dynamic> command, AiProvider aiProvider) async {
  final confirmMessage = command['confirmMessage'] as String? ?? '确认执行此操作？';
  final action = command['action'] as String? ?? '';
  if (!mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(_actionIcon(action), color: _actionColor(action), size: 24),
        const SizedBox(width: 8), Text(_actionTitle(action)),
      ]),
      content: Text(confirmMessage),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: _actionColor(action)),
          child: const Text('确认执行'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final userProvider = context.read<UserProvider>();
    final result = await AgentExecutor().execute(command, userProvider: userProvider);
    setState(() { _messages.add({'role': 'assistant', 'content': result}); });
    await aiProvider.saveAssistantMessage(result);
  } else {
    setState(() { _messages.add({'role': 'assistant', 'content': '操作已取消'}); });
    await aiProvider.saveAssistantMessage('操作已取消');
  }
}

// 颜色/图标映射
IconData _actionIcon(String action) { ... }
Color _actionColor(String action) {
  switch (action) {
    case 'delete_word': return Colors.red;
    case 'add_word': return Colors.green;
    default: return Colors.blue;
  }
}
```

---

## 11. pubspec.yaml 完整内容

```yaml
name: cet4_app
description: 英语四级备考 APP（AI 增强版）
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  shared_preferences: ^2.2.2
  dio: ^5.4.0
  path: ^1.8.3
  file_picker: ^8.0.0
  syncfusion_flutter_pdf: ^26.1.35
  fl_chart: ^0.69.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  assets:
    - assets/data/
    - assets/audio/
    - assets/pdf/
```

---

## 12. 依赖用途速查

| 依赖 | 用途 | 注意事项 |
|------|------|----------|
| provider | 状态管理 | ChangeNotifier + Consumer2 |
| shared_preferences | 键值对持久化 | Web=localStorage，Android=SharedPreferences |
| dio | HTTP 客户端 | 支持拦截器/取消/超时/SSE |
| syncfusion_flutter_pdf | PDF 文本提取 | 纯 Dart，全平台，无需原生 |
| fl_chart | 数据图表 | PieChart + BarChart，Web 兼容 |
| file_picker | 文件选择 | PDF 手动导入 |
| path | 跨平台路径 | 路径拼接与解析 |
