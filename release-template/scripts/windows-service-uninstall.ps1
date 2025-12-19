# Windows 서비스 삭제 스크립트 (NSSM)
# 목적: MES 웹 서버 서비스를 중지하고 삭제합니다.
# 주의: 데이터/백업/증빙 파일은 삭제하지 않습니다.

param(
    [string]$ServiceName = "MES-Web"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# 관리자 권한 체크
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "관리자 권한으로 실행해야 합니다. PowerShell을 관리자 권한으로 다시 실행하세요."
    exit 2
}

# NSSM 확인
$nssm = (Get-Command nssm.exe -ErrorAction SilentlyContinue)?.Source
if (-not $nssm) {
    Write-Err "nssm.exe를 찾지 못했습니다. NSSM 설치 후 다시 실행하세요."
    exit 2
}

Write-Info "서비스 중지 시도: $ServiceName"
try { & $nssm stop $ServiceName | Out-Null } catch {}

Write-Info "서비스 삭제: $ServiceName"
& $nssm remove $ServiceName confirm

Write-Host "[완료] 서비스 삭제 완료"
Write-Host "[안내] 로그/데이터/증빙 파일은 삭제하지 않았습니다."
Write-Host "[안내] 필요 시 수동으로 정리하세요."
