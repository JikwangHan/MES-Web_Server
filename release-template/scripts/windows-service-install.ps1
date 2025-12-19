# Windows 서비스 설치 스크립트 (NSSM)
# 목적: MES 웹 서버를 Windows 서비스로 설치하고 자동 기동/재시작을 구성합니다.
# 주의: 민감정보(비밀번호/키)는 절대 출력하지 않습니다.

param(
    [string]$ServiceName = "MES-Web",
    [string]$DisplayName = "MES Web Service",
    [string]$AppHome = "C:\MES\app\mes-web",
    [string]$LogsDir = "C:\MES\logs"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# 관리자 권한 체크
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "관리자 권한으로 실행해야 합니다. PowerShell을 관리자 권한으로 다시 실행하세요."
    exit 2
}

# NSSM 확인 및 설치 시도
$nssmCmd = Get-Command nssm.exe -ErrorAction SilentlyContinue
$nssm = if ($nssmCmd) { $nssmCmd.Source } else { $null }
if (-not $nssm) {
    Write-Warn "nssm.exe를 찾지 못했습니다. winget으로 설치를 시도합니다."
    winget install -e --id NSSM.NSSM
    $nssmCmd = Get-Command nssm.exe -ErrorAction SilentlyContinue
    $nssm = if ($nssmCmd) { $nssmCmd.Source } else { $null }
}
if (-not $nssm) {
    $nssmFallback = "C:\Program Files\NSSM\nssm.exe"
    if (Test-Path $nssmFallback) {
        $nssm = $nssmFallback
        Write-Info "NSSM 경로를 직접 지정했습니다: $nssm"
    } else {
        Write-Err "NSSM 설치가 필요합니다. 새 PowerShell을 열거나 수동 설치 후 다시 실행하세요."
        Write-Err "설치 직후 PATH가 반영되지 않았을 수 있습니다."
        exit 2
    }
}
if (-not $nssm) {
    Write-Err "NSSM 경로 확인 실패. 수동 설치 후 다시 실행하세요."
    exit 2
}

# 실행 스크립트 결정
$runProd = Join-Path $AppHome "bin\run-prod.ps1"
$runLocal = Join-Path $AppHome "bin\run-local.ps1"
$runScript = if (Test-Path $runProd) { $runProd } elseif (Test-Path $runLocal) { $runLocal } else { $null }
if (-not $runScript) {
    Write-Err "run-prod.ps1 또는 run-local.ps1를 찾지 못했습니다. AppHome 경로를 확인하세요."
    exit 2
}

# 로그 경로 준비
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
$stdoutLog = Join-Path $LogsDir "mes-web-service.out.log"
$stderrLog = Join-Path $LogsDir "mes-web-service.err.log"

# 서비스 설치
Write-Info "서비스 설치: $ServiceName"
& $nssm install $ServiceName "powershell.exe"
& $nssm set $ServiceName DisplayName $DisplayName
& $nssm set $ServiceName AppDirectory $AppHome
& $nssm set $ServiceName AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$runScript`""

# 로그 리다이렉션 + 롤링
& $nssm set $ServiceName AppStdout $stdoutLog
& $nssm set $ServiceName AppStderr $stderrLog
& $nssm set $ServiceName AppRotateFiles 1
& $nssm set $ServiceName AppRotateOnline 1
& $nssm set $ServiceName AppRotateSeconds 86400
& $nssm set $ServiceName AppRotateBytes 10485760

# 자동 재시작 정책
& $nssm set $ServiceName Start SERVICE_AUTO_START
& $nssm set $ServiceName AppExit Default Restart
& $nssm set $ServiceName AppRestartDelay 5000

# 서비스 시작
Write-Info "서비스 시작: $ServiceName"
& $nssm start $ServiceName

# 상태 확인 + health 폴링
Start-Sleep -Seconds 5
try {
    $svc = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Info "서비스 상태: $($svc.Status)"
} catch {
    Write-Err "서비스 상태를 확인할 수 없습니다."
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

if ($ok) {
    Write-Host "SERVICE_STATUS=RUNNING"
    Write-Host "HEALTH=UP"
    exit 0
}

Write-Err "health 확인 실패. 서비스 로그를 확인하세요."
if (Test-Path $stdoutLog) { Get-Content -Path $stdoutLog -Tail 60 }
if (Test-Path $stderrLog) { Get-Content -Path $stderrLog -Tail 60 }
exit 1
