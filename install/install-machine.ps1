<#
.SYNOPSIS
  一条命令装好「UI 优先开发流程」：技能 + 红线，支持 DSH / Codex / Claude Code。

.DESCRIPTION
  按 -Target 安装（默认 all，装了哪个工具就装哪个）：

  | Target | 技能目录                      | 红线文件                            | 额外 |
  |--------|-------------------------------|-------------------------------------|------|
  | dsh    | %USERPROFILE%\.agents\skills  | %USERPROFILE%\.dsh\AGENTS.md        | 还会插工作区 §2.6 |
  | codex  | %USERPROFILE%\.codex\skills   | %USERPROFILE%\.codex\AGENTS.md      | — |
  | claude | %USERPROFILE%\.claude\skills  | %USERPROFILE%\.claude\CLAUDE.md     | — |

  未安装的工具（对应目录不存在）自动跳过，不会凭空造目录。
  幂等：技能按 SHA256 判重；红线/§2.6 按标题判重；改文件前自动备份 *.bak-<时间>。
  工作区根自动探测（当前目录向上 → 本仓库向上 → DSH 登记表 storages\workspace.json）。

.PARAMETER Target
  dsh / codex / claude / all，默认 all

.PARAMETER WorkspaceAgents
  工作区根目录 / AGENTS.md / "auto"（默认自动探测）/ "none"（跳过）

.PARAMETER SpecRoot
  规范正文目录（写进红线的路径），默认本仓库根目录

.PARAMETER DryRun
  只打印计划，不写文件

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install\install-machine.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install\install-machine.ps1 -Target dsh -DryRun
#>
[CmdletBinding()]
param(
  [ValidateSet("dsh", "codex", "claude", "all")]
  [string]$Target = "all",
  [string]$WorkspaceAgents = "auto",
  [string]$SpecRoot,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SpecRoot)) { $SpecRoot = $repoRoot }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$userHome = $env:USERPROFILE
$marker = "## 开发流程红线"

