<#
.SYNOPSIS
  在任意机器上一条命令装好「UI 优先开发流程」：技能 ui-first-dev + 全局红线 + 工作区级 §2.6。

.DESCRIPTION
  1) 技能：把本仓库 skill/ui-first-dev 复制到技能目录（默认 %USERPROFILE%\.agents\skills）。
  2) 全局红线：把 install/redline-template.md（替换 {{SPEC_ROOT}}）插入全局指令文件
     （默认 %USERPROFILE%\.dsh\AGENTS.md）。已存在「## 开发流程红线」则跳过。
  3) 工作区级：找到工作区根（含 AGENTS.md + skills\registry.md 的目录），
     把 install/workspace-agents-2.6.md 里 BEGIN/END 之间的 §2.6 插进去；
     已存在该节则跳过。工作区根默认自动探测，也可用 -WorkspaceAgents 指定。

  工作区根探测顺序：
    a) -WorkspaceAgents 显式指定的目录/文件
    b) 当前目录向上逐级
    c) 本仓库根目录向上逐级
    d) DSH 登记表 %DSH_HOME%\storages\workspace.json 里登记过的路径

  幂等：重复执行只更新技能；红线与 §2.6 已存在则跳过；改文件前自动备份。

.PARAMETER SkillTarget
  技能安装目录，默认 %USERPROFILE%\.agents\skills

.PARAMETER AgentsFile
  全局 AGENTS.md 路径，默认 %USERPROFILE%\.dsh\AGENTS.md

.PARAMETER WorkspaceAgents
  工作区 AGENTS.md 路径 / 工作区根目录 / "auto"（默认自动探测）/ "none"（跳过这一项）

.PARAMETER SpecRoot
  规范正文所在目录（写进红线的路径），默认本仓库根目录

.PARAMETER DryRun
  只打印计划，不写任何文件

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install\install-machine.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install\install-machine.ps1 -WorkspaceAgents "D:\my-workspace" -DryRun
#>
[CmdletBinding()]
param(
  [string]$SkillTarget = (Join-Path $env:USERPROFILE ".agents\skills"),
  [string]$AgentsFile = (Join-Path $env:USERPROFILE ".dsh\AGENTS.md"),
  [string]$WorkspaceAgents = "auto",
  [string]$SpecRoot,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SpecRoot)) { $SpecRoot = $repoRoot }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Test-WorkspaceRoot([string]$dir) {
  if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
  if (-not (Test-Path -LiteralPath $dir)) { return $false }
  $agents = Join-Path $dir "AGENTS.md"
  if (-not (Test-Path -LiteralPath $agents)) { return $false }
  # 强信号一：工作区技能注册表
  if (Test-Path -LiteralPath (Join-Path $dir "skills\registry.md")) { return $true }
  # 强信号二：AGENTS.md 内容里明确写了"工作区"协作规范
  try {
    $head = Get-Content -LiteralPath $agents -Raw -Encoding UTF8
    if ($head.Length -gt 4000) { $head = $head.Substring(0, 4000) }
    if ($head -match "工作区通用协作规范|本工作区") { return $true }
  } catch { }
  return $false
}

function Resolve-WorkspaceRoot([string[]]$startDirs) {
  $cands = New-Object System.Collections.Generic.List[string]
  foreach ($sd in $startDirs) {
    if ([string]::IsNullOrWhiteSpace($sd)) { continue }
    $d = $sd
    for ($i = 0; $i -lt 12 -and $d; $i++) {
      $cands.Add($d)
      $parent = Split-Path -Parent $d
      if ([string]::IsNullOrEmpty($parent) -or $parent -eq $d) { break }
      $d = $parent
    }
  }

  # DSH 自己的登记表里登记过的路径（不写死盘符，各机器自适应）
  $dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE ".dsh" }
  $reg = Join-Path $dshHome "storages\workspace.json"
  if (Test-Path -LiteralPath $reg) {
    $raw = Get-Content -LiteralPath $reg -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($raw, '"(?:path|root|dir)"\s*:\s*"((?:[^"\\]|\\.)*)"')) {
      $cands.Add(($m.Groups[1].Value -replace '\\\\', '\'))
    }
  }

  foreach ($c in $cands) {
    if (Test-WorkspaceRoot $c) { return (Resolve-Path -LiteralPath $c).Path }
  }
  return $null
}

# ---------- 1) 技能 ----------
$src = Join-Path $repoRoot "skill\ui-first-dev"
$dst = Join-Path $SkillTarget "ui-first-dev"

if (-not (Test-Path (Join-Path $src "SKILL.md"))) {
  throw "找不到技能源文件：$src\SKILL.md（请在规范仓库内运行本脚本）"
}

$srcHash = (Get-FileHash (Join-Path $src "SKILL.md") -Algorithm SHA256).Hash
$dstFile = Join-Path $dst "SKILL.md"
$dstHash = if (Test-Path $dstFile) { (Get-FileHash $dstFile -Algorithm SHA256).Hash } else { $null }

if ($dstHash -eq $srcHash) {
  "技能已是最新，跳过：$dst"
} elseif ($DryRun) {
  "[dry] 复制技能：$src -> $dst"
} else {
  New-Item -ItemType Directory -Force $SkillTarget | Out-Null
  Copy-Item $src $dst -Recurse -Force
  "已安装技能：$dst"
}

# ---------- 2) 全局红线 ----------
$tpl = Join-Path $PSScriptRoot "redline-template.md"
if (-not (Test-Path $tpl)) { throw "缺少模板：$tpl" }

