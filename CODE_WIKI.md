# CET4 英语四级备考 APP - Code Wiki

## 1. 项目概述

### 1.1 项目简介

CET4 英语四级备考 APP（AI 增强版）是一款基于 Flutter 开发的轻量化、无广告、离线优先 + AI 增强的大学英语四级备考应用程序。

### 1.2 核心功能

| 功能模块 | 描述 |
|---------|------|
| 词汇记忆 | 4500+ 四级考纲词汇，艾宾浩斯遗忘曲线复习算法 |
| 真题题库 | 近 10 年四级全套真题，六大题型专项练习 |
| 听力专项 | 配套音频播放，倍速控制，精听模式 |
| 作文翻译 | 模板库、用户编辑、草稿保存 |
| 模拟考试 | 全真考试流程，倒计时，自动打分 |
| AI 增强 | 单词讲解、题目解析、作文批改、翻译批改、智能助手 |

### 1.3 技术栈

| 技术类别 | 技术选型 |
|---------|---------|
| 前端框架 | Flutter |
| 状态管理 | Provider |
| 本地存储 | SharedPreferences + 内存存储 |
| HTTP 客户端 | Dio |
| PDF 解析 | Syncfusion Flutter PDF |
| 图表展示 | fl_chart |
| AI API | OpenAI/Claude 兼容接口 |

---

## 2. 项目架构

### 2.1 目录结构

```
cet4_app/
├── lib/
│   ├── main.dart                 # 项目入口，初始化数据
│   ├── app.dart                 # 应用根组件，主题配置
│   ├── components/              # 公共组件
│   │   ├── ai_message_bubble.dart
│   │   ├── question_item.dart
│   │   └── word_card.dart
│   ├── database/                 # 数据库层
│   │   ├── db_helper.dart        # 数据库操作封装
│   │   ├── memory_storage.dart   # Web 平台内存存储
│   │   └── tables/               # 数据表定义
│   ├── models/                   # 数据模型
│   │   ├── ai_message.dart
│   │   ├── exam.dart
│   │   ├── question.dart
│   │   └── word.dart
│   ├── pages/                    # 页面模块
│   │   ├── ai_assistant/
│   │   ├── home/
│   │   ├── import/
│   │   ├── profile/
│   │   ├── question_bank/
│   │   ├── vocabulary/
│   │   ├── word_book/
│   │   └── wrong_questions/
│   ├── provider/                 # 状态管理
│   │   ├── ai_provider.dart
│   │   ├── navigation_provider.dart
│   │   ├── study_provider.dart
│   │   └── user_provider.dart
│   ├── services/                 # 服务层
│   │   └── pdf_parser_service.dart
│   └── utils/                    # 工具类
│       ├── agent_executor.dart
│       ├── batch_word_filler.dart
│       ├── cet4_offline_wordbank.dart
│       ├── claude_api.dart
│       ├── ebbinghaus_algorithm.dart
│       └── json_loader.dart
└── assets/
    ├── data/                     # JSON 数据文件
    ├── audio/                    # 音频资源
    └── pdf/                      # PDF 资源
```

### 2.2 架构分层

