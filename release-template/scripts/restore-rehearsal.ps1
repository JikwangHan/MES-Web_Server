# 복원 리허설 스크립트 (Windows PowerShell)
# 목적: 지정한 테넌트 덤프 파일을 테스트 복원하고, 기본 쿼리(SELECT 1, 테이블 존재)를 확인한다.
#       ConfirmToken="RESTORE" 입력이 없으면 실행하지 않는다.
#
# 사용 예시:
#   powershell -File .\scripts\restore-rehearsal.ps1 -Tenant tenant_a -DumpPath "C:\MES\backup\tenant_a\mes_tenant_a_YYYYMMDD_HHMMSS.sql" -ConfirmToken "RESTORE"
#
# 환경변수(선택):
#   MES_DB_CONTAINER          : Docker 컨테이너명 (기본 mes-mariadb)
#   MES_DB_RESTORE_USER       : 복원/검증 실행 계정 (기본 root)
#   MES_DB_RESTORE_PASSWORD   : 복원/검증 비밀번호 (기본 root1234!)
#
# 주의:
# - 비밀번호는 화면/로그에 출력하지 않는다.
# - ConfirmToken 불일치 시 즉시 중단한다.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("tenant_a","tenant_b")]
    [string]$Tenant,
    [Parameter(Mandatory = $true)]
    [string]$DumpPath,
    [Parameter(Mandatory = $true)]
    [string]$ConfirmToken
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if ($ConfirmToken -ne "RESTORE") {
    Write-Host "[ERROR] ConfirmToken이 맞지 않습니다. (RESTORE 필요)" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $DumpPath)) {
    Write-Host "[ERROR] 덤프 파일이 없습니다: $DumpPath" -ForegroundColor Red
    exit 1
}

$container = if ($env:MES_DB_CONTAINER) { $env:MES_DB_CONTAINER } else { "mes-mariadb" }
$dbUser = if ($env:MES_DB_RESTORE_USER) { $env:MES_DB_RESTORE_USER } else { "root" }
$dbPass = if ($env:MES_DB_RESTORE_PASSWORD) { $env:MES_DB_RESTORE_PASSWORD } else { "root1234!" }

$dbNameMap = @{
    "tenant_a" = "mes_tenant_a"
    "tenant_b" = "mes_tenant_b"
}
$dbName = $dbNameMap[$Tenant]
if (-not $dbName) {
    Write-Host "[ERROR] DB 매핑을 찾을 수 없습니다: $Tenant" -ForegroundColor Red
    exit 1
}

$backupRoot = "C:\MES\backup"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$logDate = Get-Date -Format "yyyyMMdd"
$logPath = Join-Path $backupRoot ("restore_rehearsal_{0}.log" -f $logDate)

function Write-Log {
    param([string]$msg, [string]$level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $level, $msg
    $line | Out-File -FilePath $logPath -Encoding UTF8 -Append
    Write-Host $line
}

# 컨테이너 확인
$containerInfo = docker ps --filter "name=$container" --format "{{.Names}}"
if (-not $containerInfo) {
    Write-Log "Docker 컨테이너가 없습니다. 이름을 확인하세요: $container" "ERROR"
    exit 1
}

try {
    Write-Log "복원 리허설 시작: tenant=$Tenant, dump=$DumpPath"

    # 복원 실행: 컨테이너 환경변수로 비밀번호 전달
    $restoreArgs = @(
        "exec", "-i",
        "-e", "MARIADB_PWD=$dbPass",
        "-e", "MYSQL_PWD=$dbPass",
        $container,
        "mariadb", "-u", $dbUser, $dbName
    )
    Get-Content -LiteralPath $DumpPath | & docker @restoreArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "복원 명령이 실패했습니다.(exit $LASTEXITCODE)" }
    Write-Log "복원 실행 완료: $Tenant"

    # 검증 1: SELECT 1
    $check1Args = @(
        "exec", "-i",
        "-e", "MARIADB_PWD=$dbPass",
        "-e", "MYSQL_PWD=$dbPass",
        $container,
        "mariadb", "-u", $dbUser, "-D", $dbName,
        "-e", "SELECT 1 AS ok;"
    )
    $check1 = & docker @check1Args
    if ($LASTEXITCODE -ne 0) { throw "SELECT 1 검증 실패(exit $LASTEXITCODE)" }
    Write-Log "SELECT 1 결과: $check1"

    # 검증 2: raw_ingest_log 테이블 존재 여부
    $check2Args = @(
        "exec", "-i",
        "-e", "MARIADB_PWD=$dbPass",
        "-e", "MYSQL_PWD=$dbPass",
        $container,
        "mariadb", "-u", $dbUser, "-D", $dbName,
        "-e", "SHOW TABLES LIKE 'raw_ingest_log';"
    )
    $check2 = & docker @check2Args
    if ($LASTEXITCODE -ne 0) { throw "테이블 확인 실패(exit $LASTEXITCODE)" }
    Write-Log "테이블 확인: $check2"

    Write-Log "복원 리허설 완료"
    exit 0
} catch {
    Write-Log "복원 리허설 실패: $_" "ERROR"
    exit 1
}
