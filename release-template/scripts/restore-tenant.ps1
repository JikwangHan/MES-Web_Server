# 테넌트 복원 스크립트 (Windows PowerShell)
# 사용 방법:
#   .\restore-tenant.ps1 -Tenant tenant_a -DumpPath "C:\MES\backup\mes_tenant_a_xxx.sql"
# 주의: 대상 DB(tenant_a/b)를 덮어쓰므로 실행 전 백업 필수

param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("tenant_a","tenant_b")]
  [string]$Tenant,

  [Parameter(Mandatory=$true)]
  [string]$DumpPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DumpPath)) {
  Write-Error "덤프 파일이 없습니다: $DumpPath"
  exit 1
}

Write-Host "[INFO] restore tenant=$Tenant from $DumpPath"
docker exec -i mes-mariadb sh -lc "mariadb -u root -proot1234! $Tenant" < $DumpPath
Write-Host "[OK] completed"
