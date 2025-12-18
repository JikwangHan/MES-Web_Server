# DR Lite 검증 스크립트 (Windows PowerShell)
# 목적: 백업 1회 + 복원 리허설 1회를 연속 실행하여 DR Lite를 빠르게 검증합니다.
# 주의: 민감정보(비밀번호, 키, 전체 payload)는 콘솔에 출력하지 않습니다.

param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupScript = Join-Path $scriptRoot "backup-all-tenants.ps1"
$restoreScript = Join-Path $scriptRoot "restore-rehearsal.ps1"
$container = if ($env:MES_DB_CONTAINER) { $env:MES_DB_CONTAINER } else { "mes-mariadb" }

function Write-Info {
    param([string]$msg)
    Write-Host "[INFO] $msg"
}

function Write-Err {
    param([string]$msg)
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

Write-Info "DR Lite 검증 시작"

if (-not (Test-Path $backupScript)) {
    Write-Err "백업 스크립트를 찾을 수 없습니다: $backupScript"
    exit 1
}
if (-not (Test-Path $restoreScript)) {
    Write-Err "복원 스크립트를 찾을 수 없습니다: $restoreScript"
    exit 1
}

# Docker 데몬 사전 확인
try {
    $dockerInfo = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw $dockerInfo }
} catch {
    $firstLine = $_.ToString().Split("`n")[0]
    Write-Err "Docker Desktop이 실행 중인지 확인하세요. 'Engine running' 상태여야 합니다."
    Write-Err "docker info 오류 요약: $firstLine"
    exit 1
}

# Docker 컨테이너 확인
$containerInfo = & docker ps -a --filter "name=$container" --format "{{.Names}}|{{.Status}}"
if (-not $containerInfo) {
    Write-Err "Docker 컨테이너 '$container'가 없습니다."
    Write-Info "아래 예시 명령으로 컨테이너를 생성한 뒤 다시 실행하세요."
    Write-Info "(비밀번호는 실제 값으로 바꿔 입력하세요)"
    Write-Host "docker rm -f $container 2>`$null"
    Write-Host "New-Item -ItemType Directory -Force -Path \"C:\\MES\\data\\mariadb\" | Out-Null"
    Write-Host "docker run -d --name $container `"
    Write-Host "  -e MARIADB_ROOT_PASSWORD=\"<ROOT_PASSWORD>\" `"
    Write-Host "  -p 3306:3306 `"
    Write-Host "  -v \"C:\\MES\\data\\mariadb:/var/lib/mysql\" `"
    Write-Host "  mariadb:11"
    exit 1
}

if ($containerInfo -notmatch "Up") {
    Write-Info "컨테이너가 중지 상태라서 시작합니다: $container"
    & docker start $container | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "컨테이너 시작에 실패했습니다: $container"
        exit 1
    }
}

# 1) 백업 1회
Write-Info "백업 스크립트 실행"
& $backupScript
if ($LASTEXITCODE -ne 0) {
    Write-Err "백업 스크립트 실패(exit $LASTEXITCODE)"
    exit 1
}

# 2) 최신 덤프 선택(tenant_a)
$dump = Get-ChildItem "C:\MES\backup\tenant_a\mes_tenant_a_*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $dump) {
    Write-Err "tenant_a 덤프 파일을 찾을 수 없습니다."
    exit 1
}

# 3) 복원 리허설 1회
Write-Info "복원 리허설 실행"
& $restoreScript -Tenant tenant_a -DumpPath $dump.FullName -ConfirmToken "RESTORE"
if ($LASTEXITCODE -ne 0) {
    Write-Err "복원 리허설 실패(exit $LASTEXITCODE)"
    exit 1
}

Write-Info "DR Lite 검증 완료"
exit 0
