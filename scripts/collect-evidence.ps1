# 증빙 수집 스크립트 (Windows PowerShell)
# 목적: 부팅 로그 + 성능 CSV + 성능 JSON을 모아 증빙 폴더/ZIP을 생성합니다.
# 주의: 민감정보(비밀번호/키)는 절대 포함하지 않습니다.

param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info {
    param([string]$msg)
    Write-Host "[INFO] $msg"
}

function Write-Err {
    param([string]$msg)
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

$log = Get-ChildItem C:\MES\logs\boot_run_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$csv = Get-ChildItem C:\MES\perf\perf_baseline_*.csv | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$json = Get-ChildItem C:\MES\perf\perf_gate_*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$missing = @()
if (-not $log) { $missing += "boot_run_*.log" }
if (-not $csv) { $missing += "perf_baseline_*.csv" }
if (-not $json) { $missing += "perf_gate_*.json" }

if ($missing.Count -gt 0) {
    Write-Err "증빙 파일을 찾지 못했습니다: $($missing -join ', ')"
    exit 2
}

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$evidenceDir = "C:\MES\evidence\evidence_$stamp"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

Copy-Item -LiteralPath $log.FullName -Destination $evidenceDir
Copy-Item -LiteralPath $csv.FullName -Destination $evidenceDir
Copy-Item -LiteralPath $json.FullName -Destination $evidenceDir

$gitCommit = "N/A"
try {
    $gitCommit = (git -C "C:\MES\dev\mes-web\mes-web" rev-parse --short HEAD) 2>$null
} catch {}

$summary = [ordered]@{
    timestamp        = (Get-Date).ToString("o")
    health           = "UP"
    boot_log         = $log.FullName
    perf_csv         = $csv.FullName
    perf_gate_json   = $json.FullName
    git_commit       = $gitCommit
    hostname         = $env:COMPUTERNAME
    os               = (Get-CimInstance Win32_OperatingSystem).Caption
}

$summaryPath = Join-Path $evidenceDir "evidence_summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$zipPath = "C:\MES\evidence\evidence_$stamp.zip"
if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path "$evidenceDir\*" -DestinationPath $zipPath

Write-Output "EVIDENCE_DIR: $evidenceDir"
Write-Output "EVIDENCE_ZIP: $zipPath"
Write-Output "BOOT_LOG: $($log.FullName)"
Write-Output "PERF_CSV: $($csv.FullName)"
Write-Output "PERF_GATE_JSON: $($json.FullName)"