```
┌─────────────────────────────────────────────────────────────┐
│                      UI 层 (Pages)                          │
│  HomePage | VocabularyPage | ExamHomePage | AiAssistantPage │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   组件层 (Components)                        │
│         WordCard | QuestionItem | AiMessageBubble           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  状态管理层 (Providers)                       │
│  NavigationProvider | StudyProvider | UserProvider | AiProvider │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    服务层 (Services)                         │
│            PdfParserService | JsonLoader | ClaudeApi        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    数据层 (Database)                        │
│               DbHelper | MemoryStorage | Models             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 核心模块详解

### 3.1 入口与初始化 (main.dart)

**文件路径**: `lib/main.dart`

**主要职责**:
- 应用初始化入口
- 数据版本管理
- 默认数据自动导入
- Provider 初始化

**关键代码逻辑**:

```dart
void main() async {
  // 1. 初始化内存存储
  // 2. 检查数据版本，必要时清除旧数据
  // 3. 自动导入默认数据（PDF 或 JSON）
  // 4. 初始化用户设置
  // 5. 配置全局 Provider
  // 6. 启动应用
}
```

**数据版本控制**:
- 当前版本: `_dataVersion = 2`
- 版本变更会触发数据重新导入

### 3.2 应用根组件 (app.dart)

**文件路径**: `lib/app.dart`

**主要组件**:

| 组件 | 说明 |
|-----|------|
| `Cet4App` | 应用根组件，配置主题和媒体查询 |
| `MainScreen` | 主屏幕，底部导航栏管理 |

**主题配置**:
- Material 3 设计
- 支持亮色/暗色主题切换
- 字体大小可调节
- 跟随系统设置

### 3.3 状态管理 (Providers)

#### 3.3.1 NavigationProvider

**文件路径**: `lib/provider/navigation_provider.dart`

```dart
class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;  // 当前导航索引 (0-4)
  
  // 导航页面映射
  // 0: 首页, 1: 词汇, 2: 题库, 3: AI助手, 4: 我的
}
```

#### 3.3.2 StudyProvider

**文件路径**: `lib/provider/study_provider.dart`

**核心功能**:

| 方法 | 描述 |
|-----|------|
| `loadTodayData()` | 加载今日学习数据 |
| `loadTodayWords(count)` | 获取今日需要学习的新单词 |
| `loadReviewWords()` | 获取需要复习的单词 |
| `updateWordStudyStatus(wordId, isCorrect)` | 更新单词学习状态 |

**状态属性**:

| 属性 | 类型 | 说明 |
|-----|------|------|
| `todayWords` | List | 今日学习单词列表 |
| `reviewWords` | List | 需要复习的单词 |
| `studyProgress` | Map | 学习进度统计 |
| `todayStudyCount` | int | 今日学习数量 |
| `checkinDays` | int | 连续打卡天数 |
| `reviewForecast` | List | 未来7天复习预测 |

#### 3.3.3 UserProvider

**文件路径**: `lib/provider/user_provider.dart`

**用户设置管理**:

| 设置项 | 默认值 | 说明 |
|-------|--------|------|
| `themeMode` | ThemeMode.system | 主题模式 |
| `fontSize` | 1.0 | 字体缩放 |
| `dailyWordGoal` | 10 | 每日单词目标 |
| `soundEnabled` | true | 音效开关 |
| `apiKey` | null | AI API 密钥 |
| `baseUrl` | OpenAI URL | API 地址 |
| `modelName` | gpt-4o-mini | 模型名称 |
| `apiTimeout` | 60 | 超时时间(秒) |

#### 3.3.4 AiProvider

**文件路径**: `lib/provider/ai_provider.dart`

**AI 功能封装**:

| 方法 | 描述 |
|-----|------|
| `initApi(key, baseUrl, model)` | 初始化 API |
| `sendMessage(prompt)` | 发送普通请求 |
| `sendMessageStream(prompt)` | 发送流式请求 |
| `explainWord(word)` | AI 单词讲解 |
| `explainQuestion(question, answer)` | AI 题目解析 |
| `correctWriting(topic, content)` | AI 作文批改 |
| `correctTranslation(original, translation)` | AI 翻译批改 |
| `testConnection(apiKey, baseUrl)` | 测试 API 连接 |

---

## 4. 数据库设计

### 4.1 数据库架构

**存储策略**:
- Web 平台: SharedPreferences + 内存存储
- 移动平台: 原生 SQLite（通过 MemoryStorage 统一接口）

**words 表分片策略**:
- 按首字母分片 (a-z, other)
- 懒加载机制
- 索引缓存优化

### 4.2 数据表定义

#### 4.2.1 words 表

```sql
CREATE TABLE words (
  id INTEGER PRIMARY KEY,
  word TEXT,              -- 单词
  phonetic_uk TEXT,       -- 英式音标
  phonetic_us TEXT,       -- 美式音标
  audio_uk TEXT,          -- 英式发音路径
  audio_us TEXT,          -- 美式发音路径
  type TEXT,              -- 词性
  meaning TEXT,          -- 释义
  example TEXT,           -- 例句
  example_translation TEXT, -- 例句翻译
  collocation TEXT,        -- 固定搭配
  level TEXT              -- 词汇级别
);
```

#### 4.2.2 study_records 表

```sql
CREATE TABLE study_records (
  id INTEGER PRIMARY KEY,
  word_id INTEGER,        -- 关联单词ID
  user_id INTEGER,        -- 用户ID
  status TEXT,            -- 状态: 未学/学习中/已掌握/已遗忘
  correct_count INTEGER,  -- 正确次数
  wrong_count INTEGER,     -- 错误次数
  last_study_time TEXT,   -- 上次学习时间
  next_review_time TEXT   -- 下次复习时间
);
```

#### 4.2.3 questions 表

```sql
CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  type TEXT,              -- 题型
  year TEXT,              -- 年份
  content TEXT,            -- 题干
  passage TEXT,            -- 文章内容
  options TEXT,            -- 选项(JSON数组)
  answer TEXT,            -- 答案
  explanation TEXT,        -- 解析
  audio_url TEXT           -- 音频地址
);
```

#### 4.2.4 其他数据表

| 表名 | 描述 |
|-----|------|
| `user_settings` | 用户设置 |
| `exam_records` | 考试记录 |
| `wrong_questions` | 错题记录 |
| `word_bookmarks` | 单词收藏 |
| `ai_conversations` | AI 对话记录 |
| `ai_corrections` | AI 批改记录 |
| `agent_logs` | Agent 操作日志 |

---

## 5. 核心算法

### 5.1 艾宾浩斯遗忘曲线算法

**文件路径**: `lib/utils/ebbinghaus_algorithm.dart`

**复习间隔表**:

| 正确次数 | 复习间隔 |
|---------|----------|
| 0 | 1 天 |
| 1 | 2 天 |
| 2 | 4 天 |
| 3 | 7 天 |
| 4 | 15 天 |
| 5+ | 30 天 |

**状态转换规则**:

```
未学 → 学习中 (正确 ≥ 1次)
学习中 → 已掌握 (正确 ≥ 3次)
已掌握/学习中 → 已遗忘 (错误 1次，正确重置为0)
```

### 5.2 Agent 执行器

**文件路径**: `lib/utils/agent_executor.dart`

**支持的 Agent 操作**:

| 操作 | 描述 |
|-----|------|
| `update_word` | 更新单词字段 |
| `add_word` | 添加新单词 |
| `delete_word` | 删除单词 |
| `update_question` | 更新题目 |
| `set_daily_goal` | 设置每日目标 |
| `batch_update_words` | 批量更新单词 |
| `list_words` | 列出单词 |
| `offline_import_full_wordbank` | 离线导入完整词库 |

**回滚机制**:
- 操作快照保存（内存缓存，最多50条）
- 支持撤销修改

---

## 6. 关键服务

### 6.1 PDF 解析服务

**文件路径**: `lib/services/pdf_parser_service.dart`

**功能**:
- 从 PDF 提取词汇数据
- 从 PDF 提取真题题目
- 支持 Flutter assets 和手动导入

**解析格式**:
```
序号. 单词 [音标] 词性. 释义
```

### 6.2 Claude API 服务

**文件路径**: `lib/utils/claude_api.dart`

**特性**:
- OpenAI 兼容格式
- 支持流式响应（SSE）
- 请求缓存
- 取消机制
- 完整错误处理

### 6.3 批量词库填充引擎

**文件路径**: `lib/utils/batch_word_filler.dart`

**特性**:
- 分批次处理（50词/批）
- 持久化进度
- 中断恢复
- 失败重试

---

## 7. 页面模块

### 7.1 首页 (HomePage)

**路径**: `lib/pages/home/home_page.dart`

**功能**:
- 今日学习概览
- 学习进度展示
- 快速入口

### 7.2 词汇页 (VocabularyPage)

**路径**: `lib/pages/vocabulary/`

| 页面 | 描述 |
|-----|------|
| `vocabulary_page.dart` | 词汇浏览 |
| `word_study_page.dart` | 单词学习 |

### 7.3 题库页 (ExamHomePage)

**路径**: `lib/pages/question_bank/`

| 页面 | 描述 |
|-----|------|
| `exam_home_page.dart` | 题库首页 |
| `exam_page.dart` | 考试页面 |
| `exam_answer_page.dart` | 答题页面 |
| `exam_result_page.dart` | 结果页面 |
| `year_paper_page.dart` | 年份真题 |

### 7.4 AI 助手页 (AiAssistantPage)

**路径**: `lib/pages/ai_assistant/ai_assistant_page.dart`

**功能**:
- 智能对话
- AI 单词讲解
- AI 题目解析
- AI 作文批改

### 7.5 个人中心 (ProfilePage)

**路径**: `lib/pages/profile/profile_page.dart`

**功能**:
- 用户设置
- API 配置
- 数据管理

---

## 8. 依赖关系

### 8.1 项目依赖 (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1              # 状态管理
  shared_preferences: ^2.2.2   # 本地存储
  dio: ^5.4.0                  # HTTP 客户端
  path: ^1.8.3                  # 路径处理
  file_picker: ^8.0.0          # 文件选择
  syncfusion_flutter_pdf: ^26.1.35  # PDF 解析
  fl_chart: ^0.69.0            # 图表库

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

### 8.2 依赖关系图

```
┌─────────────┐
│   main.dart │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│              Provider 层                │
│  NavigationProvider | StudyProvider     │
│  UserProvider | AiProvider              │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│             Service 层                  │
│  PdfParserService | JsonLoader          │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│           Database 层                    │
│  DbHelper | MemoryStorage               │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│            Model 层                      │
│  Word | Question | Exam | AiMessage     │
└─────────────────────────────────────────┘
```

---

## 9. 项目运行

### 9.1 环境要求

| 要求 | 版本 |
|-----|------|
| Flutter SDK | >= 3.0.0 |
| Dart SDK | >= 3.0.0 |
| Android Studio | 最新版 |
| Xcode | 最新版 (iOS 开发) |

### 9.2 运行命令

```bash
# 安装依赖
flutter pub get

