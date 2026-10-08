# Growth Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在“我的”显示真实经验进度，支持复盘/聊天奖励、递增升级、闲置衰减和永久里程碑徽章。

**Architecture:** 服务端经验账本与成长状态在同一用户级事务中更新。活动保存、闲置补算和前台活跃通知均通过成长服务结算；SwiftUI 从服务端获取成长快照，不在手机端自行发奖或扣分。

**Tech Stack:** SwiftUI、Swift Testing、FastAPI、SQLAlchemy async、Alembic、PostgreSQL；现有 pytest SQLite 测试环境。

**Spec:** `docs/superpowers/specs/2026-10-08-growth-experience-design.md`

## Global Constraints

- 成功复盘 30 EXP；有效聊天每轮 5 EXP、每天上限 50 EXP；Asia/Singapore 自然日、服务端时间。
- L 级升至 L+1 需要 `100 + 50 × (L-1)` EXP；等级从 1 开始，无最高等级限制。
- 宽限 7 天，第 8 天起每天扣 10 EXP，余额不低于 0；回归先结算衰减再记活跃、再发奖。
- 当前称号随等级，等级成就按历史最高等级永久保留；称号等级为 1/3/5/10/20。
- 活跃指 App 前台或有效行为保存；后台查询不续期；上线前闲置不补扣。
- 删除活动不删除账本；稳定事件 UUID 保证新客户端重试幂等；失败不发奖。
- 中英文、现有主题、无障碍、账号隔离；不引入第三方 UI 依赖。
- 保留本地其他未提交改动。测试通过后按已有授权推送 GitHub main；生产迁移和后端部署须单独明确状态。

## Review Focus

1. 网络超时后重试，甚至原活动已删除：不能重复保存、发奖或重复改变关系数据（Task 3）。
2. 继续历史聊天或 AI 只有开场白：不能把旧消息/开场白重新算作有效轮次（Task 4）。
3. 离线恢复、前后台快速切换或切换账户：不能丢失活跃上报，也不能把旧账户响应显示给新账户（Task 4）。
4. 多设备同时领奖或读取衰减：每日上限和扣减必须在数据库中串行结算（Task 2）。
5. 长期离开导致一次降多级，或后端还未升级：保留已获徽章，展示真实状态/重试入口，不伪造零经验（Tasks 2、5）。

---

### Task 1: 纯规则、数据库结构与历史补计

**Files:** Create `SoulMark_backend/app/services/growth_rules.py`, `app/models/growth.py`, `alembic/versions/20261008_0013_growth_experience.py`, `tests/test_growth_rules.py`; modify `app/models/__init__.py`, `tests/test_migrations.py`（路径均相对 SoulMark_backend）。

**Interfaces:** `level_progress(balance: int) -> tuple[int, int, int]` 返回等级/本级经验/需求；`decay_due(last_active: date, settled_through: date, today: date, balance: int) -> int` 返回未结算扣减；`count_completed_turns(messages: list[tuple[str, str]]) -> int` 只计用户非空发言后完成的非空助手回答。

- [ ] 写规则测试：`level_progress(0)==(1,0,100)`、`(100)==(2,0,150)`、`(250)==(3,0,200)`、`(249)==(2,149,150)`；10/1 活跃在 10/8 扣 0、10/9 扣 10、10/11 扣 30，余额 7 时只扣 7；开场白/空文本不计轮次。
- [ ] 运行 `.venv/bin/python -m pytest tests/test_growth_rules.py -q`，确认因规则函数缺失失败，再实现以上签名并重跑通过。
- [ ] 新增 `UserGrowth`（owner_id 主键外键、balance、peak_level、last_active_date、decay_settled_through）和 `ExperienceEvent`（id、owner_id、event_key、kind、delta、created_at、source_id、request_hash）；`(owner_id,event_key)` 唯一，账户删除级联、活动删除不级联。source_id 保存幂等结果定位，不使用活动外键。余额非负约束。
- [ ] 写迁移测试：从 0012 种入 2 份复盘、同日 12 份双方转录非空的旧练习及空练习，升级后余额为 110、等级 2；只有一个 Alembic head；再次升级无增量；初始活跃为迁移当天；降级可移除新增表。
- [ ] 实现 0013 迁移与模型注册。历史事件使用 `legacy:review:<id>` / `legacy:practice:<id>`，按记录原日期和稳定排序补计；不调用会随版本变化的业务服务完成迁移。新账户状态由首次成长访问懒创建，初始日期使用用户创建日期。
- [ ] 运行规则/迁移测试，确认通过；独立提交本任务文件。

### Task 2: 成长事务与读取/活跃接口

**Files:** Create `SoulMark_backend/app/services/growth.py`, `app/schemas/growth.py`, `app/api/v1/growth.py`, `tests/test_growth.py`; modify `app/main.py`。

