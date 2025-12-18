# 운영 점검 자동화 스크립트 (Windows PowerShell)
# 목적: Docker/DB/DR Lite/부팅/성능/증빙을 1회 실행으로 점검합니다.
# 주의: 민감정보(비밀번호/키)는 출력하지 않습니다.

param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info {
    param([string]$msg)
    Write-Host "[INFO] $msg"
}

function Write-Warn {
    param([string]$msg)
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$msg)
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

function Resolve-Script {
    param([string[]]$candidates)
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

$scriptDir = $PSScriptRoot
$root = Split-Path -Parent $scriptDir
$opsDir = "C:\MES\ops"
New-Item -ItemType Directory -Force -Path $opsDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmm"
$opsLog = Join-Path $opsDir ("ops_daily_{0}.log" -f $ts)

$opsStatus = "FAIL"
$drExit = "N/A"
$health = "N/A"
$perfCsv = "N/A"
$perfGateJson = "N/A"
$evidenceZip = "N/A"
$finalExit = 0

try {
    Start-Transcript -Path $opsLog | Out-Null

    # 1) Docker 데몬 체크
    Write-Info "Docker 데몬 확인"
    $dockerInfo = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker Desktop을 실행하고 Engine running 상태를 확인하세요."
        $finalExit = 2
        throw "docker"
    }

    # 2) DB 컨테이너 체크/기동
    $container = "mes-mariadb"
    Write-Info "DB 컨테이너 확인: $container"
    $containerInfo = & docker ps -a --filter "name=$container" --format "{{.Names}}|{{.Status}}"
    if (-not $containerInfo) {
        Write-Err "컨테이너가 없습니다: $container"
        Write-Info "필요 시 컨테이너를 생성한 뒤 다시 실행하세요."
        $finalExit = 2
        throw "container_missing"
    }
    if ($containerInfo -notmatch "Up") {
        Write-Info "컨테이너가 중지 상태라서 시작합니다: $container"
        & docker start $container | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Err "컨테이너 시작 실패: $container"
            $finalExit = 2
            throw "container_start"
        }
    }

    # 3) DR Lite 검증
    $verifyPath = Resolve-Script @(
        (Join-Path $scriptDir "verify-dr-lite.ps1"),
        (Join-Path $root "release-template\scripts\verify-dr-lite.ps1"),
        (Join-Path $root "scripts\verify-dr-lite.ps1")
    )
    if (-not $verifyPath) {
        Write-Err "verify-dr-lite.ps1를 찾을 수 없습니다."
        $finalExit = 2
        throw "verify_missing"
    }
    Write-Info "DR Lite 검증 실행"
    & $verifyPath
    $drExit = $LASTEXITCODE
    if ($drExit -ne 0) {
        Write-Err "DR Lite 검증 실패(exit $drExit)"
        $finalExit = 1
        throw "dr_fail"
    }

    # 4) 부팅 + 성능 체인
    $diagPath = Resolve-Script @(
        (Join-Path $scriptDir "diagnose-boot.ps1"),
        (Join-Path $root "scripts\diagnose-boot.ps1")
    )
    if (-not $diagPath) {
        Write-Err "diagnose-boot.ps1를 찾을 수 없습니다."
        $finalExit = 2
        throw "diag_missing"
    }
    Write-Info "부팅/성능 진단 실행"
    $diagOutput = & $diagPath 2>&1
    $diagLines = $diagOutput | ForEach-Object { $_.ToString() }

    $healthLine = $diagLines | Where-Object { $_ -match '^HEALTH:' } | Select-Object -Last 1
    if ($healthLine) { $health = $healthLine -replace '^HEALTH:\s*', '' }

    $perfCsvLine = $diagLines | Where-Object { $_ -match '^PERF_CSV:' } | Select-Object -Last 1
    if ($perfCsvLine) { $perfCsv = $perfCsvLine -replace '^PERF_CSV:\s*', '' }

    $perfGateLine = $diagLines | Where-Object { $_ -match '^PERF_GATE_JSON:' } | Select-Object -Last 1
    if ($perfGateLine) { $perfGateJson = $perfGateLine -replace '^PERF_GATE_JSON:\s*', '' }

    $gateExitLine = $diagLines | Where-Object { $_ -match '^PERF_GATE_EXITCODE:' } | Select-Object -Last 1
    $perfGateExit = if ($gateExitLine) { ($gateExitLine -replace '^PERF_GATE_EXITCODE:\s*', '') } else { "N/A" }

    if ($perfGateExit -ne "0") {
        Write-Err "성능 게이트 실패(exit $perfGateExit)"
        $finalExit = 1
        throw "perf_gate_fail"
    }
    if (-not $perfGateJson -or $perfGateJson -eq "N/A" -or -not (Test-Path -LiteralPath $perfGateJson)) {
        Write-Err "성능 리포트(JSON) 파일이 없습니다."
        $finalExit = 2
        throw "perf_json_missing"
    }

    # 5) 증빙 ZIP
    $collectPath = Resolve-Script @(
        (Join-Path $scriptDir "collect-evidence.ps1"),
        (Join-Path $root "scripts\collect-evidence.ps1")
    )
    if (-not $collectPath) {
        Write-Err "collect-evidence.ps1를 찾을 수 없습니다."
        $finalExit = 2
        throw "collect_missing"
    }
    Write-Info "증빙 ZIP 생성"
    $collectOutput = & $collectPath 2>&1
    $collectLine = $collectOutput | Where-Object { $_ -match '^EVIDENCE_ZIP:' } | Select-Object -Last 1
    if ($collectLine) { $evidenceZip = $collectLine -replace '^EVIDENCE_ZIP:\s*', '' }
    if (-not $evidenceZip -or $evidenceZip -eq "N/A") {
        $recentZip = Get-ChildItem C:\MES\evidence\evidence_*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($recentZip) { $evidenceZip = $recentZip.FullName }
    }
    if (-not $evidenceZip -or $evidenceZip -eq "N/A" -or -not (Test-Path -LiteralPath $evidenceZip)) {
        Write-Err "증빙 ZIP 생성 실패"
        $finalExit = 2
        throw "evidence_missing"
    }

    $opsStatus = "PASS"
    $finalExit = 0
} catch {
    if ($finalExit -eq 0) { $finalExit = 1 }
} finally {
    Write-Host "OPS_STATUS: $opsStatus"
    Write-Host "DR_VERIFY_EXIT: $drExit"
    Write-Host "HEALTH: $health"
    Write-Host "PERF_CSV: $perfCsv"
    Write-Host "PERF_GATE_JSON: $perfGateJson"
    Write-Host "EVIDENCE_ZIP: $evidenceZip"
    Write-Host "OPS_LOG: $opsLog"
    try { Stop-Transcript | Out-Null } catch {}
    exit $finalExit
}
