# 릴리즈 태그 및 노트 생성 스크립트 (Windows PowerShell)
# 목적: 운영 증빙을 포함한 릴리즈 노트를 생성하고 태그를 부여합니다.
# 주의: 민감정보(비밀번호/키)는 출력하지 않습니다.

param(
    [string]$TagName = "ops-v0.4.0",
    [switch]$PushTag
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# Git 상태 확인
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
Set-Location $root

$inside = git rev-parse --is-inside-work-tree 2>$null
if ($inside -ne "true") {
    Write-Err "Git 저장소가 아닙니다."
    exit 2
}

$dirty = git status --porcelain
if ($dirty) {
    Write-Err "커밋되지 않은 변경이 있습니다. 정리 후 다시 실행하세요."
    exit 2
}

$branch = git rev-parse --abbrev-ref HEAD
if ($branch -ne "main") {
    Write-Err "현재 브랜치가 main이 아닙니다: $branch"
    exit 2
}

# 태그 존재 확인
$tagExists = git tag --list $TagName
if ($tagExists) {
    Write-Err "태그가 이미 존재합니다: $TagName"
    exit 2
}

# 최신 증빙 파일 탐색
$perfCsv = Get-ChildItem C:\MES\perf\perf_baseline_*.csv -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$perfGate = Get-ChildItem C:\MES\perf\perf_gate_*.json -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$evidenceZip = Get-ChildItem C:\MES\evidence\evidence_*.zip -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$opsLog = Get-ChildItem C:\MES\ops\ops_daily_*.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $evidenceZip -or -not $opsLog) {
    Write-Err "필수 증빙이 없습니다. evidence zip 또는 ops log를 확인하세요."
    exit 2
}

# 상태 스냅샷
$svcInfo = Get-Service -Name "MES-Web" -ErrorAction SilentlyContinue | Select-Object Status,StartType,Name
$health = "N/A"
try {
    $healthResp = Invoke-RestMethod http://localhost:8080/actuator/health -TimeoutSec 5
    $health = $healthResp.status
} catch {}
$port = netstat -ano | findstr ":8080"

# ops 로그에서 상태 추출
$opsStatus = "N/A"
$perfGateExit = "N/A"
if ($opsLog) {
    $tail = Get-Content $opsLog.FullName -Tail 200
    $line1 = $tail | Where-Object { $_ -match '^OPS_STATUS:' } | Select-Object -Last 1
    if ($line1) { $opsStatus = $line1 -replace '^OPS_STATUS:\s*', '' }
    $line2 = $tail | Where-Object { $_ -match '^PERF_GATE_EXITCODE:' } | Select-Object -Last 1
    if ($line2) { $perfGateExit = $line2 -replace '^PERF_GATE_EXITCODE:\s*', '' }
}

# 릴리즈 노트 생성
$notesDir = Join-Path $root "docs"
New-Item -ItemType Directory -Force -Path $notesDir | Out-Null
$notesPath = Join-Path $notesDir ("RELEASE_NOTES_{0}.md" -f $TagName)

$commitList = git log -n 20 --pretty=format:"- %s (%h)"

$commitShort = git rev-parse --short HEAD
$svcStatus = if ($svcInfo) { $svcInfo.Status } else { "N/A" }
$svcStartType = if ($svcInfo) { $svcInfo.StartType } else { "N/A" }
$perfCsvPath = if ($perfCsv) { $perfCsv.FullName } else { "N/A" }
$perfGatePath = if ($perfGate) { $perfGate.FullName } else { "N/A" }
$evidencePath = if ($evidenceZip) { $evidenceZip.FullName } else { "N/A" }
$opsLogPath = if ($opsLog) { $opsLog.FullName } else { "N/A" }

$notesTemplate = @'
# Release Notes - {0}

## 1. 태그/커밋
- Tag: {0}
- Branch: {1}
- Commit: {2}

## 2. 변경 요약
{3}

## 3. 운영 검증 결과
- OPS_STATUS: {4}
- HEALTH: {5}
- PERF_GATE_EXITCODE: {6}

## 4. 증빙 경로
- PERF_CSV: {7}
- PERF_GATE_JSON: {8}
- EVIDENCE_ZIP: {9}
- OPS_LOG: {10}

## 5. 상태 스냅샷
- Service: {11} / {12}
- Port 8080:
{13}

## 6. Known Issues
- 없음

## 7. 재현 커맨드
- ops-daily-check: `powershell -File .\scripts\ops-daily-check.ps1`
- deploy-rehearsal: `powershell -File .\scripts\deploy-rehearsal.ps1 -ZipPath <latest>`
- service check: `Get-Service -Name "MES-Web"`
'@

$notesContent = $notesTemplate -f `
    $TagName, $branch, $commitShort, $commitList, `
    $opsStatus, $health, $perfGateExit, `
    $perfCsvPath, $perfGatePath, $evidencePath, $opsLogPath, `
    $svcStatus, $svcStartType, $port

$notesContent | Set-Content -Encoding UTF8 $notesPath

# 커밋/태그
$diff = git status --porcelain
if ($diff) {
    git add $notesPath
    git commit -m "chore(release): $TagName notes"
}

git tag -a $TagName -m "$TagName release"

if ($PushTag) {
    git push origin main
    git push origin $TagName
}

Write-Host "RELEASE_TAG: $TagName"
Write-Host "RELEASE_NOTES: $notesPath"
Write-Host "EVIDENCE_ZIP: $($evidenceZip.FullName)"
Write-Host "PERF_GATE_JSON: $($perfGate.FullName)"
Write-Host "SERVICE_STATUS: $($svcInfo.Status)"