**Interfaces:** `GrowthSnapshot` 字段：`balance, level, level_experience, next_level_experience, peak_level, chat_experience_today, title_key, next_title_level, decayed_experience, next_decay_date`；`lock_growth(session, owner_id, now) -> UserGrowth`；`settle_decay(session, state, now) -> int`；`mark_active(state, now) -> None`；`award_experience(session, state, event_key, kind, requested, now, source_id, request_hash) -> int`；`growth_snapshot(session, state, now, decayed_experience=0) -> GrowthSnapshot`。服务函数不自行提交事务。

- [ ] 写接口/事务测试：GET `/api/v1/growth` 不更新 last_active_date；POST `/api/v1/growth/active` 先扣后续期；同日重复读取不重复扣；归零无负债；跨月、日期边界、历史最高等级不回退；不同用户无法读写彼此成长。
- [ ] 运行 `.venv/bin/python -m pytest tests/test_growth.py -q` 确认失败。
- [ ] 实现用户锁：在创建成长状态前锁定既有 User 行，生产 PostgreSQL 使用数据库行锁；所有成长写操作使用同一锁顺序。SQLite 测试需要独立文件连接验证事务，不用进程内锁替代生产数据库锁；发生数据库锁冲突时回滚并有界重试整个事务。
- [ ] 实现衰减账本、今日聊天正向奖励汇总和历史 peak_level。余额为 0 也更新结算日期，防止回归得奖后补扣过去的天数。响应返回实际扣减数，下一扣减日期不得早于已结算日期的次日。
- [ ] 注册 GET/POST 接口，认证复用 CurrentUser；提交成功后返回快照。接口响应不返回其他用户或身份数据。
- [ ] 加并发测试：同账户 49 点聊天经验时两个 5 点请求总发放 1 点；两个请求同时结算 20 点衰减只扣 20。用独立连接运行，生产 PostgreSQL 测试通过测试数据库 URL 执行；如环境缺失必须记录未验证项。
- [ ] 运行成长测试与规则测试通过后提交。

### Task 3: 接入复盘与练习保存，保障幂等

**Files:** Modify `SoulMark_backend/app/schemas/activity.py`, `app/services/activity.py`, `app/api/v1/activity.py`, `tests/test_activity.py`; create `tests/test_growth_activity.py`。

**Interfaces:** 保存请求新增可选 `event_id: UUID`；练习新增可选 `messages: list[PracticeMessage]`，消息字段 `role: Literal['user','assistant']`、`text: str`，仅接受最终完整消息。响应新增可选 `growth: GrowthSnapshot`、`awarded_experience: int`。服务层 `ActivitySaveResult` 包含 `record, created, growth, awarded_experience`；路由仅在 `created` 时执行关系更新。

- [ ] 写失败测试：复盘 +30、完整聊天两轮 +10、空聊天 +0、每天最多 +50、跨日恢复额度；保存异常使活动和账本一起回滚。
- [ ] 写重复测试：同一 event_id 同一内容返回原记录且新奖励 0；同 event_id 不同内容返回 409；删除原活动后重放返回 409 且不重建；复盘重试不再次执行关系重算。旧客户端无 event_id 仍能保存，双方非空合并文本仅按一轮计。
- [ ] 运行 `.venv/bin/python -m pytest tests/test_growth_activity.py -q` 确认失败。
- [ ] 在现有保存事务前取得 Task 2 用户锁，先查幂等事件，再结算衰减、插入活动并发奖。零奖励也存事件用于去重；请求摘要含业务字段，不含服务端时间。有效活动标记活跃；空练习不标记活跃。
- [ ] 新消息列表设置总文本长度与条数上限，空白文本不计轮次，用户连续多条到下一条助手回答只计一个轮次；结构化文本与合并转录不符返回 422。奖励金额只由服务端计算。
- [ ] 保留原有记录列表、删除和关系接口行为；修改调用方接收 ActivitySaveResult。复盘记录提交后关系更新失败沿用现有错误语义，不回滚已成功的成长事务。
- [ ] 运行成长活动和既有活动测试通过后提交。

### Task 4: iOS 成长数据、稳定保存标识与活跃通知

**Files:** Create `SoulMark/GrowthModels.swift`, `SoulMarkTests/GrowthTests.swift`; modify `SoulMark/AppSession.swift`, `SoulMark/ContentView.swift`, `SoulMark/ScenarioSimulationView.swift`, `SoulMark/ConversationReviewPage.swift`, `SoulMark/RealtimeVoiceCall.swift`（仅当完整消息状态需要显式区分）。

