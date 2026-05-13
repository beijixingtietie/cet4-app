# CET4 备考 APP - Dogfood 测试报告

## 执行摘要

本报告对 CET4 备考 APP 项目进行了系统性分析和测试，发现了 **多个关键问题**，其中最严重的是 **缺失整个源代码目录**，导致项目无法正常运行。

---

## 问题清单（按严重程度排序）

### 🔴 严重问题（Blocker）

#### 1. **缺失核心源代码目录 (`lib/`)**

**描述**：项目缺少了完整的 `lib/` 源代码目录，这是 Flutter 项目的核心。

**位置**：`/workspace/cet4_app/lib/` 不存在

**影响**：
- 项目无法编译或运行
- 所有功能都无法使用
- 测试文件无法执行（因为它们依赖于缺失的源文件）

**缺失文件列表**（根据测试文件和项目文档推断）：

| 文件路径 | 用途 |
|---------|------|
| `lib/main.dart` | 应用入口点 |
| `lib/app.dart` | 应用根组件 |
| `lib/models/word.dart` | 单词数据模型 |
| `lib/models/question.dart` | 问题数据模型 |
| `lib/models/exam.dart` | 考试数据模型 |
| `lib/database/db_helper.dart` | 数据库帮助类 |
| `lib/database/memory_storage.dart` | 内存存储实现 |
| `lib/provider/user_provider.dart` | 用户状态管理 |
| `lib/provider/study_provider.dart` | 学习状态管理 |
| `lib/provider/ai_provider.dart` | AI 状态管理 |
| `lib/provider/navigation_provider.dart` | 导航状态管理 |
| `lib/utils/agent_executor.dart` | AI Agent 执行器 |
| `lib/utils/batch_word_filler.dart` | 批量单词填充工具 |
| `lib/utils/ebbinghaus_algorithm.dart` | 艾宾浩斯算法 |
| `lib/utils/json_loader.dart` | JSON 加载器 |
| `lib/utils/claude_api.dart` | Claude API 工具 |
| `lib/pages/home/home_page.dart` | 首页 |
| `lib/pages/vocabulary/vocabulary_page.dart` | 词汇页 |
| `lib/pages/vocabulary/word_study_page.dart` | 单词学习页 |
| `lib/pages/question_bank/exam_page.dart` | 考试页 |
| `lib/pages/ai_assistant/ai_assistant_page.dart` | AI 助手页 |
| `lib/pages/profile/profile_page.dart` | 个人中心页 |
| `lib/pages/word_book/word_book_page.dart` | 单词本页 |
| `lib/pages/word_book/word_book_manager_page.dart` | 单词本管理页 |
| `lib/pages/wrong_questions/wrong_questions_page.dart` | 错题本页 |
| `lib/pages/import/pdf_import_page.dart` | PDF 导入页 |
| `lib/components/` | 可复用组件目录 |
| `lib/services/pdf_parser_service.dart` | PDF 解析服务 |

---

### 🟠 高优先级问题

#### 2. **词汇数据被错误截断**

**描述**：`assets/data/words.json` 文件中的单词数据存在严重的格式化问题，`type` 和 `meaning` 字段被错误地截断分离。

**位置**：`/workspace/cet4_app/assets/data/words.json`

**示例问题**：

```json
{
  "id": 1,
  "word": "peril",
  "type": "n.危",   // ❌ 应该是 "n."
  "meaning": "险"    // ❌ 应该是 "危险"
}
```

```json
{
  "id": 2,
  "word": "experienced",
  "type": "adj.有经验的；熟练",  // ❌ 应该是 "adj."
  "meaning": "的"                 // ❌ 应该是 "有经验的；熟练的"
}
```

**影响**：
- 用户会看到不完整或错误的单词解释
- 严重影响学习体验
- 需要数据清洗和修复

**修复建议**：
- 使用 `offline_wordbank_test.dart` 中提到的修复逻辑来清理数据
- 或者重新生成正确的数据文件

---

#### 3. **README 与 pubspec.yaml 依赖不一致**

**描述**：`README.md` 中列出的依赖与 `pubspec.yaml` 中的实际依赖不一致。

**位置**：
- `/workspace/cet4_app/README.md` (第 109-128 行)
- `/workspace/cet4_app/pubspec.yaml`

**不一致的地方**：

