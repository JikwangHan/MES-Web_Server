# Disk and log health check script (Windows PowerShell)
# Purpose: verify disk free space and log folder size.
# Note: no secrets are printed.

param(
    [string]$LogDir = "C:\MES\logs",
    [int]$MinFreeGb = 10,
    [int]$MaxLogGb = 5
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

$drive = (Get-Item $LogDir).PSDrive
$freeGb = [math]::Round($drive.Free/1GB, 2)

$logSize = 0
if (Test-Path $LogDir) {
    $logSize = (Get-ChildItem -Path $LogDir -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
}
$logGb = [math]::Round($logSize/1GB, 2)

$status = "PASS"
if ($freeGb -lt $MinFreeGb) {
    Write-Err "디스크 여유 공간 부족: ${freeGb}GB (최소 ${MinFreeGb}GB 필요)"
    $status = "FAIL"
} else {
    Write-Info "디스크 여유 공간: ${freeGb}GB"
}

if ($logGb -gt $MaxLogGb) {
    Write-Warn "로그 폴더 용량 초과: ${logGb}GB (권장 ${MaxLogGb}GB 이하)"
    $status = "FAIL"
} else {
    Write-Info "로그 폴더 용량: ${logGb}GB"
}

Write-Host "DISK_LOG_STATUS: $status"
Write-Host "FREE_GB: $freeGb"
Write-Host "LOG_GB: $logGb"

exit $(if ($status -eq "PASS") { 0 } else { 1 })
