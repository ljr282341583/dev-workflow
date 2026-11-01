<#
.SYNOPSIS
  在任意机器上一条命令装好「UI 优先开发流程」：技能 ui-first-dev + 全局红线。

.DESCRIPTION
  1) 把本仓库 skill/ui-first-dev 复制到技能目录（默认 %USERPROFILE%\.agents\skills）。
  2) 把 install/redline-template.md（替换 {{SPEC_ROOT}}）插入全局指令文件
     （默认 %USERPROFILE%\.dsh\AGENTS.md）。已存在「## 开发流程红线」则跳过；
     写入前自动备份为 AGENTS.md.bak-<时间>。

  幂等：重复执行只更新技能，不会把红线写两遍。

.PARAMETER SkillTarget
  技能安装目录，默认 %USERPROFILE%\.agents\skills

.PARAMETER AgentsFile
  全局 AGENTS.md 路径，默认 %USERPROFILE%\.dsh\AGENTS.md

.PARAMETER SpecRoot
  规范正文所在目录（写进红线的路径），默认本仓库根目录

.PARAMETER DryRun
  只打印计划，不写任何文件

.EXAMPLE
  pwsh -File .\install\install-machine.ps1

.EXAMPLE
  pwsh -File .\install\install-machine.ps1 -SpecRoot "D:\ai\dev-workflow" -DryRun
#>
[CmdletBinding()]
param(
  [string]$SkillTarget = (Join-Path $env:USERPROFILE ".agents\skills"),
  [string]$AgentsFile = (Join-Path $env:USERPROFILE ".dsh\AGENTS.md"),
  [string]$WorkspaceAgents,
  [string]$SpecRoot,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SpecRoot)) { $SpecRoot = $repoRoot }

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
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $AgentsFile)) {
  if ($DryRun) {
    "[dry] 新建并写入红线：$AgentsFile"
  } else {
    New-Item -ItemType Directory -Force (Split-Path $AgentsFile) | Out-Null
    [System.IO.File]::WriteAllText($AgentsFile, ("# 全局工作区约定`r`n`r`n" + $fragment), $utf8NoBom)
    "已新建并写入红线：$AgentsFile"
  }
} else {
  $content = Get-Content $AgentsFile -Raw -Encoding UTF8
  if ($content -match [regex]::Escape($marker)) {
    "红线已存在，跳过：$AgentsFile"
  } elseif ($DryRun) {
    "[dry] 追加红线到：$AgentsFile"
  } else {
    $backup = "$AgentsFile.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $AgentsFile $backup -Force
    if ($content -match "^#\s") {
      # 插到首个一级标题之后，保持"全局约定"在最前
      $nl = $content.IndexOf("`n")
      if ($nl -lt 0) { $new = $content + "`r`n`r`n" + $fragment }
      else { $new = $content.Substring(0, $nl + 1) + "`r`n" + $fragment + "`r`n" + $content.Substring($nl + 1) }
    } else {
      $new = $fragment + "`r`n`r`n" + $content
    }
    [System.IO.File]::WriteAllText($AgentsFile, $new, $utf8NoBom)
    "已追加红线：$AgentsFile（备份：$backup）"
  }
}

# ---------- 3) 工作区级红线（可选：-WorkspaceAgents <path>） ----------
if (-not [string]::IsNullOrWhiteSpace($WorkspaceAgents)) {
  $waMarker = "### 2.6 带界面项目的开发流程"
  $snipFile = Join-Path $PSScriptRoot "workspace-agents-2.6.md"
  if (-not (Test-Path $snipFile)) { throw "缺少片段文件：$snipFile" }
  if (-not (Test-Path $WorkspaceAgents)) { throw "找不到工作区 AGENTS.md：$WorkspaceAgents" }

  $snipRaw = Get-Content $snipFile -Raw -Encoding UTF8
  $begin = "<!-- BEGIN-SECTION-2.6 -->"
  $end = "<!-- END-SECTION-2.6 -->"
  $b = $snipRaw.IndexOf($begin)
  $e = $snipRaw.IndexOf($end)
  if ($b -lt 0 -or $e -le $b) { throw "片段文件缺少 BEGIN/END 标记：$snipFile" }
  $section = $snipRaw.Substring($b + $begin.Length, $e - $b - $begin.Length).Trim("`r", "`n")

  $wa = Get-Content $WorkspaceAgents -Raw -Encoding UTF8
  if ($wa -match [regex]::Escape($waMarker)) {
    "工作区红线已存在，跳过：$WorkspaceAgents"
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
    "已插入 §2.6：$WorkspaceAgents（备份：$backup2）"
  }
} else {
  "工作区级红线：未指定 -WorkspaceAgents，跳过（换机器时建议加上）"
}

# ---------- 4) 收尾提示 ----------
""
"完成。验证方式："
"  1) 新开会话问 agent：你有 ui-first-dev 技能吗？（DSH 会监视技能目录，通常无需重启）"
"  2) 打开 $AgentsFile 确认包含「$marker」"
"  3) 说「帮我做个 XXX 的 APK」，第一条回复应是问题（P0）而不是代码"
