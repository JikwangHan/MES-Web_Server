# 성능 퇴행 자동 판정 게이트 (PowerShell)
# 용도: perf-baseline CSV와 임계치(JSON)를 비교해 PASS/FAIL을 판정하고,
#       요약은 콘솔에 출력하며 JSON 리포트를 반드시 생성합니다.
#
# 실행 예시
#   powershell -File .\scripts\perf-gate.ps1 -CsvPath "C:\MES\perf\perf_baseline_20251217_1200.csv"
#   powershell -File .\scripts\perf-gate.ps1 -CsvPath "C:\MES\perf\perf_baseline_20251217_1200.csv" -ThresholdPath ".\docs\perf-thresholds.v0.1.json"
#   powershell -File .\scripts\perf-gate.ps1 -CsvPath "C:\MES\perf\perf_baseline_20251217_1200.csv" -OutJsonPath "C:\MES\perf\perf_gate_20251217_1200.json"

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    [string]$ThresholdPath = ".\docs\perf-thresholds.v0.1.json",
    [string]$OutJsonPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Write-Host "[DEBUG] CsvPath 전달 값 '$CsvPath'"
Write-Host "[DEBUG] ThresholdPath 전달 값 '$ThresholdPath'"

if ([string]::IsNullOrWhiteSpace($CsvPath) -or -not (Test-Path -LiteralPath $CsvPath)) {
    Write-Host "[ERROR] CSV 파일이 없습니다: $CsvPath" -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrWhiteSpace($ThresholdPath) -or -not (Test-Path -LiteralPath $ThresholdPath)) {
    Write-Host "[ERROR] Threshold 파일이 없습니다: $ThresholdPath" -ForegroundColor Red
    exit 1
}

# 결과 저장 경로
$perfDir = "C:\MES\perf"
New-Item -ItemType Directory -Force -Path $perfDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmm"
$reportPath = if ($OutJsonPath) { $OutJsonPath } else { Join-Path $perfDir ("perf_gate_{0}.json" -f $ts) }

# 임계치 로드
$thresholds = Get-Content -LiteralPath $ThresholdPath -Raw | ConvertFrom-Json
$regPct = [double]$thresholds.regression_pct
$endpointThresholds = $thresholds.endpoints

# CSV 로드
$rows = Import-Csv -Path $CsvPath

function Get-PercentileIndex {
    param(
        [int]$count,
        [double]$percentile
    )
    if ($count -le 0) { return -1 }
    $idx = [math]::Ceiling($count * $percentile) - 1
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $count) { $idx = $count - 1 }
    return [int]$idx
}

function Get-Stats {
    param([double[]]$values)
    $sorted = $values | Sort-Object
    $count = $sorted.Count
    if ($count -eq 0) { return @{ p50 = 0; p95 = 0; p99 = 0; avg = 0; max = 0 } }
    $p50 = $sorted[(Get-PercentileIndex -count $count -percentile 0.5)]
    $p95 = $sorted[(Get-PercentileIndex -count $count -percentile 0.95)]
    $p99 = $sorted[(Get-PercentileIndex -count $count -percentile 0.99)]
    $avg = [math]::Round(($sorted | Measure-Object -Average).Average, 2)
    $max = ($sorted | Measure-Object -Maximum).Maximum
    return @{ p50 = $p50; p95 = $p95; p99 = $p99; avg = $avg; max = $max }
}

$report = @{
    csvPath        = $CsvPath
    thresholdPath  = $ThresholdPath
    generatedAt    = (Get-Date).ToString("o")
    regression_pct = $regPct
    endpoints      = @{}
    overall        = "PASS"
}

foreach ($endpoint in $endpointThresholds.PSObject.Properties.Name) {
    $ths = $endpointThresholds.$endpoint
    $data = $rows | Where-Object { $_.endpoint -eq $endpoint }
    if (-not $data) {
        $report.endpoints[$endpoint] = @{
            status = "FAIL"
            reason = "CSV에 해당 엔드포인트가 없습니다."
        }
        $report.overall = "FAIL"
        continue
    }

    $durations = $data | ForEach-Object { [double]$_.duration_ms }
    $stats = Get-Stats $durations

    # 허용 한계 = 임계치 * (1 + regression_pct/100)
    $p95Limit = $ths.p95_max_ms * (1 + $regPct / 100)
    $p99Limit = $ths.p99_max_ms * (1 + $regPct / 100)
    $avgLimit = $ths.avg_max_ms * (1 + $regPct / 100)

    $failReasons = @()
    if ($stats.p95 -gt $p95Limit) { $failReasons += "p95>${p95Limit}ms(측정 ${($stats.p95)}ms)" }
    if ($stats.p99 -gt $p99Limit) { $failReasons += "p99>${p99Limit}ms(측정 ${($stats.p99)}ms)" }
    if ($stats.avg -gt $avgLimit) { $failReasons += "avg>${avgLimit}ms(측정 ${($stats.avg)}ms)" }

    if ($failReasons.Count -eq 0) {
        $status = "PASS"
    } else {
        $status = "FAIL"
        $report.overall = "FAIL"
    }

    $report.endpoints[$endpoint] = @{
        status         = $status
        stats          = $stats
        threshold      = $ths
        regression_pct = $regPct
        failReasons    = $failReasons
    }
}

# JSON 저장(항상 수행)
try {
    $json = $report | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $reportPath -Value $json -Encoding UTF8
    if (-not (Test-Path -LiteralPath $reportPath)) { throw "file not found" }
    if ((Get-Item -LiteralPath $reportPath).Length -le 10) { throw "file too small" }
} catch {
    Write-Error "JSON 저장 실패: $reportPath"
    exit 2
}

# 콘솔 요약
Write-Host "`n[성능 퇴행 판정]" -ForegroundColor Cyan
Write-Host "Overall: $($report.overall)"
foreach ($ep in $report.endpoints.Keys) {
    $epData = $report.endpoints[$ep]
    $line = "{0,-25} {1} p95={2}ms p99={3}ms avg={4}ms" -f $ep, $epData.status, $epData.stats.p95, $epData.stats.p99, $epData.stats.avg
    if ($epData.status -eq "FAIL") {
        Write-Host $line -ForegroundColor Red
        Write-Host "  이유: $($epData.failReasons -join '; ')" -ForegroundColor Red
    } else {
        Write-Host $line -ForegroundColor Green
    }
}
Write-Host "`n[리포트] $reportPath"
Write-Host "OUTPUT_JSON=$reportPath"

if ($report.overall -eq "FAIL") { exit 1 } else { exit 0 }
