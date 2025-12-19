# Daily backup health check script (Windows PowerShell)
# Purpose: verify latest tenant backup files exist and are non-empty.
# Note: no secrets are printed.

param(
    [string]$BaseDir = "C:\MES\backup",
    [string]$LogDir = "C:\MES\ops",
    [int]$MaxAgeHours = 26
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$logPath = Join-Path $LogDir ("backup_health_{0}.log" -f $stamp)
Start-Transcript -Path $logPath -Append | Out-Null

$now = Get-Date
$tenants = @("tenant_a","tenant_b")
$fail = $false

Write-Info "Backup health check start"
foreach ($t in $tenants) {
    $dir = Join-Path $BaseDir $t
    if (-not (Test-Path $dir)) {
        Write-Err "Missing backup directory: $dir"
        $fail = $true
        continue
    }
    $latest = Get-ChildItem -Path $dir -Filter "mes_${t}_*.sql" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Err "No backup file found for $t"
        $fail = $true
        continue
    }
    $age = ($now - $latest.LastWriteTime).TotalHours
    if ($latest.Length -le 10) {
        Write-Err "Backup file too small: $($latest.FullName)"
        $fail = $true
    } elseif ($age -gt $MaxAgeHours) {
        Write-Warn "Backup file is older than ${MaxAgeHours}h: $($latest.FullName)"
        $fail = $true
    } else {
        Write-Info "OK: $t => $($latest.FullName) (age ${age}h)"
    }
}

Write-Host "BACKUP_HEALTH_STATUS: $([string]::Join('', $(if ($fail) { 'FAIL' } else { 'PASS' })))"
Write-Host "BACKUP_HEALTH_LOG: $logPath"

Stop-Transcript | Out-Null
exit $(if ($fail) { 1 } else { 0 })
