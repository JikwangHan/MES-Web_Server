# Backup retention cleanup script (Windows PowerShell)
# Purpose: delete backup files older than retention days.
# Note: no secrets are printed.

param(
    [string]$BaseDir = "C:\MES\backup",
    [int]$RetentionDays = 30,
    [string]$LogDir = "C:\MES\ops"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$logPath = Join-Path $LogDir ("backup_cleanup_{0}.log" -f $stamp)
Start-Transcript -Path $logPath -Append | Out-Null

$cutoff = (Get-Date).AddDays(-$RetentionDays)
$deleted = 0

Write-Info "Backup cleanup start (retention ${RetentionDays} days)"

$targets = @("tenant_a","tenant_b")
foreach ($t in $targets) {
    $dir = Join-Path $BaseDir $t
    if (-not (Test-Path $dir)) {
        Write-Warn "Missing backup directory: $dir"
        continue
    }
    $files = Get-ChildItem -Path $dir -Filter "mes_${t}_*.sql" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
    foreach ($f in $files) {
        Remove-Item -Force -LiteralPath $f.FullName
        $deleted++
        Write-Info "Deleted: $($f.FullName)"
    }
}

Write-Host "BACKUP_CLEANUP_DELETED: $deleted"
Write-Host "BACKUP_CLEANUP_LOG: $logPath"

Stop-Transcript | Out-Null
exit 0
