# CET4 英语四级备考 APP - Trae 云端迁移完整提示词

## 项目概述

这是一个基于 **Flutter 3.x** 开发的英语四级备考 APP（AI 增强版），需要迁移到 Trae 云端环境继续开发。

- **项目名称**: cet4_app
- **Flutter SDK**: >=3.0.0 <4.0.0
- **状态管理**: Provider (ChangeNotifier)
- **本地存储**: SharedPreferences + 自定义 MemoryStorage
- **AI API**: OpenAI 兼容格式 (Claude/Dify/自定义)
- **UI 设计**: Material 3，支持亮/暗主题切换

---

## 一、项目文件结构

```
cet4_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                    # 入口：初始化数据、Provider、通知服务
│   ├── app.dart                     # 根组件：主题系统、底部导航、5个主页面
│   ├── components/
│   │   ├── word_card.dart           # 单词卡片组件
│   │   ├── question_item.dart       # 题目展示组件
│   │   ├── ai_message_bubble.dart   # AI消息气泡组件
│   │   └── audio_player.dart        # 音频播放器（倍速、循环、进度条）
│   ├── database/
│   │   ├── db_helper.dart           # 数据库操作封装（统一接口）
│   │   ├── memory_storage.dart      # Web平台内存存储（words分片a-z+other，800KB分片，索引缓存）
│   │   └── tables/                  # 数据表定义（words, study_records, questions, user_settings等）
│   ├── models/
│   │   ├── word.dart                # 单词模型
│   │   ├── question.dart            # 题目模型
│   │   ├── exam.dart                # 考试模型
│   │   └── ai_message.dart          # AI消息模型
│   ├── pages/
│   │   ├── home/home_page.dart                  # 首页：今日概览、学习进度、快速入口
│   │   ├── vocabulary/
│   │   │   ├── vocabulary_page.dart             # 词汇浏览页
│   │   │   ├── word_study_page.dart             # 单词学习页（认识/不认识）
│   │   │   └── lock_screen_words_page.dart      # 锁屏单词学习（深色主题、翻转卡片）
│   │   ├── question_bank/
│   │   │   ├── exam_home_page.dart              # 题库首页
│   │   │   ├── year_paper_page.dart             # 年份真题页
│   │   │   ├── exam_page.dart                   # 模拟考试页（倒计时、交卷）
│   │   │   ├── exam_answer_page.dart            # 答题页
│   │   │   └── exam_result_page.dart            # 考试结果页
│   │   ├── ai_assistant/ai_assistant_page.dart  # AI助手页（流式响应、Agent命令）
│   │   ├── profile/
│   │   │   ├── profile_page.dart                # 个人中心
│   │   │   ├── notification_settings_page.dart  # 通知设置
│   │   │   ├── study_statistics_page.dart       # 学习统计图表（fl_chart）
│   │   │   └── cloud_sync_page.dart             # 云同步管理
│   │   ├── import/pdf_import_page.dart          # PDF导入页
│   │   ├── word_book/                           # 单词本管理
│   │   └── wrong_questions/wrong_questions_page.dart
│   ├── provider/
│   │   ├── navigation_provider.dart   # 底部导航状态（0-4索引）
│   │   ├── study_provider.dart        # 学习状态：今日单词、复习、进度、打卡
│   │   ├── user_provider.dart         # 用户设置：主题、字体、API密钥、每日目标
│   │   └── ai_provider.dart           # AI状态：对话、流式请求、单词讲解、作文批改
│   ├── services/
│   │   ├── pdf_parser_service.dart    # PDF解析（从assets或文件导入词汇/真题）
│   │   ├── notification_service.dart  # 本地通知（学习提醒、复习提醒、打卡提醒）
│   │   ├── sync_service.dart          # 云同步（全量备份、增量同步、恢复）
│   │   └── lock_screen_service.dart   # 锁屏单词服务设置
│   └── utils/
│       ├── claude_api.dart            # OpenAI兼容API客户端（SSE流式、缓存、取消）
│       ├── agent_executor.dart        # Agent命令解析执行器（update_word/add_word/delete_word等）
│       ├── ebbinghaus_algorithm.dart  # 艾宾浩斯遗忘曲线算法
│       ├── batch_word_filler.dart     # 批量词库填充引擎
│       ├── json_loader.dart           # JSON数据加载器
│       └── cet4_offline_wordbank.dart # 离线词库
├── assets/
│   ├── data/words.json                # 默认词汇数据
│   ├── data/questions.json            # 默认题库数据
│   ├── data/exams.json                # 考试数据
│   ├── audio/                         # 音频资源
│   └── pdf/                           # PDF资源（1500核心词等）
└── web/                               # Web构建配置
    ├── index.html
    ├── manifest.json
    └── icons/
```

