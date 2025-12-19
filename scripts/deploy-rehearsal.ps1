# 배포 ZIP 실배포 리허설 스크립트 (Windows PowerShell)
# 목적: 배포 ZIP 전개 -> ops 점검 -> NSSM 서비스 설치/검증 -> 증빙 ZIP 생성까지 자동화합니다.
# 주의: 민감정보(비밀번호/키)는 출력하지 않습니다.

param(
    [string]$ZipPath,
    [string]$DeployDir = "C:\MES\app\mes-web",
    [string]$ServiceName = "MES-Web",
    [switch]$DoServiceInstall = $true,
    [switch]$DoOpsCheck = $true,
    [switch]$DoEvidenceZip = $true,
    [switch]$AsAdmin = $false
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

function Is-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LatestFile {
    param([string]$pattern)
    $items = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    return $items | Select-Object -First 1
}

$opsStatus = "N/A"
$opsExit = "N/A"
$opsLog = "N/A"
$opsEvidence = "N/A"
$rehearsalStatus = "FAIL"
$rehearsalLog = "N/A"
$serviceStatus = "N/A (service not installed)"
$health = "N/A"
$rehearsalZip = "N/A"
$deployRoot = $DeployDir
$exitCode = 0

try {
    # 8080 포트 점유 정리(리허설 모드에서만)
    $listen = netstat -ano | findstr ":8080" | findstr LISTENING
    if ($listen) {
        Write-Warn "포트 8080 사용 중입니다. 리허설을 위해 정리합니다."
        try {
            $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Info "서비스 중지: $ServiceName"
                Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            }
        } catch {}
        $listen | ForEach-Object { $_.Trim() } | ForEach-Object {
            $procId = ($_ -split "\s+")[-1]
            $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($p) {
                Write-Warn "PID=$procId NAME=$($p.ProcessName) 종료"
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # 관리자 재실행 처리
    if ($DoServiceInstall -and -not (Is-Admin)) {
        if ($AsAdmin) {
            $args = @(
                "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", "$PSCommandPath",
                "-ZipPath", "$ZipPath",
                "-DeployDir", "$DeployDir",
                "-ServiceName", "$ServiceName"
            )
            if ($DoServiceInstall) { $args += "-DoServiceInstall" }
            if ($DoOpsCheck) { $args += "-DoOpsCheck" }
            if ($DoEvidenceZip) { $args += "-DoEvidenceZip" }
            Start-Process powershell -Verb RunAs -ArgumentList $args
            return
        } else {
            Write-Err "서비스 설치/기동은 관리자 권한이 필요합니다. -AsAdmin 옵션으로 다시 실행하세요."
            $exitCode = 2
            throw "admin_required"
        }
    }

    # ZipPath 자동 탐색
    if (-not $ZipPath) {
        $latestZip = Get-LatestFile "C:\MES\dist\mes-web_release_*.zip"
        if ($latestZip) { $ZipPath = $latestZip.FullName }
    }
    if (-not $ZipPath -or -not (Test-Path -LiteralPath $ZipPath)) {
        Write-Err "배포 ZIP을 찾지 못했습니다."
        $exitCode = 2
        throw "zip_missing"
    }

    # 전개 폴더 준비
    if (Test-Path $DeployDir) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmm"
        $backupDir = "${DeployDir}_prev_$stamp"
        Write-Info "기존 폴더를 백업으로 이동합니다: $backupDir"
        try {
            Move-Item -Force $DeployDir $backupDir
        } catch {
            Write-Warn "기존 폴더 이동 실패. 사용 중인 프로세스가 있을 수 있습니다."
            Write-Warn "가능하면 C:\\MES\\app\\mes-web 사용 중인 창/프로세스를 종료한 뒤 다시 실행하세요."
        }
    }
    New-Item -ItemType Directory -Force -Path $DeployDir | Out-Null

    # 전개
    Write-Info "ZIP 전개: $ZipPath -> $DeployDir"
    Expand-Archive -Force -Path $ZipPath -DestinationPath $DeployDir

    # 전개 루트 판단
    $deployRoot = if (Test-Path (Join-Path $DeployDir "release-template\scripts\ops-daily-check.ps1")) {
        Join-Path $DeployDir "release-template"
    } else {
        $DeployDir
    }

    # 필수 파일 확인
    $runProd = Join-Path $deployRoot "bin\run-prod.ps1"
    $runLocal = Join-Path $deployRoot "bin\run-local.ps1"
    $opsPath = Join-Path $deployRoot "scripts\ops-daily-check.ps1"
    $svcInstall = Join-Path $deployRoot "scripts\windows-service-install.ps1"

    if (-not (Test-Path $runProd) -and -not (Test-Path $runLocal)) {
        Write-Err "run-prod.ps1 또는 run-local.ps1를 찾지 못했습니다."
        $exitCode = 2
        throw "run_missing"
    }
    if (-not (Test-Path $opsPath)) {
        Write-Err "ops-daily-check.ps1를 찾지 못했습니다."
        $exitCode = 2
        throw "ops_missing"
    }
    if (-not (Test-Path $svcInstall)) {
        Write-Err "windows-service-install.ps1를 찾지 못했습니다."
        $exitCode = 2
        throw "svc_missing"
    }

    # ops-daily-check 실행
    if ($DoOpsCheck) {
        Write-Info "ops-daily-check 실행"
        Push-Location $deployRoot
        $opsOutput = & powershell -ExecutionPolicy Bypass -File .\scripts\ops-daily-check.ps1 2>&1 | ForEach-Object { $_.ToString() }
        $opsOutput | ForEach-Object { Write-Host $_ }
        $opsExit = $LASTEXITCODE
        Pop-Location

        $opsStatusLine = $opsOutput | Where-Object { $_ -match '^OPS_STATUS:' } | Select-Object -Last 1
        if ($opsStatusLine) { $opsStatus = $opsStatusLine -replace '^OPS_STATUS:\s*', '' }
        $opsLogLine = $opsOutput | Where-Object { $_ -match '^OPS_LOG:' } | Select-Object -Last 1
        if ($opsLogLine) { $opsLog = $opsLogLine -replace '^OPS_LOG:\s*', '' }
        $opsEvLine = $opsOutput | Where-Object { $_ -match '^EVIDENCE_ZIP:' } | Select-Object -Last 1
        if ($opsEvLine) { $opsEvidence = $opsEvLine -replace '^EVIDENCE_ZIP:\s*', '' }

        if ($opsStatus -eq "N/A") { $opsStatus = if ($opsExit -eq 0) { "PASS" } else { "FAIL" } }

        $opsLogItem = Get-LatestFile "C:\MES\ops\ops_daily_*.log"
        if ($opsLogItem) { $opsLog = $opsLogItem.FullName }
        $rehearsalLog = $opsLog

        if ($opsExit -ne 0) {
            Write-Err "ops-daily-check 실패(exit $opsExit)"
            $exitCode = 1
            throw "ops_failed"
        }
    }

    # 서비스 설치/기동 검증
    if ($DoServiceInstall) {
        Write-Info "NSSM 서비스 설치/기동"
        & powershell -ExecutionPolicy Bypass -File $svcInstall -AppHome $deployRoot -ServiceName $ServiceName
        $svcExit = $LASTEXITCODE
        if ($svcExit -ne 0) {
            Write-Err "서비스 설치/기동 실패(exit $svcExit)"
            $exitCode = 1
            throw "svc_failed"
        }

        try {
            $svc = Get-Service -Name $ServiceName -ErrorAction Stop
            $serviceStatus = $svc.Status.ToString()
        } catch {
            $serviceStatus = "UNKNOWN"
        }

        $baseUrl = "http://localhost:8080/actuator/health"
        $maxAttempts = 60
        $ok = $false
        for ($i=1; $i -le $maxAttempts; $i++) {
            try {
                $resp = Invoke-RestMethod -Uri $baseUrl -TimeoutSec 5
                if ($resp.status -eq "UP") { $ok = $true; break }
            } catch {}
            Start-Sleep -Seconds 2
        }
        $health = if ($ok) { "UP" } else { "FAIL" }
        if (-not $ok) {
            Write-Err "health 확인 실패"
            $exitCode = 1
            throw "health_failed"
        }
    }

    # 증빙 ZIP 생성
    if ($DoEvidenceZip) {
        $evDir = "C:\MES\evidence"
        New-Item -ItemType Directory -Force -Path $evDir | Out-Null
        $stamp = Get-Date -Format "yyyyMMdd_HHmm"
        $rehDir = Join-Path $evDir ("deploy_rehearsal_$stamp")
        New-Item -ItemType Directory -Force -Path $rehDir | Out-Null

        $hashPath = Join-Path $rehDir "deploy_zip_sha256.txt"
        $hash = Get-FileHash -Algorithm SHA256 -Path $ZipPath
        "$($hash.Hash)  $ZipPath" | Set-Content -Encoding UTF8 $hashPath

        $opsLogItem = Get-LatestFile "C:\MES\ops\ops_daily_*.log"
        if ($opsLogItem) { Copy-Item -LiteralPath $opsLogItem.FullName -Destination $rehDir }
        if ($opsEvidence -and $opsEvidence -ne "N/A" -and (Test-Path -LiteralPath $opsEvidence)) {
            Copy-Item -LiteralPath $opsEvidence -Destination $rehDir
        }

        $svcOut = "C:\MES\logs\mes-web-service.out.log"
        $svcErr = "C:\MES\logs\mes-web-service.err.log"
        if (Test-Path $svcOut) { Copy-Item -LiteralPath $svcOut -Destination $rehDir }
        if (Test-Path $svcErr) { Copy-Item -LiteralPath $svcErr -Destination $rehDir }

        $meta = [ordered]@{
            timestamp = (Get-Date).ToString("o")
            deploy_zip = $ZipPath
            deploy_dir = $deployRoot
            ops_status = $opsStatus
            ops_exitcode = $opsExit
            ops_log = $opsLog
            ops_evidence_zip = $opsEvidence
            service_name = $ServiceName
            service_status = $serviceStatus
            health = $health
        }
        $meta | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $rehDir "deploy_rehearsal_summary.json")

        $rehearsalZip = Join-Path $evDir ("deploy_rehearsal_$stamp.zip")
        if (Test-Path $rehearsalZip) { Remove-Item -LiteralPath $rehearsalZip -Force }
        Compress-Archive -Path "$rehDir\*" -DestinationPath $rehearsalZip
    }

    if ($opsStatus -eq "PASS") {
        $rehearsalStatus = "PASS"
    }
    $exitCode = if ($rehearsalStatus -eq "PASS") { 0 } else { 1 }
} catch {
    if ($exitCode -eq 0) { $exitCode = 1 }
} finally {
    if ($opsEvidence -and $opsEvidence -ne "N/A") { $rehearsalZip = $opsEvidence }
    Write-Host "DEPLOY_ZIP: $ZipPath"
    Write-Host "DEPLOY_DIR: $deployRoot"
    Write-Host "OPS_STATUS: $opsStatus"
    Write-Host "OPS_EXITCODE: $opsExit"
    Write-Host "OPS_LOG: $opsLog"
    Write-Host "OPS_EVIDENCE_ZIP: $opsEvidence"
    Write-Host "SERVICE_STATUS: $serviceStatus"
    Write-Host "HEALTH: $health"
    Write-Host "REHEARSAL_STATUS: $rehearsalStatus"
    Write-Host "REHEARSAL_EVIDENCE_ZIP: $rehearsalZip"
    Write-Host "REHEARSAL_LOG: $rehearsalLog"
    Write-Host "EXITCODE: $exitCode"
    exit $exitCode
}
