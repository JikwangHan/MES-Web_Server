# 통합 백업 스크립트 (Windows PowerShell)
# 목적: tenant_a, tenant_b를 순서대로 백업하여 C:\MES\backup에 저장하고
#       로그를 남긴다. 실패하면 exit code 1로 종료해 스케줄러에서 감지 가능하게 한다.
#
# 사용 예시(수동):
#   powershell -File .\scripts\backup-all-tenants.ps1
#
# 환경변수(선택):
#   MES_DB_CONTAINER        : Docker 컨테이너명 (기본 mes-mariadb)
#   MES_DB_USER             : 덤프 실행 계정 (기본 mes)
#   MES_DB_USER_PASSWORD    : 덤프 실행 비밀번호 (기본 mes1234!)
#
# 주의:
# - 비밀번호는 화면/로그에 출력하지 않는다.
# - 덤프 파일이 비어 있으면 실패로 처리한다.

param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$container = if ($env:MES_DB_CONTAINER) { $env:MES_DB_CONTAINER } else { "mes-mariadb" }
$dbUser = if ($env:MES_DB_USER) { $env:MES_DB_USER } else { "mes" }
$dbPass = if ($env:MES_DB_USER_PASSWORD) { $env:MES_DB_USER_PASSWORD } else { "mes1234!" }

$tenants = @("tenant_a", "tenant_b")
$dbNameMap = @{
    "tenant_a" = "mes_tenant_a"
    "tenant_b" = "mes_tenant_b"
}

$backupRoot = "C:\MES\backup"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$logDate = Get-Date -Format "yyyyMMdd"
$logPath = Join-Path $backupRoot ("backup_run_{0}.log" -f $logDate)

function Write-Log {
    param([string]$msg, [string]$level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $level, $msg
    $line | Out-File -FilePath $logPath -Encoding UTF8 -Append
    Write-Host $line
}

# Docker 컨테이너 존재 확인
$containerInfo = docker ps --filter "name=$container" --format "{{.Names}}"
if (-not $containerInfo) {
    Write-Log "Docker 컨테이너가 없습니다. 이름을 확인하세요: $container" "ERROR"
    exit 1
}

foreach ($t in $tenants) {
    try {
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $tenantDir = Join-Path $backupRoot $t
        New-Item -ItemType Directory -Force -Path $tenantDir | Out-Null
        $dumpPath = Join-Path $tenantDir ("mes_{0}_{1}.sql" -f $t, $ts)
        $dbName = $dbNameMap[$t]
        if (-not $dbName) { throw "DB 매핑을 찾을 수 없습니다: $t" }

        Write-Log "백업 시작: $t -> $dumpPath"

        # 안전한 방식: 컨테이너 환경변수로 비밀번호 전달
        $args = @(
            "exec", "-i",
            "-e", "MARIADB_PWD=$dbPass",
            "-e", "MYSQL_PWD=$dbPass",
            $container,
            "mariadb-dump", "-u", $dbUser, $dbName
        )
        & docker @args | Out-File -FilePath $dumpPath -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "mariadb-dump 실패(exit $LASTEXITCODE)" }

        if (-not (Test-Path $dumpPath)) { throw "덤프 파일 생성 실패: $dumpPath" }
        if ((Get-Item $dumpPath).Length -le 0) { throw "덤프 파일이 비어 있습니다: $dumpPath" }

        Write-Log "백업 완료: $t"
    } catch {
        Write-Log "백업 실패: $t, 오류=$_" "ERROR"
        exit 1
    }
}

Write-Log "모든 테넌트 백업 완료"
exit 0
