# 재부팅 후 원샷 마감 스크립트 (Windows PowerShell)
# 목적: 재부팅 검증 로그 생성 + 릴리즈 노트 부록 반영을 한 번에 수행합니다.
# 주의: 민감정보(비밀번호/키)는 출력하지 않습니다.

param(
    [string]$TagName = "ops-v0.4.1",
    [string]$RepoRoot = $null,
    [string]$AppHome = "C:\MES\app\mes-web"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# RepoRoot 자동 추론
if (-not $RepoRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Split-Path -Parent $scriptDir
}

$verifyScript = Join-Path $AppHome "scripts\post-reboot-verify.ps1"
$appendScript = Join-Path $RepoRoot "scripts\append-reboot-appendix.ps1"

if (-not (Test-Path $verifyScript)) {
    Write-Err "post-reboot-verify.ps1를 찾지 못했습니다: $verifyScript"
    exit 1
}
if (-not (Test-Path $appendScript)) {
    Write-Err "append-reboot-appendix.ps1를 찾지 못했습니다: $appendScript"
    exit 2
}

Write-Info "재부팅 검증 스크립트를 실행합니다."
& powershell -ExecutionPolicy Bypass -File $verifyScript
if ($LASTEXITCODE -ne 0) {
    Write-Err "재부팅 검증 실패(exit $LASTEXITCODE)"
    exit 1
}

# 최신 로그 경로 찾기
$latestLog = Get-ChildItem -Path "C:\MES\logs\post_reboot_verify_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestLog) {
    Write-Err "재부팅 검증 로그를 찾지 못했습니다."
    exit 1
}

# 헬스 재확인(최대 3회, 5초 간격)
$healthOk = $false
for ($i=1; $i -le 3; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:8080/actuator/health" -TimeoutSec 5
        if ($resp.status -eq "UP") { $healthOk = $true; break }
    } catch {}
    Start-Sleep -Seconds 5
}

if (-not $healthOk) {
    Write-Err "헬스 재확인 실패"
    exit 1
}

Write-Info "릴리즈 노트 부록을 추가합니다."
& powershell -ExecutionPolicy Bypass -File $appendScript -TagName $TagName
if ($LASTEXITCODE -ne 0) {
    Write-Err "릴리즈 노트 부록 추가 실패(exit $LASTEXITCODE)"
    exit 2
}

$notesPath = Join-Path $RepoRoot ("docs\RELEASE_NOTES_{0}.md" -f $TagName)

Write-Host "FINAL_STATUS: PASS"
Write-Host "TAG: $TagName"
Write-Host "LOG_PATH: $($latestLog.FullName)"
Write-Host "RELEASE_NOTES: $notesPath"
