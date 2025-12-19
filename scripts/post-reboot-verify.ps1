# 재부팅 후 서비스 자동 기동 검증 스크립트 (Windows PowerShell)
# 목적: 재부팅 직후 서비스/포트/헬스 상태를 한 번에 점검합니다.
# 주의: 민감정보(비밀번호/키)는 출력하지 않습니다.

param(
    [string]$ServiceName = "MES-Web",
    [string]$LogDir = "C:\MES\logs",
    [int]$TailLines = 60,
    [string]$HealthUrl = "http://localhost:8080/actuator/health"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }

Write-Info "재부팅 후 서비스 검증을 시작합니다."

# 1) 서비스 상태 확인
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Warn "서비스를 찾지 못했습니다: $ServiceName"
} else {
    Write-Info "서비스 상태: $($svc.Status) / StartType: $($svc.StartType)"
}

# 2) 8080 포트 점유 확인
$portLine = (netstat -ano | findstr ":8080" | Select-Object -First 1)
if ($portLine) {
    Write-Info "8080 포트 점유 확인: $portLine"
} else {
    Write-Warn "8080 포트 LISTEN을 찾지 못했습니다."
}

# 3) 헬스 체크
$health = "N/A"
try {
    $resp = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 5
    $health = $resp.status
    Write-Info "헬스 체크 결과: $health"
} catch {
    Write-Warn "헬스 체크 실패: $($_.Exception.Message)"
}

# 4) 서비스 로그 Tail 출력(있을 때만)
$outLog = Join-Path $LogDir "mes-web-service.out.log"
$errLog = Join-Path $LogDir "mes-web-service.err.log"

if (Test-Path $outLog) {
    Write-Info "표준 출력 로그(Tail $TailLines): $outLog"
    Get-Content $outLog -Tail $TailLines
} else {
    Write-Warn "표준 출력 로그를 찾지 못했습니다: $outLog"
}

if (Test-Path $errLog) {
    Write-Info "표준 오류 로그(Tail $TailLines): $errLog"
    Get-Content $errLog -Tail $TailLines
} else {
    Write-Warn "표준 오류 로그를 찾지 못했습니다: $errLog"
}

# 5) 요약 출력(고정 포맷)
Write-Host "SERVICE_STATUS: $($svc.Status)"
Write-Host "PORT_8080: $([string]::IsNullOrWhiteSpace($portLine) ? 'N/A' : 'LISTEN')"
Write-Host "HEALTH: $health"
Write-Host "OUT_LOG_TAIL: $outLog"
Write-Host "ERR_LOG_TAIL: $errLog"
