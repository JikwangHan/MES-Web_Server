# tenant_b 백업 스크립트 (Windows PowerShell)
# 사용 방법:
#   .\backup-tenant-b.ps1
# 결과 파일: ../backup/mes_tenant_b_YYYYMMDD_HHMMSS.sql

$ErrorActionPreference = 'Stop'

$backupDir = Join-Path $PSScriptRoot "..\\backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$file = Join-Path $backupDir ("mes_tenant_b_{0}.sql" -f $ts)

Write-Host "[INFO] backup -> $file"
docker exec -i mes-mariadb sh -lc "mariadb-dump -u root -proot1234! mes_tenant_b" | Out-File -Encoding utf8 $file
Write-Host "[OK] completed"