$fragment = (Get-Content $tpl -Raw -Encoding UTF8).Replace("{{SPEC_ROOT}}", $SpecRoot.TrimEnd("\"))
$marker = "## 开发流程红线"

if (-not (Test-Path $AgentsFile)) {
  if ($DryRun) {
    "[dry] 新建并写入全局红线：$AgentsFile"
  } else {
    New-Item -ItemType Directory -Force (Split-Path $AgentsFile) | Out-Null
    [System.IO.File]::WriteAllText($AgentsFile, ("# 全局工作区约定`r`n`r`n" + $fragment), $utf8NoBom)
    "已新建并写入全局红线：$AgentsFile"
  }
} else {
  $content = Get-Content $AgentsFile -Raw -Encoding UTF8
  if ($content -match [regex]::Escape($marker)) {
    "全局红线已存在，跳过：$AgentsFile"
  } elseif ($DryRun) {
    "[dry] 追加全局红线到：$AgentsFile"
  } else {
    $backup = "$AgentsFile.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $AgentsFile $backup -Force
    if ($content -match "^#\s") {
      $nl = $content.IndexOf("`n")
      if ($nl -lt 0) { $new = $content + "`r`n`r`n" + $fragment }
      else { $new = $content.Substring(0, $nl + 1) + "`r`n" + $fragment + "`r`n" + $content.Substring($nl + 1) }
    } else {
      $new = $fragment + "`r`n`r`n" + $content
    }
    [System.IO.File]::WriteAllText($AgentsFile, $new, $utf8NoBom)
    "已追加全局红线：$AgentsFile（备份：$backup）"
  }
}

# ---------- 3) 工作区级 §2.6 ----------
if ($WorkspaceAgents -eq "none") {
  "工作区级 §2.6：按要求跳过"
} else {
  $wsRoot = $null
  if ($WorkspaceAgents -ne "auto") {
    if (Test-Path -LiteralPath $WorkspaceAgents -PathType Container) {
      $wsRoot = $WorkspaceAgents
      $WorkspaceAgents = Join-Path $WorkspaceAgents "AGENTS.md"
    }
  } else {
    $wsRoot = Resolve-WorkspaceRoot @((Get-Location).Path, $repoRoot, $PSScriptRoot)
    if ($wsRoot) { $WorkspaceAgents = Join-Path $wsRoot "AGENTS.md" }
  }

  $waMarker = "### 2.6 带界面项目的开发流程"
  $snipFile = Join-Path $PSScriptRoot "workspace-agents-2.6.md"

  if (-not (Test-Path -LiteralPath $snipFile)) {
    throw "缺少片段文件：$snipFile"
  } elseif ([string]::IsNullOrWhiteSpace($WorkspaceAgents) -or -not (Test-Path -LiteralPath $WorkspaceAgents)) {
    "工作区级 §2.6：没探测到工作区 AGENTS.md，跳过。"
    "  → 知道路径就显式传：-WorkspaceAgents `"<工作区根目录或AGENTS.md>`""
    "  → 这台机器没有工作区：-WorkspaceAgents none"
  } else {
    if ($wsRoot) { "工作区根：$wsRoot" } else { "工作区根：$(Split-Path -Parent $WorkspaceAgents)" }
    $snipRaw = Get-Content $snipFile -Raw -Encoding UTF8
    $begin = "<!-- BEGIN-SECTION-2.6 -->"
    $end = "<!-- END-SECTION-2.6 -->"
    $b = $snipRaw.IndexOf($begin)
    $e = $snipRaw.IndexOf($end)
    if ($b -lt 0 -or $e -le $b) { throw "片段文件缺少 BEGIN/END 标记：$snipFile" }
    $section = $snipRaw.Substring($b + $begin.Length, $e - $b - $begin.Length).Trim("`r", "`n")

    $wa = Get-Content $WorkspaceAgents -Raw -Encoding UTF8
    if ($wa -match [regex]::Escape($waMarker)) {
      "工作区 §2.6 已存在，跳过：$WorkspaceAgents"
    } elseif ($DryRun) {
      "[dry] 插入 §2.6 到：$WorkspaceAgents"
    } else {
      $backup2 = "$WorkspaceAgents.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      Copy-Item $WorkspaceAgents $backup2 -Force

      $lines = $wa -split "`r?`n"
      $anchor = -1
      for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^##\s*3\.") { $anchor = $i; break } }
      if ($anchor -lt 0) { for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^##\s*7\.") { $anchor = $i; break } } }

      if ($anchor -le 0) {
        $new2 = $section + "`r`n`r`n" + $wa
      } else {
        $before = ($lines[0..($anchor - 1)] -join "`r`n").TrimEnd()
        $after = ($lines[$anchor..($lines.Count - 1)] -join "`r`n")
        $new2 = $before + "`r`n`r`n" + $section + "`r`n`r`n" + $after
      }
      [System.IO.File]::WriteAllText($WorkspaceAgents, $new2, $utf8NoBom)
      "已插入工作区 §2.6：$WorkspaceAgents（备份：$backup2）"
    }
  }
}

# ---------- 4) 收尾提示 ----------
""
"完成。验证方式："
"  1) 新开会话问 agent：你有 ui-first-dev 技能吗？（DSH 会监视技能目录，通常无需重启）"
"  2) 打开 $AgentsFile 确认包含「$marker」"
"  3) 工作区 AGENTS.md 确认包含「### 2.6 带界面项目的开发流程」"
"  4) 说「帮我做个 XXX 的 APK」，第一条回复应是问题（P0）而不是代码"
