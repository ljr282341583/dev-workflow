<#
.SYNOPSIS
  打一个「双击即装」的离线压缩包（给小白用的分发包）。

.DESCRIPTION
  产物：dist\UI优先开发流程-安装包-v<版本>.zip
  内容：仓库全部文件（去掉 .git 和 dist）+ 安装.cmd + 安装说明.txt（+ 大脑仓库的教程4，如果本机有）。
  解压后双击「安装.cmd」即可，无需 git、无需联网。

.PARAMETER Version
  版本号，默认 1.0.0，只影响 zip 文件名

.PARAMETER Open
  打包完成后打开 dist 目录

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install\打包一键安装.ps1 -Open
#>
[CmdletBinding()]
param(
  [string]$Version = "1.0.0",
  [switch]$Open
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $repoRoot "dist"
$stageName = "UI优先开发流程-安装包-v$Version"
$stage = Join-Path $env:TEMP $stageName

foreach ($f in @("安装.cmd", "install\install-machine.ps1")) {
  if (-not (Test-Path (Join-Path $repoRoot $f))) { throw "仓库不完整，缺少：$f" }
}

New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

# 1) 仓库内容（排除 .git / dist）
Get-ChildItem $repoRoot -Force |
  Where-Object { $_.Name -notin @(".git", "dist") } |
  ForEach-Object { Copy-Item $_.FullName -Destination $stage -Recurse -Force }

# 2) 顺手带上大脑仓库里的「教程4」，小白装完可以直接看怎么用
$brainFile = Join-Path $env:USERPROFILE ".agent-brain"
if (Test-Path $brainFile) {
  $brainRoot = (Get-Content $brainFile -Raw -Encoding UTF8).Trim()
  $tutorial = Join-Path $brainRoot "教程4-UI优先开发流程.md"
  if (Test-Path $tutorial) {
    Copy-Item $tutorial -Destination (Join-Path $stage "教程4-UI优先开发流程.md") -Force
    "已带上教程4：$tutorial"
  }
}

# 3) 顶层放一份「从这里开始」
$readme = @"
从这里开始
==========

1) 解压本压缩包到任意位置（桌面就行）
2) 双击「安装.cmd」
3) 看到「安装结果」全是 ✅ 就成功了

装完怎么用：对 AI 说「帮我做个 XXX 的 App」。
详细说明见「安装说明.txt」与「教程4-UI优先开发流程.md」。

规范正文：WORKFLOW.md（流程）、CHECKLIST-UI.md（自检清单）、templates\（模板与可点击原型）
"@
[System.IO.File]::WriteAllText((Join-Path $stage "从这里开始.txt"), $readme, (New-Object System.Text.UTF8Encoding($true)))

# 4) 压缩
# 注意：zip 文件名用 ASCII（中文字符经 gh CLI 上传会被改名成 "UI.-.-"），解压后的文件夹仍是中文
$zip = Join-Path $dist "ui-first-dev-installer-v$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal

$size = [math]::Round((Get-Item $zip).Length / 1MB, 2)
$files = (Get-ChildItem $stage -Recurse -File).Count
"打包完成：$zip"
"  含 $files 个文件，$size MB，解压后根目录是：$stageName\"
"  用法：解压 → 双击「安装.cmd」"
"  发 Release：gh release upload <tag> `"$zip`"（文件名保持 ASCII）"

if ($Open) { Start-Process explorer.exe $dist }
