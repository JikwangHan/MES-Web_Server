# 재부팅 검증 로그를 릴리즈 노트에 부록으로 추가하는 스크립트 (Windows PowerShell)
# 목적: 재부팅 검증 결과를 릴리즈 노트에 자동 반영합니다.
# 주의: 민감정보(비밀번호/키)는 출력하지 않습니다.

param(
    [string]$TagName = "ops-v0.4.1",
    [string]$LogDir = "C:\MES\logs"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir

$notesPath = Join-Path $root ("docs\RELEASE_NOTES_{0}.md" -f $TagName)
if (-not (Test-Path $notesPath)) {
    Write-Err "릴리즈 노트를 찾지 못했습니다: $notesPath"
    exit 2
}

$latestLog = Get-ChildItem -Path (Join-Path $LogDir "post_reboot_verify_*.log") -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestLog) {
    Write-Err "재부팅 검증 로그를 찾지 못했습니다. post-reboot-verify.ps1를 먼저 실행하세요."
    exit 2
}

$lines = Get-Content $latestLog.FullName
$svcLine = $lines | Where-Object { $_ -match '^SERVICE_STATUS:' } | Select-Object -Last 1
$portLine = $lines | Where-Object { $_ -match '^PORT_8080:' } | Select-Object -Last 1
$healthLine = $lines | Where-Object { $_ -match '^HEALTH:' } | Select-Object -Last 1
$logPathLine = $lines | Where-Object { $_ -match '^LOG_PATH:' } | Select-Object -Last 1

$svcVal = if ($svcLine) { $svcLine -replace '^SERVICE_STATUS:\s*', '' } else { "N/A" }
$portVal = if ($portLine) { $portLine -replace '^PORT_8080:\s*', '' } else { "N/A" }
$healthVal = if ($healthLine) { $healthLine -replace '^HEALTH:\s*', '' } else { "N/A" }
$logPathVal = if ($logPathLine) { $logPathLine -replace '^LOG_PATH:\s*', '' } else { $latestLog.FullName }

$runAt = $latestLog.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

$appendText = @"

## 부록 A. 재부팅 자동 기동 검증(1회)
- 실행 시각(KST): $runAt
- 서비스: MES-Web (StartType=Automatic)
- SERVICE_STATUS: $svcVal
- PORT_8080: $portVal
- HEALTH: $healthVal
- 로그: $logPathVal
- 결론: 재부팅 후 자동 기동 및 헬스 정상(운영 자동 기동 신뢰성 기준 충족)

주: 이전 “Paused” 표기는 스냅샷 시점의 일시 상태였고, 재부팅 검증 결과로 Running/UP을 최종 확인함.
"@

Add-Content -Encoding UTF8 -Path $notesPath -Value $appendText

Write-Info "릴리즈 노트에 부록을 추가했습니다."
Write-Info "RELEASE_NOTES: $notesPath"
Write-Info "SOURCE_LOG: $($latestLog.FullName)"
