# 复盘情景模拟图标统一设计

## 目标

将复盘页面中所有由 `ReviewSource.scenario` 提供的情景模拟图标，从 `figure.wave` 统一为底部导航栏“模拟”所使用的 `waveform.and.mic`。

## 范围

- 修改 `SoulMark/SoulModels.swift` 中 `ReviewSource.systemImage` 的 `.scenario` 分支。
- 复盘筛选按钮、复盘记录卡片及详情入口继续复用该统一属性，因此会同步更新。
- 不修改微信聊天、手动记录图标，不修改尺寸、颜色、间距或交互。

## 验证

- 检查 `.scenario` 返回 `waveform.and.mic`。
- 执行 Swift 语法解析与 `git diff --check`。
