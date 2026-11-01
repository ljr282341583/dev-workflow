# 换机器一键安装（技能 + 全局红线）

本目录是「UI 优先开发流程」的**跨机安装包**：在任意一台新机器上，一条命令就能把流程装好。

## 装什么

| 安装项 | 目标位置 | 作用 |
| --- | --- | --- |
| 技能 `ui-first-dev` | `%USERPROFILE%\.agents\skills\ui-first-dev\` | DSH 从用户级目录加载技能；任务命中"开发带界面的东西"时自动可用 |
| 全局红线 | `%USERPROFILE%\.dsh\AGENTS.md` | 每次会话自动加载，强制"先加载技能、先过 UI 审、每门必停" |

## 一条命令

```powershell
# 先 clone 规范仓库（私有，需已登录 GitHub）
git clone https://github.com/ljr282341583/dev-workflow.git "$env:USERPROFILE\dev-workflow"

# 安装技能 + 全局红线（默认装到本机用户级目录）
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dev-workflow\install\install-machine.ps1"

# 可选：顺手把「工作区级 §2.6」也插进工作区的 AGENTS.md（workspace 不在 git 里，只能本机插）
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dev-workflow\install\install-machine.ps1" `
  -WorkspaceAgents "G:\ai\deepseek harness output\workspace\AGENTS.md"

# 只看会做什么、不落盘
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dev-workflow\install\install-machine.ps1" -DryRun
```

> 装了 PowerShell 7 的机器也可以把 `powershell -NoProfile -ExecutionPolicy Bypass` 换成 `pwsh`（Windows 自带的 5.1 没有 `pwsh` 命令，用上面这行最稳）。

脚本是**幂等**的：技能每次覆盖为仓库里的最新版；红线检测到「## 开发流程红线」标记就跳过，不会写两遍；改红线前先自动备份 `AGENTS.md.bak-<时间>`。

## 可选参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-SkillTarget` | `%USERPROFILE%\.agents\skills` | 技能安装目录（DSH 用户级技能目录） |
| `-AgentsFile` | `%USERPROFILE%\.dsh\AGENTS.md` | 要插入红线的全局指令文件 |
| `-WorkspaceAgents` | 空（不处理） | 指定 `workspace/AGENTS.md` 路径时，顺手把 §2.6 插进去（已存在则跳过） |
| `-SpecRoot` | 本仓库根目录 | 红线里"正文与模板"指向的路径（仓库不一定克隆在同一路径） |
| `-DryRun` | 关 | 只打印计划，不写文件 |

## 装完怎么验

1. **技能在不在**：新开一个 DSH 会话，问一句"你有 ui-first-dev 技能吗？"→ 答"有"即成功（DSH 会监视技能目录，通常不用重启）。
2. **红线在不在**：打开 `%USERPROFILE%\.dsh\AGENTS.md`，应能看到 `## 开发流程红线(有界面的项目一律执行)`。
3. **工作区级在不在**（若加了 `-WorkspaceAgents`）：`workspace/AGENTS.md` 里应能看到 `### 2.6 带界面项目的开发流程`。
4. **实战验收**：说"帮我做个 XXX 的 APK"，第一条回复应该是**问题**（P0），不是代码。

## 工作区级红线（为什么它特殊）

`workspace/AGENTS.md` **不属于本仓库**（workspace 根不是 git 仓库），`git clone` 带不过去，所以它是唯一需要"在本机落地"的一处：

- **自动**（推荐）：加 `-WorkspaceAgents "<workspace>\AGENTS.md"`，脚本会检测、备份、插到 `## 3.` 之前（找不到就退到 `## 7.` 之前，再找不到追加文末）。
- **手动**：把 [`workspace-agents-2.6.md`](workspace-agents-2.6.md) 里 `BEGIN/END` 之间那段贴到 `### 2.5 汇报` 之后，并按该文件末尾提示补 §7 勾选项与变更记录。

两种方式都只插一次（靠 `### 2.6 带界面项目的开发流程` 标题判重）。

## 卸载

```powershell
Remove-Item "$env:USERPROFILE\.agents\skills\ui-first-dev" -Recurse -Force
# 红线：手动删掉 AGENTS.md 里「## 开发流程红线」那一节（备份文件在 AGENTS.md.bak-*）
```
