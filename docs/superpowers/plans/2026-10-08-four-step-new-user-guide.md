# Four-Step New User Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新用户完成资料设置后必须阅读四页产品指引，老用户不被打扰，并可从设置重新查看。

**Architecture:** 服务端用户记录保存强制指引的当前步骤，客户端新增独立 `tutorial` 路由并按顺序提交进度。设置中的重看模式只复用相同页面内容，不写服务端状态。等级徽章继续集中在现有成就弹窗中。

**Tech Stack:** SwiftUI、Swift Testing、FastAPI、SQLAlchemy async、Alembic、pytest。

**Spec:** `docs/superpowers/specs/2026-10-08-new-user-guide-design.md`

## Global Constraints

- 固定四页：关系图谱、情景模拟、沟通复盘、关系成长。
- 强制模式无跳过或关闭按钮；只需点击下一步，不执行真实业务操作。
- 老用户迁移为已完成；设置重看不重置或写入服务端进度。
- 第四页说明等级徽章位于“我的 → 成就徽章”；关系成长卡不展示徽章列表。
- 支持中英文、日夜主题、动态字体、VoiceOver、减少动态效果。
- 不修改经验数值、升级、衰减、奖励或新增徽章。
- 保留工作区原有未提交改动；只提交本功能文件和重叠文件中的本功能差异。

## Review Focus

1. 资料设置完成与教程状态同时变化时，必须先进入教程而非短暂进入主界面（Task 3）。
2. 重复点击、网络超时重试或旧响应晚到时，步骤不得跳过或倒退（Tasks 1、3）。
3. 老用户迁移、新账号创建和多个账号切换必须各自获得正确状态（Tasks 1、3）。
4. 重看流程关闭或完成不能修改服务端教程状态（Task 4）。
5. 大字体与英文较长文案不能遮挡主按钮；VoiceOver 顺序必须与页面阅读顺序一致（Task 2）。

---

### Task 1: 服务端教程状态与顺序推进

**Files:**
- Create: `SoulMark_backend/alembic/versions/20261008_0014_user_tutorial.py`
- Modify: `SoulMark_backend/app/models/user.py`
- Modify: `SoulMark_backend/app/schemas/user.py`
- Modify: `SoulMark_backend/app/api/v1/users.py`
- Modify: `SoulMark_backend/app/services/users.py`
- Modify: `SoulMark_backend/alembic/env.py`
- Test: `SoulMark_backend/tests/test_users.py`
- Test: `SoulMark_backend/tests/test_migrations.py`

**Interfaces:**
- Produces `UserResponse.tutorial_step: int`、`tutorial_completed_at: datetime | None`。
- Produces `TutorialProgress(step: int)` 与 `advance_tutorial(session, user, requested_step) -> User`。
- Produces authenticated `PATCH /api/v1/users/me/tutorial`。

- [ ] 写失败测试：新用户默认第 0 步；请求 1→2→3→4 顺序成功；重复当前步骤幂等；跳步、倒退、超出 0...4 返回 409/422；另一个账号状态不受影响。
- [ ] 运行 `.venv/bin/python -m pytest tests/test_users.py -q`，确认新字段和接口缺失导致失败。
- [ ] 实现模型、schema、服务和接口。服务器只接受 `requested_step == current + 1` 或 `requested_step == current`；到 4 时写入完成时间，重复 4 保留原时间。
- [ ] 写迁移测试：0013 已有账号升级后为 step 4 且有完成时间；升级后新账号由数据库默认 step 0；降级移除字段；Alembic 保持单一 head。
- [ ] 实现 0014：添加非空 `tutorial_step` 默认 0、可空完成时间，随后把当时已有用户更新为 4 和迁移时间。
- [ ] 运行用户、迁移和完整后端测试，执行 Ruff/Mypy；通过后仅提交本任务文件。

### Task 2: 四页指引模型和可复用界面

**Files:**
- Create: `SoulMark/SoulTutorialView.swift`
- Create: `SoulMarkTests/SoulTutorialTests.swift`

