# CET4 英语四级备考 APP（AI 增强版）

一款基于 Flutter 开发的轻量化、无广告、离线优先 + AI 增强的大学英语四级备考 APP。

## 功能特性

### 核心功能
- **词汇记忆**：4500+ 四级考纲词汇，艾宾浩斯遗忘曲线复习算法
- **真题题库**：近 10 年四级全套真题，六大题型专项练习
- **听力专项**：配套音频播放，倍速控制，精听模式
- **作文 & 翻译**：模板库、用户编辑、草稿保存
- **模拟考试**：全真考试流程，倒计时，自动打分

### AI 增强功能
- **AI 单词讲解**：个性化单词讲解、词根词缀分析
- **AI 题目解析**：深度解题思路、知识点讲解
- **AI 作文批改**：按四级评分标准打分、逐句标注错误
- **AI 翻译批改**：对比标准译文、提供地道表达
- **AI 听力翻译**：逐句精准翻译
- **AI 智能助手**：回答备考问题、生成模拟题

## 技术栈

- **前端框架**：Flutter
- **本地数据库**：sqflite
- **状态管理**：Provider
- **音频播放**：just_audio
- **本地缓存：shared_preferences
- **HTTP 客户端**：dio
- **大模型 API**：Claude API

## 开发环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android SDK (Android 开发)
- Xcode (iOS 开发，仅 macOS)

## 安装步骤

### 1. 克隆项目
```bash
git clone <repository-url>
cd cet4_app
```

### 2. 安装依赖
```bash
flutter pub get
```

### 3. 运行项目
```bash
# Android
flutter run

# iOS (仅 macOS)
flutter run -d ios
```

### 4. 配置 API 密钥（可选）
1. 打开 APP，进入"我的"页面
2. 点击"API 设置"
3. 输入您的 Claude API 密钥
4. 选择模型（推荐 Claude 3 Haiku）

## 项目结构

```
lib/
├── main.dart                  // 项目入口
├── app.dart                   // 应用根组件
├── pages/                     // 所有页面
│   ├── home/                  // 首页
│   ├── vocabulary/            // 词汇模块
│   ├── question_bank/         // 题库模块
│   ├── listening/             // 听力模块
│   ├── ai_assistant/          // AI 助手模块
│   └── profile/               // 个人中心
├── components/                // 公共组件
│   ├── word_card.dart         // 单词卡片组件
│   ├── question_item.dart     // 题目组件
│   ├── audio_player.dart      // 音频播放器组件
│   └── ai_message_bubble.dart // AI 消息气泡组件
├── models/                    // 数据模型
│   ├── word.dart              // 单词模型
│   ├── question.dart          // 题目模型
│   ├── exam.dart              // 考试模型
│   └── ai_message.dart        // AI 消息模型
├── database/                  // 数据库操作
│   ├── db_helper.dart         // 数据库帮助类
│   └── tables/                // 数据表定义
├── provider/                  // 状态管理
│   ├── study_provider.dart    // 学习状态管理
│   ├── user_provider.dart     // 用户状态管理
│   └── ai_provider.dart       // AI 状态管理
├── utils/                     // 工具类
│   ├── ebbinghaus_algorithm.dart // 艾宾浩斯算法
│   ├── json_loader.dart       // JSON 数据加载器
│   └── claude_api.dart        // Claude API 工具类
└── assets/                    // 本地资源
    ├── data/                  // JSON 数据
    └── audio/                 // 听力音频
```

## 依赖包

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  shared_preferences: ^2.2.2
  dio: ^5.4.0
  path: ^1.8.3
  sqflite: ^2.3.0
  file_picker: ^8.0.0
  syncfusion_flutter_pdf: ^26.1.35
  fl_chart: ^0.69.0
  just_audio: ^0.9.36
  audio_session: ^0.1.18
  flutter_local_notifications: ^18.0.1
  timezone: ^0.10.0
  intl: ^0.19.0
```

## 安全与隐私

- API 密钥加密存储在本地
- AI 功能与基础功能完全解耦
- 所有 AI 请求显示加载动画
- 友好的错误提示和重试机制
- 离开页面自动取消请求
- 请求缓存减少 API 调用
- 对话内容仅本地存储
- 不收集用户个人信息

## 后续扩展

1. 支持更多大模型 API（OpenAI GPT、Google Gemini、DeepSeek 等）
2. 云端同步功能
3. 社区功能
4. 单词发音评分
5. 视频课程功能

## 许可证

本项目仅供学习使用。
