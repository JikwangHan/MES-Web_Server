# Weekly ops report script (Windows PowerShell)
# Purpose: summarize latest ops, perf, and backup health logs into one report.
# Note: no secrets are printed.

param(
    [string]$OpsDir = "C:\MES\ops",
    [string]$PerfDir = "C:\MES\perf",
    [string]$EvidenceDir = "C:\MES\evidence",
    [string]$ReportDir = "C:\MES\ops",
    [int]$TailLines = 80
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Pick-Latest { param([string]$pattern) Get-ChildItem $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$reportPath = Join-Path $ReportDir ("weekly_ops_report_{0}.md" -f $stamp)

$opsLog = Pick-Latest (Join-Path $OpsDir "ops_daily_*.log")
$backupLog = Pick-Latest (Join-Path $OpsDir "backup_health_*.log")
$perfCsv = Pick-Latest (Join-Path $PerfDir "perf_baseline_*.csv")
$perfGate = Pick-Latest (Join-Path $PerfDir "perf_gate_*.json")
$evidence = Pick-Latest (Join-Path $EvidenceDir "evidence_*.zip")

$content = @()
$content += "# Weekly Ops Report"
$content += ""
$content += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$content += ""
$content += "## Latest Evidence"
$content += "- OPS_LOG: $($opsLog.FullName)"
$content += "- BACKUP_HEALTH_LOG: $($backupLog.FullName)"
$content += "- PERF_CSV: $($perfCsv.FullName)"
$content += "- PERF_GATE_JSON: $($perfGate.FullName)"
$content += "- EVIDENCE_ZIP: $($evidence.FullName)"
$content += ""
$content += "## OPS Log Tail"
if ($opsLog) {
    $content += "```"
    $content += Get-Content $opsLog.FullName -Tail $TailLines
    $content += "```"
} else {
    $content += "N/A"
}
$content += ""
$content += "## Backup Health Tail"
if ($backupLog) {
    $content += "```"
    $content += Get-Content $backupLog.FullName -Tail $TailLines
    $content += "```"
} else {
    $content += "N/A"
}

$content | Set-Content -Encoding UTF8 $reportPath

Write-Host "WEEKLY_REPORT: $reportPath"
exit 0