**Interfaces:**
- Produces `SoulTutorialPage` 固定四项，包含 `id/index/title/subtitle/icon` 与展示语义。
- Produces `SoulTutorialView(mode: .required(startStep:onAdvance:) | .replay(onClose:))`。

- [ ] 写失败测试：页面顺序和数量固定；第二页包含对象与情景／提示词说明；第四页包含经验衰减、称号与“成就徽章”；前三页按钮为“下一步”，第四页为“开始使用”。
- [ ] 运行指定 Swift 测试，确认类型缺失导致失败。
- [ ] 实现四页内容和 SoulMark 风格示意卡；强制模式从服务端步骤开始、无关闭按钮，点击回调成功才前进；重看模式从第一页开始并可关闭，不调用服务端。
- [ ] 为提交中、错误重试、VoiceOver、动态字体和减少动态效果实现明确状态；页面纵向可滚动，底部按钮保持可达。
- [ ] 运行 Swift 测试并用模拟器渲染中文/英文、日间/夜间、最大辅助字号四页；检查无截断后提交本任务文件。

### Task 3: 登录路由、进度 API 与账号隔离

**Files:**
- Modify: `SoulMark/AppSession.swift`
- Modify: `SoulMark/SoulMarkApp.swift`
- Modify: `SoulMark/AuthenticationViews.swift`
- Test: `SoulMarkTests/SoulTutorialTests.swift`

**Interfaces:**
- Extends `AppUser` with `tutorialStep` and `tutorialCompletedAt`。
- Adds `AppSession.Route.tutorial`、`advanceTutorial(to:) async`。
- Consumes Task 1 API and Task 2 required-mode view.

- [ ] 写网络桩失败测试：资料设置完成后 route 为 tutorial；step 4 才进入 main；提交失败停留；重复点击仅一个请求；账号 A 晚响应不能改变账号 B；老账号 step 4 直接进 main。
- [ ] 运行测试确认失败，再扩展 DTO/API 和 `applyUser` 路由优先级：未完成资料→onboarding，资料完成但 tutorialStep<4→tutorial，否则 main。
- [ ] `finishOnboarding` 应应用服务器返回的新用户并直接进入 tutorial；`advanceTutorial` 捕获账号/token/请求代次，成功应用服务器响应，失败保留当前页并显示重试错误。
- [ ] 在 App 根路由加载 Task 2 强制模式；退出登录清理教程请求状态，冷启动和换设备使用服务端步骤。
- [ ] 运行教程网络测试和全部 iOS 单元测试，通过后以差异块提交本功能改动。

### Task 4: 设置重看入口、徽章归位与交付

**Files:**
- Modify: `SoulMark/HomeProfileViews.swift`
- Modify: `SoulMark/GrowthViews.swift`（仅在需要移除关系成长卡中的徽章展示时）
- Modify: `SoulMark_backend/README.md`
- Test: `SoulMarkTests/SoulTutorialTests.swift`

**Interfaces:**
- Consumes `SoulTutorialView(mode: .replay)`。
- 保持 `AchievementsSheet` 内 `GrowthMilestoneSection` 为等级徽章唯一列表入口。

- [ ] 写失败测试或可检查视图状态：设置入口打开 replay；关闭/完成返回设置；重看不调用 `advanceTutorial`；成长卡无徽章列表，成就弹窗仍展示全部等级徽章。
- [ ] 在设置页新增“新手指引”行并以全屏方式打开重看；重看页面显示关闭按钮，第四页完成后关闭。
- [ ] 检查并保持等级徽章只在 `AchievementsSheet` 渲染；不改经验规则或添加教程奖励。
- [ ] README 补充 0014 部署顺序及旧用户/新用户迁移语义。
- [ ] 运行后端完整测试、Ruff、Mypy、iOS 全部单元测试和 Debug 模拟器构建；逐项核对四页内容、强制/重看差异和账号隔离。
- [ ] 独立审查本功能差异，修复重要问题后再次验证；确认未混入工作区原有改动，提交并按既有授权推送 `origin main`，提供 GitHub 提交链接并说明后端尚需部署迁移。
