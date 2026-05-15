# Tasks

- [x] Task 1: 统一卡片内边距规范
  - [x] SubTask 1.1: 修改 `_buildMotivation` 内边距为 `EdgeInsets.symmetric(horizontal: 16, vertical: 14)`
  - [x] SubTask 1.2: 修改 `_buildReviewForecast` 列表项内边距，确保与辅助卡片规范一致
  - [x] SubTask 1.3: 验证所有卡片内边距符合规范

- [x] Task 2: 底部导航栏添加点击缩放动画
  - [x] SubTask 2.1: 将 `_NavItem` 从 `StatelessWidget` 改为 `StatefulWidget`
  - [x] SubTask 2.2: 添加 `AnimationController` 和缩放动画（0.95）
  - [x] SubTask 2.3: 在 `onTapDown`/`onTapUp`/`onTapCancel` 中触发动画
  - [x] SubTask 2.4: 验证点击反馈在所有导航项上正常工作

- [x] Task 3: 颜色主题化替换
  - [x] SubTask 3.1: 在 `home_page.dart` 中识别所有硬编码颜色
  - [x] SubTask 3.2: 将 `Color(0xFF165DFF)` 替换为 `Theme.of(context).colorScheme.primary`
  - [x] SubTask 3.3: 将 `Color(0xFF1E293B)` 等表面/文字颜色替换为对应的 `colorScheme` 属性
  - [x] SubTask 3.4: 验证暗色模式下颜色自动适配

- [x] Task 4: Base64解码异常保护
  - [x] SubTask 4.1: 在 `home_page.dart` 中添加 `_decodeBase64` 辅助函数
  - [x] SubTask 4.2: 替换所有 `base64.decode()` 调用为安全版本
  - [x] SubTask 4.3: 添加空值判断，避免传入损坏数据给 `Image.memory`

- [x] Task 5: 复习预测卡片视觉优化
  - [x] SubTask 5.1: 增强"今天"卡片的阴影深度和视觉权重
  - [x] SubTask 5.2: 调整非今天卡片的边框或背景色，形成层级对比

- [x] Task 6: 响应式网格断点扩展
  - [x] SubTask 6.1: 修改 `_buildQuickActions` 中的 `crossAxisCount` 逻辑
  - [x] SubTask 6.2: 添加 >900px 的4列断点
  - [x] SubTask 6.3: 验证不同宽度下的布局效果

- [x] Task 7: 激励语暗色模式对比度优化
  - [x] SubTask 7.1: 调整 `_buildMotivation` 暗色模式背景不透明度从 0.15 到 0.25
  - [x] SubTask 7.2: 验证暗色模式下文字可读性

# Task Dependencies
- Task 3 可与 Task 1、2、4、5、6、7 并行执行
- Task 4 依赖于 Task 3 完成（避免冲突）
- Task 7 可与 Task 1 并行执行
