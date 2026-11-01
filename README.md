# 开发规范（UI 优先 · 全阶段门禁）

> 解决一个具体问题：**"叫你开发个 APK，你没做 UI 设计就直接写代码，结果界面很丑。"**
> 从今往后，所有带界面的项目都按这里的流程走，**每一关我停下来等你点头**。

---

## 一页看完流程

| 阶段 | 我做什么 | 你看到什么 | 你要做什么 |
| --- | --- | --- | --- |
| **P0 需求** | 问你 5 个问题，写成一页需求卡 | `docs/PRD.md` | 确认需求对不对 |
| **P1 UI 设计** ← 最关键 | 给 2～3 套风格方向 → 你选一套 → 铺全屏可点击原型 + 设计 token + 截图 | 浏览器/手机能点的原型 + 每屏截图 | **选方向、过审稿** |
| **P2 前端** | 按原型 1:1 实现，先用假数据，每屏截图对照 | 能跑的前端 + 走查截图 | 看一下像不像、点得通不通 |
| **P3 后端** | 先写接口契约，再接 mock，再换真接口 | `docs/API-CONTRACT.md` | 确认业务逻辑 |
| **P4 联调验收** | 真实数据跑主流程、测异常、真机截图 | 验收表（逐条打勾） | 验收 |
| **P5 交付** | 出安装包/网址 + README + 收尾写大脑仓库 | 能装能用的成品 | 用起来 |

```
P0需求 ──①── P1 UI设计 ──②── P2 前端(mock) ──③── P3 契约+后端 ──④── P4 验收 ──⑤── P5 交付
```

**门禁②是硬的**：UI 没过审，一行界面代码都不写。

---

## 怎么用

### 你只需要这样说

- 新项目：「帮我做个 XXX 的 APK」→ 我会按 P0 先问 5 个问题，不会直接开写。
- 想改设计：「P1-首页 卡片太挤，改成两列」→ 我改原型给你看，你点头我再动代码。
- 赶时间：「这次跳过设计，先跑起来」→ 我照做，但会把后果说清并记进 `docs/DECISIONS.md`。
- 修 bug / 改文案：直接说，不用走全流程。

### 我这边怎么保证执行

- 全局 `~/.dsh/AGENTS.md` 里加了红线：有界面的项目必须加载 `ui-first-dev` 技能、必须走门禁。
- 技能 `~/.agents/skills/ui-first-dev/SKILL.md` 里有每阶段的动作清单和门禁话术。
- 本目录是规范正文与模板的唯一权威来源。

---

## 文件导航

| 文件 | 内容 | 谁看 |
| --- | --- | --- |
| [WORKFLOW.md](WORKFLOW.md) | **主规范**：六阶段、五门禁、反丑 10 条、例外通道、目录标准、复盘 | 必读 |
| [CHECKLIST-UI.md](CHECKLIST-UI.md) | UI 交付前自检清单（A–G 七组 + 30 秒判丑） | 每屏做完跑一遍 |
| [templates/PRD.md](templates/PRD.md) | 需求卡模板（一页） | P0 |
| [templates/UI-DESIGN.md](templates/UI-DESIGN.md) | 设计说明模板（为什么长这样） | P1 |
| [templates/design-tokens.json](templates/design-tokens.json) | 设计 token 起点（颜色/字号/间距/圆角/阴影） | P1–P2 |
| [templates/prototype/index.html](templates/prototype/index.html) | **可点击高保真原型脚手架**（首页/列表/详情/我的/设计规范 5 屏 + 危险操作确认弹层 + 输入框四态，离线可开；示例产品"轻账"记账 App） | P1 |
| [templates/prototype/shots/](templates/prototype/shots/) | 9 张截图：5 屏默认态 + 列表四态（空/加载/错误）+ 删除确认弹层 | P1 |
| [templates/API-CONTRACT.md](templates/API-CONTRACT.md) | 接口契约模板 | P3 |
| [templates/ACCEPTANCE.md](templates/ACCEPTANCE.md) | 验收清单模板 | P4–P5 |

> **原型脚手架怎么用**：它是"模板 + 标准样例"两用。换项目时先改 `design-tokens.json` 再同步页面 `:root`，然后改文案/数据/屏数即可。
> 注意：脚手架把**四态演示集中在列表屏**（`#list?state=empty|loading|error`），这是为了控制模板体积；**真实项目要求每一屏都做四态**，照着这个模式复制。

---

## 为什么"上次会丑"

1. 没有设计阶段，需求直接进代码 → 界面就是默认控件堆起来的样子。
2. 没有设计 token → 每页自己配色配字号，越加越乱。
3. 没有状态设计 → 空数据/加载/报错是白屏和原生样式。
4. 没有截图走查 → 丑到装到手机上那天才被发现。

规范里对应的四道保险：**P1 设计先行、token 统一、四态齐全、截图走查**。详见 [WORKFLOW.md](WORKFLOW.md) 第 8 节。

---

## 换机器 / 新电脑怎么装（一条命令）

本规范在本机是"全局生效"的（技能 + `~/.dsh/AGENTS.md` 红线）。换机器时：

```powershell
git clone https://github.com/ljr282341583/dev-workflow.git "$env:USERPROFILE\dev-workflow"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dev-workflow\install\install-machine.ps1"
```

脚本会：① 把 `skill/ui-first-dev` 装进 `%USERPROFILE%\.agents\skills\`（DSH 的用户级技能目录）；
② 把「开发流程红线」插进 `%USERPROFILE%\.dsh\AGENTS.md`（已有则跳过，改前自动备份）。
幂等、可 `-DryRun` 先看计划，细节见 [install/README.md](install/README.md)。

> 工作区级还有一处：`workspace/AGENTS.md` 的 §2.6「带界面项目的开发流程」；若新机器的 workspace 是另一份，需同步过去。

## 常见问题

**Q：每次都走全流程会不会太慢？**
A：小改动有快捷通道（[WORKFLOW.md](WORKFLOW.md) 第 5 节）。只有"新项目/新页面/换风格"才走全流程——恰恰是这三类最容易返工。

**Q：我怎么判断设计好不好？我不懂设计。**
A：所以 P1 不是拿一套稿子让你评价，而是给 2～3 套方向让你**选**。选完还有 [CHECKLIST-UI.md](CHECKLIST-UI.md) 兜底。

**Q：我能不能直接说"别啰嗦，直接写"？**
A：可以，这是你的项目。我会先说一句预期后果，然后照做，并把这次跳过记进项目的 `docs/DECISIONS.md`。

**Q：老项目怎么办？**
A：不强制补历史文档。但新增页面/改视觉按此流程走，新产物放到 `docs/` 下。

---

维护：[WORKFLOW.md](WORKFLOW.md) 是唯一权威版本，本文件只做索引。规则变更记在 WORKFLOW.md 末尾的变更记录里。