# 运行 Android
flutter run

# 运行 iOS (仅 macOS)
flutter run -d ios

# 运行 Web
flutter run -d chrome

# 构建 APK
flutter build apk --release

# 构建 Web
flutter build web
```

### 9.3 API 配置

1. 打开 APP，进入"我的"页面
2. 点击"API 设置"
3. 输入 API 密钥
4. 配置 Base URL（默认: https://api.openai.com/v1）
5. 选择模型（默认: gpt-4o-mini）

---

## 10. 数据流

### 10.1 应用启动流程

```
main() → 初始化 MemoryStorage → 检查数据版本
    → 导入默认数据 → 初始化 UserProvider
    → 配置 Provider → 启动 Cet4App
```

### 10.2 学习流程

```
加载单词 → 显示学习界面 → 用户答题
    → updateWordStudyStatus() → 艾宾浩斯算法计算下次复习时间
    → 保存学习记录 → 更新学习进度
```

### 10.3 AI 对话流程

```
用户发送消息 → AiProvider.sendMessage()
    → ClaudeApiService.sendMessage() → API 请求
    → 保存对话记录 → 显示回复
```

---

## 11. 附录

### 11.1 导航索引映射

| 索引 | 页面 |
|-----|------|
| 0 | HomePage (首页) |
| 1 | VocabularyPage (词汇) |
| 2 | ExamHomePage (题库) |
| 3 | AiAssistantPage (AI助手) |
| 4 | ProfilePage (我的) |

### 11.2 学习状态

| 状态 | 说明 |
|-----|------|
| 未学 | 尚未开始学习 |
| 学习中 | 正在学习 (正确 1-2 次) |
| 已掌握 | 完全掌握 (正确 >= 3 次) |
| 已遗忘 | 需要重新学习 |

### 11.3 题型分类

| 题型 | 说明 |
|-----|------|
| 听力 | 听力理解题 |
| 选词填空 | 选词填空题 |
| 长篇阅读 | 段落匹配题 |
| 仔细阅读 | 阅读理解题 |
| 翻译 | 中译英 |
| 写作 | 英文写作 |

---

*文档版本: 1.0*
*最后更新: 2026-05-13*