| 依赖 | README.md | pubspec.yaml |
|-----|----------|-------------|
| `cupertino_icons` | ✅ | ❌ |
| `sqflite` | ✅ | ❌ |
| `percent_indicator` | ✅ | ❌ |
| `fl_chart` | ✅ (0.66.0) | ✅ (0.69.0) |
| `table_calendar` | ✅ | ❌ |
| `flutter_slidable` | ✅ | ❌ |
| `cached_network_image` | ✅ | ❌ |
| `flutter_markdown` | ✅ | ❌ |
| `uuid` | ✅ | ❌ |
| `just_audio` | ❌ | ✅ |
| `audio_session` | ❌ | ✅ |
| `flutter_local_notifications` | ❌ | ✅ |
| `timezone` | ❌ | ✅ |
| `intl` | ❌ | ✅ |
| `file_picker` | ❌ | ✅ |
| `syncfusion_flutter_pdf` | ❌ | ✅ |

**影响**：
- 开发者会被误导
- 如果按照 README 安装依赖会失败

---

### 🟡 中优先级问题

#### 4. **assets/pdf/ 目录缺失**

**描述**：`pubspec.yaml` 中声明了 `assets/pdf/` 资源目录，但该目录不存在。

**位置**：
- `/workspace/cet4_app/pubspec.yaml` (第 35 行)
- `/workspace/cet4_app/assets/pdf/` 不存在

**影响**：
- 应用启动时可能会有警告
- PDF 导入功能可能无法正常工作

---

#### 5. **测试文件无法运行**

**描述**：所有测试文件都引用了缺失的源文件，导致无法执行。

**位置**：`/workspace/cet4_app/test/` 目录下的所有文件

**影响**：
- 无法验证代码质量
- 无法确保功能正确性

---

### 🟢 低优先级问题

#### 6. **重复的 assets/data/words.json**

**描述**：项目根目录和 `cet4_app/assets/data/` 目录下都有 `words.json` 文件，可能导致混淆。

**位置**：
- `/workspace/assets/data/words.json`
- `/workspace/cet4_app/assets/data/words.json`

---

## 项目结构对比

### 期望的完整结构（基于项目文档）

```
cet4_app/
├── lib/                          # ❌ 缺失！
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   │   ├── word.dart
│   │   ├── question.dart
│   │   └── exam.dart
│   ├── provider/
│   │   ├── user_provider.dart
│   │   ├── study_provider.dart
│   │   ├── ai_provider.dart
│   │   └── navigation_provider.dart
│   ├── database/
│   │   ├── db_helper.dart
│   │   ├── memory_storage.dart
│   │   └── tables/
│   ├── pages/
│   │   ├── home/
│   │   ├── vocabulary/
│   │   ├── question_bank/
│   │   ├── ai_assistant/
│   │   ├── profile/
│   │   ├── word_book/
│   │   ├── wrong_questions/
│   │   └── import/
│   ├── utils/
│   │   ├── claude_api.dart
│   │   ├── agent_executor.dart
│   │   ├── batch_word_filler.dart
│   │   ├── ebbinghaus_algorithm.dart
│   │   └── json_loader.dart
│   ├── components/
│   └── services/
│       └── pdf_parser_service.dart
├── assets/
│   ├── data/                     # ✅ 存在
│   ├── audio/                    # ✅ 存在（只有 .gitkeep）
│   └── pdf/                      # ❌ 缺失
├── test/                         # ✅ 存在
├── android/                      # ✅ 存在
├── web/                          # ✅ 存在
└── pubspec.yaml                  # ✅ 存在
```

---

## 修复建议优先级

### 立即修复（P0）

1. **恢复或重建 `lib/` 源代码目录**
   - 检查 git 历史或备份
   - 如果无法恢复，根据项目文档和测试文件重新实现

2. **修复 `words.json` 数据文件**
   - 使用测试文件中的逻辑清理数据
   - 确保 `type` 和 `meaning` 字段正确

### 尽快修复（P1）

3. **创建 `assets/pdf/` 目录**
4. **更新 README.md 以匹配实际依赖**

### 后续优化（P2）

5. **清理重复的文件**
6. **运行所有测试验证修复**

---

## 总结

| 严重程度 | 数量 |
|---------|------|
| 🔴 严重 | 1 |
| 🟠 高 | 2 |
| 🟡 中 | 2 |
| 🟢 低 | 1 |
| **总计** | **6** |

**关键结论**：该项目处于 **无法运行状态**，主要因为核心源代码缺失。建议优先恢复源代码，然后依次修复其他问题。
