# 일간 운영 점검 작업 스케줄러 등록 스크립트 (Windows PowerShell)
# 목적: 매일 ops-daily-check.ps1를 자동 실행하도록 등록합니다.
# 주의: 관리자 권한이 필요합니다.

param(
    [string]$TaskName = "MES-OpsDailyCheck",
    [string]$ScriptPath = "C:\MES\app\mes-web\scripts\ops-daily-check.ps1",
    [string]$RunTime = "02:10"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

if (-not (Test-Path $ScriptPath)) {
    Write-Err "스크립트를 찾지 못했습니다: $ScriptPath"
    exit 2
}

# 기존 작업이 있으면 삭제
$exists = schtasks.exe /Query /TN $TaskName 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Info "기존 작업이 있어 삭제합니다: $TaskName"
    schtasks.exe /Delete /TN $TaskName /F | Out-Null
}

# 작업 생성
$command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
schtasks.exe /Create /TN $TaskName /SC DAILY /ST $RunTime /RL HIGHEST /TR $command | Out-Null

Write-Info "작업 등록 완료: $TaskName"
Write-Info "실행 시간: 매일 $RunTime"
Write-Info "명령: $command"