---

## 二、核心依赖 (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1              # 状态管理
  shared_preferences: ^2.2.2   # 本地持久化存储
  dio: ^5.4.0                  # HTTP客户端（AI API调用）
  path: ^1.8.3                 # 路径处理
  file_picker: ^8.0.0          # 文件选择（导入PDF）
  syncfusion_flutter_pdf: ^26.1.35  # PDF解析
  fl_chart: ^0.69.0            # 图表（学习统计）
  just_audio: ^0.9.36          # 音频播放
  audio_session: ^0.1.18       # 音频会话管理
  flutter_local_notifications: ^18.0.1  # 本地通知
  timezone: ^0.10.0            # 时区处理
  intl: ^0.19.0                # 国际化/格式化

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

---

## 三、关键架构说明

### 3.1 数据流架构

```
UI Pages → Components → Providers → Services → Database → Models
```

### 3.2 存储系统 (MemoryStorage)

- **Web平台**: SharedPreferences 模拟数据库存储
- **words表分片**: 按首字母 a-z + _other 分片，避免单key 1MB限制
- **大表分片**: 超过800KB自动拆分为多个chunk存储
- **索引缓存**: wordId索引 + wordText索引加速查询
- **懒加载**: words表首次访问时才加载

### 3.3 艾宾浩斯复习算法

```
正确次数 → 复习间隔:
0次 → 1天, 1次 → 2天, 2次 → 4天, 3次 → 7天, 4次 → 15天, 5+次 → 30天

状态转换:
未学 → 学习中(正确≥1次) → 已掌握(正确≥3次)
任何状态 + 错误1次 → 已遗忘(正确重置为0)
```

### 3.4 AI 系统架构

```
用户输入 → AiProvider
  ├── 普通对话 → sendMessageStream() → SSE流式响应 → 实时UI更新
  └── Agent命令 → sendMessage(responseFormatJson=true) → JSON解析 → AgentExecutor执行数据库操作

AI功能:
- explainWord(word)      # 单词讲解
- explainQuestion(q,a)   # 题目解析
- correctWriting(topic,content)  # 作文批改
- correctTranslation(orig,trans) # 翻译批改
- testConnection()       # API连接测试
```

### 3.5 Agent 执行器

支持的操作类型：`update_word`, `add_word`, `delete_word`, `update_question`, `set_daily_goal`, `batch_update_words`, `list_words`, `offline_import_full_wordbank`

- 操作前保存快照（内存缓存，最多50条）
- 支持撤销修改
- 批量更新words表（多字段×多单词，每个分片仅保存一次）

---

## 四、主题系统

### 亮色主题
- Primary: `#4F46E5` (靛蓝)
- Secondary: `#F59E0B` (琥珀)
- Surface: `#FAFAFB`
- Background: `#F8F9FC`
- Error: `#EF4444`

### 暗色主题
- Primary: `#818CF8`
- Secondary: `#FBBF24`
- Surface: `#111827`
- Background: `#0B0F19`
- Error: `#FCA5A5`

### 底部导航
- 5个页面：首页(0)、词汇(1)、题库(2)、AI(3)、我的(4)
- 自定义 `_NavItem` 组件：AnimatedContainer + AnimatedScale + AnimatedDefaultTextStyle
- 选中状态：背景色变化 + 图标放大1.15x + 文字加粗

