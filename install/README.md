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

# 装：技能 + 全局红线 + 工作区级 §2.6（工作区根自动探测，不需要填路径）
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dev-workflow\install\install-machine.ps1"

# 只看会做什么、不落盘
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\dev-workflow\install\install-machine.ps1" -DryRun
```

> 装了 PowerShell 7 的机器也可以把 `powershell -NoProfile -ExecutionPolicy Bypass` 换成 `pwsh`（Windows 自带的 5.1 没有 `pwsh` 命令，用上面这行最稳）。

脚本是**幂等**的：技能每次覆盖为仓库里的最新版；红线检测到「## 开发流程红线」标记就跳过；§2.6 检测到标题就跳过；改文件前先自动备份 `*.bak-<时间>`。

## 工作区根怎么找（不用你填路径）

脚本**不写死任何盘符**，按顺序猜：

1. 当前目录向上逐级找，直到某个目录同时有 `AGENTS.md` + `skills\registry.md`（或 `AGENTS.md` 里写着"工作区通用协作规范"）；
2. 没找到就再查 DSH 自己的登记表 `%DSH_HOME%\storages\workspace.json`（默认 `%USERPROFILE%\.dsh\storages\workspace.json`）里登记过的路径；
3. 还找不到就**打印提示并跳过**，不会瞎改文件。

所以每台机器路径不同也没关系。想确认它找到了哪：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install\install-machine.ps1 -DryRun
# 输出里会有一行「工作区根：D:\...」
```

## 可选参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-SkillTarget` | `%USERPROFILE%\.agents\skills` | 技能安装目录（DSH 用户级技能目录） |
| `-AgentsFile` | `%USERPROFILE%\.dsh\AGENTS.md` | 要插入红线的全局指令文件 |
| `-WorkspaceAgents` | `auto` | 工作区根目录 / `AGENTS.md` 路径 / `auto` 自动探测 / `none` 跳过 |
| `-SpecRoot` | 本仓库根目录 | 红线里"正文与模板"指向的路径（仓库不一定克隆在同一路径） |
| `-DryRun` | 关 | 只打印计划，不写文件 |

**探测不准时**（例如工作区不叫 `workspace`、或没有 `skills/registry.md`）：

```powershell
# 显式指定目录（脚本自动补 AGENTS.md）
... -WorkspaceAgents "D:\某台机器的工作区根"
# 或直接给文件
... -WorkspaceAgents "D:\某台机器的工作区根\AGENTS.md"
# 这台机器确实没有工作区
... -WorkspaceAgents none
```

## 装完怎么验

1. **技能在不在**：新开一个 DSH 会话，问一句"你有 ui-first-dev 技能吗？"→ 答"有"即成功（DSH 会监视技能目录，通常不用重启）。
2. **红线在不在**：打开 `%USERPROFILE%\.dsh\AGENTS.md`，应能看到 `## 开发流程红线(有界面的项目一律执行)`。
3. **工作区级在不在**：工作区根目录的 `AGENTS.md` 里应能看到 `### 2.6 带界面项目的开发流程`。
4. **实战验收**：说"帮我做个 XXX 的 APK"，第一条回复应该是**问题**（P0），不是代码。

## 工作区级红线（为什么它特殊）

`workspace/AGENTS.md` **不属于本仓库**（workspace 根不是 git 仓库），`git clone` 带不过去，所以它是唯一需要"在本机落地"的一处：

- **自动**（默认）：脚本探到工作区根后，检测、备份、把 §2.6 插到 `## 3.` 之前（找不到就退到 `## 7.` 之前，再找不到追加文末）。
- **手动**：把 [`workspace-agents-2.6.md`](workspace-agents-2.6.md) 里 `BEGIN/END` 之间那段贴到 `### 2.5 汇报` 之后，并按该文件末尾提示补 §7 勾选项与变更记录。

两种方式都只插一次（靠 `### 2.6 带界面项目的开发流程` 标题判重）。

## 卸载

```powershell
Remove-Item "$env:USERPROFILE\.agents\skills\ui-first-dev" -Recurse -Force
# 红线：手动删掉 AGENTS.md 里「## 开发流程红线」那一节（备份文件在 AGENTS.md.bak-*）
```