**Interfaces:** `GrowthSnapshot: Decodable, Equatable` 对应 Task 2 snake_case；`GrowthLoadState` 表示 loading/loaded/failed；API `growth(token:)`、`markGrowthActive(token:)`。AppSession 公开成长状态、`refreshGrowth() async`、`recordForegroundActivity() async` 和一次性 `GrowthFeedback`；保存响应直接应用快照并展示实际奖励，不用余额差猜测奖励。

- [ ] 写 Swift 测试：解码完整快照/可选旧响应；有效消息提取不含开场白、未完成回答或历史消息；结构化与合并转录一致；保存重试复用 event UUID；编辑为新内容才生成新 UUID。
- [ ] 使用模拟器实际名称运行 `xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=<available iPhone>' -only-testing:SoulMarkTests/GrowthTests CODE_SIGNING_ALLOWED=NO`，确认新增接口缺失导致失败。
- [ ] 保存事件标识在一次用户操作开始时生成，保存在视图待提交状态；复盘分析成功后重试保存复用分析结果及标识。练习结束产生不可变待保存快照，仅包含本次新增完整轮次；失败保留快照和重试入口。继续历史会话不得重计旧消息。
- [ ] 将练习保存的吞错 `try?` 改为抛错并显示重试；成功后才更新练习统计。复盘/练习响应缺失 growth 时主动刷新；旧后端 404 显示暂不可用，不假发奖。
- [ ] 前台激活调用 active 接口，首次进入主界面也调用；失败不标记已成功，下一次前台/手动重试允许重报。后台查询只 GET。异步任务捕获账户 ID、token 及请求代次，应用结果前核对仍属于同一会话且未过期；退出清空状态和反馈。
- [ ] 加网络桩测试：账户 A 慢响应在切换 B 后到达不能覆盖；前台上报失败后可以重试；保存成功但刷新失败不重复保存。为 SoulAPIClient 添加最小 URLSession 注入入口支持 URLProtocol 桩，避免改动无关网络逻辑。
- [ ] 运行 GrowthTests 通过后提交；以差异块选择本功能，保留这些文件里已存在的其他改动。

### Task 5: “我的”成长卡、称号、成就与反馈

**Files:** Create `SoulMark/GrowthViews.swift`; modify `SoulMark/HomeProfileViews.swift`, `SoulMark/ContentView.swift`; extend `SoulMarkTests/GrowthTests.swift`。

**Interfaces:** `GrowthProgressCard(state:onRetry:)`；`GrowthMilestone` 根据快照 level 与 peak_level 分别提供当前称号和已解锁徽章；`GrowthFeedback` 展示在已登录根视图覆盖层。

- [ ] 写称号测试：等级 1/3/5/10/20 对应关系探索者/倾听学徒/沟通达人/共情专家/关系大师；当前等级 2、peak 10 时当前称号为探索者，Lv.10 徽章仍已解锁。
- [ ] 运行 Swift GrowthTests 确认失败，再实现双语映射。
- [ ] 在身份卡下方插入经验卡，移除固定 01；显示本级进度、距升级经验、下个称号、奖励和衰减规则。加载态用占位，失败态提供重试，不显示伪造数值；未有快照时身份卡不硬编码等级。
- [ ] 在现有成就弹窗加入等级里程碑与锁定进度。展示获得经验/升级/回归扣减反馈；历史补计、首次加载不显示升级动画，遵循减少动态效果设置；屏幕阅读器读出进度。
- [ ] 运行 Swift 测试、构建；模拟器检查中英文、日夜主题、大字号、加载/失败、Lv.1/Lv.20/一次衰减降多级；保存可查看截图作为验证证据。
- [ ] 提交本功能 UI 差异块。

### Task 6: 完整验证、交付说明与推送

**Files:** Modify `SoulMark_backend/README.md`；必要时新增本功能发布说明，不改动部署凭据。

- [ ] 执行后端 `.venv/bin/python -m pytest -q` 和 `.venv/bin/ruff check` 对本功能变更文件检查；执行 iOS 单元测试与 Debug 模拟器构建。现有失败需辨明是否本功能引入，不能以跳过冒充通过。
- [ ] 审查经验重复发放、衰减并发、账户切换、迁移历史额度与成就永久保留；逐项对照 spec，无遗漏再交付。
- [ ] README 写明部署顺序：数据库备份→`alembic upgrade head`→匹配后端上线→App 更新；说明历史补计、Asia/Singapore 日界及上线后宽限期。代码推送不等于后端已部署。
- [ ] `git diff --check`、查看 staged diff，确认没有混入本地既有修改或凭据；提交验证过的变更，按用户已有授权推送 `origin main`，不强推。
- [ ] 验证远端提交成功后提供 GitHub 提交链接、测试结果、生产部署状态和任何真实验证限制。
