# 首页UI优化 Spec

## Why
当前首页UI在视觉一致性、交互反馈和代码质量方面存在改进空间。具体包括：颜色硬编码导致暗色模式维护困难、卡片内边距不统一、底部导航缺少点击反馈、base64解码缺少异常保护等。本次优化在保持功能逻辑完全不变的前提下，提升视觉精致度和代码可维护性。

## What Changes
- 统一卡片内边距规范，消除区块间视觉差异
- 底部导航栏添加点击缩放反馈动画
- 将高频硬编码颜色替换为 Theme colorScheme 变量
- 为 base64 图片解码添加 try-catch 保护
- 优化复习预测卡片的视觉层级
- 调整激励语横幅暗色模式对比度
- 扩展 GridView 响应式断点支持更多屏幕尺寸

## Impact
- Affected specs: 首页视觉呈现、暗色/亮色主题一致性、交互反馈体验
- Affected code: `lib/pages/home/home_page.dart`, `lib/app.dart`

## ADDED Requirements
### Requirement: 底部导航点击反馈
The system SHALL 在底部导航栏项被点击时提供视觉反馈。

#### Scenario: 用户点击导航项
- **WHEN** 用户点击任意底部导航项
- **THEN** 图标和文字产生短暂的缩放动画（0.95），然后恢复原状

### Requirement: Base64解码安全
The system SHALL 安全地解码内嵌的base64图片，避免解码失败导致UI崩溃。

#### Scenario: 图片数据损坏
- **WHEN** base64字符串格式异常或损坏
- **THEN** 返回空值，Image组件展示errorBuilder的fallback，不抛出未捕获异常

## MODIFIED Requirements
### Requirement: 卡片内边距统一
所有卡片容器 SHALL 使用统一内边距规范：
- 主内容卡片（今日学习、学习概览）：`EdgeInsets.all(20)`
- 辅助卡片（激励语、复习预测）：`EdgeInsets.symmetric(horizontal: 16, vertical: 14)`

### Requirement: 颜色主题化
所有Widget中的硬编码颜色 SHALL 尽可能替换为 `Theme.of(context).colorScheme` 对应属性，确保暗色/亮色切换时自动适配。

### Requirement: 复习预测卡片视觉优化
复习预测中的"今天"卡片 SHALL 使用更高的阴影和对比度，与非今天卡片形成明确的视觉层级差异。

### Requirement: 响应式网格断点
快速入口GridView SHALL 支持更多屏幕尺寸的响应式布局：
- 宽度 > 900px：4列
- 宽度 > 600px：3列
- 默认：2列

## REMOVED Requirements
无移除需求。
