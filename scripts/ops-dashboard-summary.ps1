# Ops dashboard summary generator (Windows PowerShell)
# Purpose: create a short summary file for daily/weekly ops status.
# Note: no secrets are printed.

param(
    [string]$OpsDir = "C:\MES\ops",
    [string]$OutDir = "C:\MES\ops",
    [int]$TailLines = 40
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Pick-Latest { param([string]$pattern) Get-ChildItem $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$outPath = Join-Path $OutDir ("ops_dashboard_{0}.md" -f $stamp)

$opsLog = Pick-Latest (Join-Path $OpsDir "ops_daily_*.log")
$backupLog = Pick-Latest (Join-Path $OpsDir "backup_health_*.log")
$weeklyReport = Pick-Latest (Join-Path $OpsDir "weekly_ops_report_*.md")

$content = @()
$content += "# Ops Dashboard Summary"
$content += ""
$content += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$content += ""
$content += "## Latest Files"
$content += "- OPS_LOG: $($opsLog.FullName)"
$content += "- BACKUP_HEALTH_LOG: $($backupLog.FullName)"
$content += "- WEEKLY_REPORT: $($weeklyReport.FullName)"
$content += ""
$content += "## OPS Log Tail"
if ($opsLog) {
    $content += "```"
    $content += Get-Content $opsLog.FullName -Tail $TailLines
    $content += "```"
} else {
    $content += "N/A"
}

$content | Set-Content -Encoding UTF8 $outPath

Write-Host "DASHBOARD_SUMMARY: $outPath"
exit 0
