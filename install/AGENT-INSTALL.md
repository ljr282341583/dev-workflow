# 给 AI 看：一句话安装说明（自包含）

> 用途：用户对你说「把这套 UI 优先开发流程装到这台电脑」时，你照这个做，**不要让用户敲命令**。
> 仓库（公开）：https://github.com/ljr282341583/dev-workflow

## 你要做的步骤

1. **确认环境**：Windows + PowerShell（`$PSVersionTable` 能跑即可，5.1 也行）。
2. **检查 git**：`git --version`。
   - 有 → 走第 3 步。
   - 没有 → 改走「ZIP 方案」（见文末），不要停在这里让用户自己装 git。
3. **克隆/更新仓库**（选一个已存在的位置，别新建重复副本）：
   ```powershell
   $dst = Join-Path $env:USERPROFILE "dev-workflow"
   if (Test-Path $dst) { git -C $dst pull --ff-only } else { git clone https://github.com/ljr282341583/dev-workflow.git $dst }
   ```
4. **跑安装脚本**（不要再手工改任何配置文件）：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$dst\install\install-machine.ps1"
   ```
   - 它会：装技能到 DSH/Codex/Claude 的技能目录 → 往各工具的 AGENTS.md/CLAUDE.md 插一段红线（改前自动备份）→ 自动探测工作区根并插 §2.6。
   - **幂等**：重复跑不会重复插入。想先看计划加 `-DryRun`；只装某一个加 `-Target dsh|codex|claude`。
5. **把脚本输出的「安装结果」原样转述给用户**（那一段就是给小白看的 ✅/❌ 清单）。有 ❌ 就按下面排错。
6. **汇报格式**（照抄结构，别丢项）：
   ```
   ✅ 已装好：<列出的 ✅ 项>
   ❌ 没装上：<列出的 ❌ 项 + 你判断的原因>
   👉 现在可以对我说："帮我做个 XXX 的 App"，我会先问你需求、再出 UI 方案给你选，你点头我才写代码。
   ```

## 排错

| 现象 | 处理 |
| --- | --- |
| 中文乱码 / 语法错 | 脚本必须以 UTF-8 **带 BOM** 保存；若被改坏，`git checkout -- install/install-machine.ps1` 恢复 |
| 提示禁止运行脚本 | 用 `powershell -NoProfile -ExecutionPolicy Bypass -File ...` 显式绕过，不改系统策略 |
| 工作区 §2.6 没接上 | 脚本会打印「没探测到工作区」。问用户工作区根目录，再加 `-WorkspaceAgents "<目录>"`；确实没有就 `-WorkspaceAgents none` |
| 某个工具没装 | 脚本自动跳过（没有 `~\.codex` / `~\.claude` 就不装），属正常 |
| 网络拉不下来（代理） | 先确认代理是否在跑；或走 ZIP 方案 |

## ZIP 方案（没有 git / 网络时）

1. 从 Releases 下载 `UI优先开发流程-安装包-v*.zip`：
   `https://github.com/ljr282341583/dev-workflow/releases/latest`
2. 解压后，让用户双击里面的 `安装.cmd`（或你直接跑 `powershell -NoProfile -ExecutionPolicy Bypass -File "<解压目录>\install\install-machine.ps1"`）。

## 不要做的事

- 不要手工编辑 `~\.dsh\AGENTS.md`、`~\.codex\AGENTS.md`、`~\.claude\CLAUDE.md`（脚本会做，且带备份与判重）。
- 不要为了"确保生效"而重复插入红线（会重复，且脚本的判重会被绕过）。
- 不要把用户的密钥/路径写进任何笔记或仓库。