$tpl = Join-Path $PSScriptRoot "redline-template.md"
if (-not (Test-Path $tpl)) { throw "缺少模板：$tpl" }
$fragment = (Get-Content $tpl -Raw -Encoding UTF8).Replace("{{SPEC_ROOT}}", $SpecRoot.TrimEnd("\"))

function Get-Targets {
  if ($Target -eq "all") { return @("dsh", "codex", "claude") }
  return @($Target)
}

function Install-Skill([string]$baseDir, [string]$skillSubPath) {
  $src = Join-Path $repoRoot "skill\ui-first-dev"
  if (-not (Test-Path (Join-Path $src "SKILL.md"))) {
    throw "找不到技能源文件：$src\SKILL.md（请在规范仓库内运行本脚本）"
  }
  $skillTarget = Join-Path $baseDir $skillSubPath
  $dst = Join-Path $skillTarget "ui-first-dev"
  $srcHash = (Get-FileHash (Join-Path $src "SKILL.md") -Algorithm SHA256).Hash
  $dstFile = Join-Path $dst "SKILL.md"
  $dstHash = if (Test-Path $dstFile) { (Get-FileHash $dstFile -Algorithm SHA256).Hash } else { $null }

  if ($dstHash -eq $srcHash) {
    "  技能已是最新，跳过：$dst"
  } elseif ($DryRun) {
    "  [dry] 复制技能：$src -> $dst"
  } else {
    New-Item -ItemType Directory -Force $skillTarget | Out-Null
    Copy-Item $src $dst -Recurse -Force
    "  已安装技能：$dst"
  }
}

function Add-Redline([string]$file, [string]$newFileHeader) {
  if (-not (Test-Path $file)) {
    if ($DryRun) {
      "  [dry] 新建并写入红线：$file"
    } else {
      New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
      [System.IO.File]::WriteAllText($file, ($newFileHeader + "`r`n`r`n" + $fragment), $utf8NoBom)
      "  已新建并写入红线：$file"
    }
    return
  }

  $content = Get-Content $file -Raw -Encoding UTF8
  if ($content -match [regex]::Escape($marker)) {
    "  红线已存在，跳过：$file"
  } elseif ($DryRun) {
    "  [dry] 追加红线到：$file"
  } else {
    $backup = "$file.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $file $backup -Force
    if ($content -match "^#\s") {
      $nl = $content.IndexOf("`n")
      if ($nl -lt 0) { $new = $content + "`r`n`r`n" + $fragment }
      else { $new = $content.Substring(0, $nl + 1) + "`r`n" + $fragment + "`r`n" + $content.Substring($nl + 1) }
    } else {
      $new = $fragment + "`r`n`r`n" + $content
    }
    [System.IO.File]::WriteAllText($file, $new, $utf8NoBom)
    "  已追加红线：$file（备份：$backup）"
  }
}

function Test-WorkspaceRoot([string]$dir) {
  if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
  if (-not (Test-Path -LiteralPath $dir)) { return $false }
  $agents = Join-Path $dir "AGENTS.md"
  if (-not (Test-Path -LiteralPath $agents)) { return $false }
  if (Test-Path -LiteralPath (Join-Path $dir "skills\registry.md")) { return $true }
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
  $dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $userHome ".dsh" }
  $reg = Join-Path $dshHome "storages\workspace.json"
  if (Test-Path -LiteralPath $reg) {
    $raw = Get-Content -LiteralPath $reg -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($raw, '"(?:path|root|dir)"\s*:\s*"((?:[^"\\]|\\.)*)"')) {
      $cands.Add(($m.Groups[1].Value -replace '\\\\', '\'))
    }
  }
  foreach ($c in $cands) { if (Test-WorkspaceRoot $c) { return (Resolve-Path -LiteralPath $c).Path } }
  return $null
}

function Add-WorkspaceSection {
  if ($WorkspaceAgents -eq "none") { "  工作区级 §2.6：按要求跳过"; return }

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

  $script:wsAgentsResolved = $WorkspaceAgents

  $waMarker = "### 2.6 带界面项目的开发流程"
  $snipFile = Join-Path $PSScriptRoot "workspace-agents-2.6.md"

  if (-not (Test-Path -LiteralPath $snipFile)) {
    throw "缺少片段文件：$snipFile"
  } elseif ([string]::IsNullOrWhiteSpace($WorkspaceAgents) -or -not (Test-Path -LiteralPath $WorkspaceAgents)) {
    "  工作区级 §2.6：没探测到工作区 AGENTS.md，跳过。"
    "    → 知道路径就显式传：-WorkspaceAgents `"<工作区根目录或AGENTS.md>`""
    "    → 这台机器没有工作区：-WorkspaceAgents none"
    return
  }

  if ($wsRoot) { "  工作区根：$wsRoot" } else { "  工作区根：$(Split-Path -Parent $WorkspaceAgents)" }
  $snipRaw = Get-Content $snipFile -Raw -Encoding UTF8
  $begin = "<!-- BEGIN-SECTION-2.6 -->"
  $end = "<!-- END-SECTION-2.6 -->"
  $b = $snipRaw.IndexOf($begin)
  $e = $snipRaw.IndexOf($end)
  if ($b -lt 0 -or $e -le $b) { throw "片段文件缺少 BEGIN/END 标记：$snipFile" }
  $section = $snipRaw.Substring($b + $begin.Length, $e - $b - $begin.Length).Trim("`r", "`n")

  $wa = Get-Content $WorkspaceAgents -Raw -Encoding UTF8
  if ($wa -match [regex]::Escape($waMarker)) {
    "  工作区 §2.6 已存在，跳过：$WorkspaceAgents"
  } elseif ($DryRun) {
    "  [dry] 插入 §2.6 到：$WorkspaceAgents"
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
    "  已插入工作区 §2.6：$WorkspaceAgents（备份：$backup2）"
  }
}

# ---------- 主流程 ----------
$done = @()
$targets = Get-Targets
foreach ($t in $targets) {
  switch ($t) {
    "dsh" {
      "== DSH =="
      Install-Skill $userHome ".agents\skills"
      Add-Redline (Join-Path $userHome ".dsh\AGENTS.md") "# 全局工作区约定"
      Add-WorkspaceSection
      $done += "DSH(技能+红线+工作区§2.6)"
    }
    "codex" {
      "== Codex CLI =="
      if (-not (Test-Path (Join-Path $userHome ".codex"))) {
        "  未安装（没有 ~\.codex），跳过"
      } else {
        Install-Skill $userHome ".codex\skills"
        Add-Redline (Join-Path $userHome ".codex\AGENTS.md") "# Global Rules"
        $done += "Codex(技能+红线)"
      }
    }
    "claude" {
      "== Claude Code =="
      if (-not (Test-Path (Join-Path $userHome ".claude"))) {
        "  未安装（没有 ~\.claude），跳过"
      } else {
        Install-Skill $userHome ".claude\skills"
        Add-Redline (Join-Path $userHome ".claude\CLAUDE.md") "# 全局约定（Claude Code）"
        $done += "Claude(技能+红线)"
      }
    }
  }
}

# ---------- 结果自检（给人看的人话结论） ----------
$checks = @()
function Add-Check([string]$name, [bool]$ok) { $script:checks += [pscustomobject]@{ Name = $name; Ok = $ok } }

$dshAgents = Join-Path $userHome ".dsh\AGENTS.md"
$codexAgents = Join-Path $userHome ".codex\AGENTS.md"
$claudeMd = Join-Path $userHome ".claude\CLAUDE.md"

if ($targets -contains "dsh") {
  Add-Check "DSH 技能已装" (Test-Path (Join-Path $userHome ".agents\skills\ui-first-dev\SKILL.md"))
  if (Test-Path $dshAgents) {
    Add-Check "DSH 全局红线已写入" ((Get-Content $dshAgents -Raw -Encoding UTF8) -match [regex]::Escape($marker))
  }
  if ($WorkspaceAgents -eq "none") {
    Add-Check "工作区 §2.6（按要求跳过）" $true
  } elseif ($script:wsAgentsResolved) {
    Add-Check "工作区 §2.6 已接上" ((Test-Path $script:wsAgentsResolved) -and
      ((Get-Content $script:wsAgentsResolved -Raw -Encoding UTF8) -match "### 2\.6 带界面项目的开发流程"))
  } else {
    Add-Check "工作区 §2.6 已接上（未探测到工作区，跳过）" $false
  }
}

if (Test-Path (Join-Path $userHome ".codex")) {
  Add-Check "Codex 技能已装" (Test-Path (Join-Path $userHome ".codex\skills\ui-first-dev\SKILL.md"))
  if (Test-Path $codexAgents) { Add-Check "Codex 红线已写入" ((Get-Content $codexAgents -Raw -Encoding UTF8) -match [regex]::Escape($marker)) }
}
if (Test-Path (Join-Path $userHome ".claude")) {
  Add-Check "Claude 技能已装" (Test-Path (Join-Path $userHome ".claude\skills\ui-first-dev\SKILL.md"))
  if (Test-Path $claudeMd) { Add-Check "Claude 红线已写入" ((Get-Content $claudeMd -Raw -Encoding UTF8) -match [regex]::Escape($marker)) }
}

""
"================ 安装结果 ================"
foreach ($c in $checks) {
  if ($c.Ok) { "  ✅ $($c.Name)" } else { "  ❌ $($c.Name)" }
}
$allOk = ($checks.Count -gt 0) -and (($checks | Where-Object { -not $_.Ok }).Count -eq 0)

""
if ($allOk) {
  "  🎉 全部就绪，以后不需要再装。"
  ""
  "  现在对 AI 说一句就能用："
  "     「帮我做个 XXX 的 App」"
  "  AI 会先问你需求 → 出 2~3 套 UI 方向给你选 → 你点「过」→ 它才开始写代码。"
  ""
  "  想自己确认：新开会话问一句「你有 ui-first-dev 技能吗？」"
} else {
  "  ⚠️ 上面有 ❌ 项没装上。把这段输出整段复制回给 AI，它能照着修。"
  "     重试命令（复制即用）："
  "       powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
}
"=========================================="