---

## 五、关键代码片段

### 5.1 main.dart 初始化流程

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MemoryStorage().init();
  // 数据版本检查（_dataVersion=2，变更则清除旧数据重新导入）
  await _seedDefaultData(); // 从PDF或JSON导入默认词汇和题库
  // 初始化UserProvider、NotificationService
  // 配置MultiProvider → 启动Cet4App
}
```

### 5.2 API 配置

- 默认 Base URL: `https://api.openai.com/v1`
- 默认模型: `gpt-4o-mini`
- 支持自定义 API Key、Base URL、模型名、超时时间
- 配置位置：个人中心 → API设置

### 5.3 数据表结构

**words表**: id, word, phonetic_uk, phonetic_us, audio_uk, audio_us, type, meaning, example, example_translation, collocation, level

**study_records表**: id, word_id, user_id, status(未学/学习中/已掌握/已遗忘), correct_count, wrong_count, last_study_time, next_review_time

**questions表**: id, type, year, content, passage, options(JSON), answer, explanation, audio_url

---

## 六、已完成的功能清单

### 核心功能
- [x] 词汇记忆（4500+单词，艾宾浩斯复习）
- [x] 真题题库（近10年真题，6大题型）
- [x] 模拟考试（全真流程，倒计时，自动打分）
- [x] AI助手（流式对话、单词讲解、题目解析）
- [x] AI批改（作文批改、翻译批改）
- [x] Agent执行器（AI直接操作数据库）

### 增强功能
- [x] 音频播放器（倍速0.5x-2.0x、循环模式、进度条）
- [x] 本地通知（学习提醒、复习提醒、打卡提醒）
- [x] 学习统计图表（周/月/学期，fl_chart）
- [x] 云同步（全量备份、增量同步、恢复）
- [x] 锁屏单词学习（深色主题、翻转卡片）
- [x] PDF导入（从文件导入词汇和真题）
- [x] 单词本管理
- [x] 错题本

### UI/UX
- [x] Material 3 设计系统
- [x] 亮/暗主题切换
- [x] 字体大小调节
- [x] 自定义底部导航栏
- [x] 渐变头部、卡片布局、动画过渡

---

## 七、已知兼容性问题

1. **Flutter SDK >=3.0.0**: 使用 `withOpacity()` 而非 `withValues(alpha:)`
2. **ColorScheme**: 使用 `surfaceVariant` 而非 `surfaceContainerHighest`
3. **Web端限制**: 本地通知、音频播放可能受限；数据存于LocalStorage
4. **PowerShell**: 不支持 `&&` 链式命令，使用 `;` 分隔

---

## 八、迁移到 Trae 后的建议

### 立即检查项
1. 运行 `flutter doctor` 确认环境完整
2. 运行 `flutter pub get` 安装依赖
3. 检查 `android/` 和 `ios/` 目录是否存在（如缺失需 `flutter create .` 重建）
4. 运行 `flutter build web` 测试构建

### 开发注意事项
- **不要修改** `memory_storage.dart` 的分片逻辑（已稳定运行）
- **API密钥** 需要从用户设置中重新配置
- **数据迁移**: Web端数据存于浏览器LocalStorage，跨设备不共享
- **新增页面** 需在 `app.dart` 的 `pages` 数组和底部导航中注册

### 推荐下一步开发
1. 真题听力音频资源补充
2. 写作/翻译模板库扩充
3. AI智能出题功能
4. 用户学习报告导出
5. 社交分享（打卡分享图）

---

## 九、GitHub Pages 部署状态

- 构建目录: `cet4_app/build/web/`
- Git仓库: 已初始化于 `build/web/.git/`
- 访问地址: `https://10713.github.io/cet4-web`（启用GitHub Pages后）
- 部署指南: 见 `DEPLOY_GUIDE.md`

---

*生成时间: 2026-05-13*
*文档版本: 1.0*
