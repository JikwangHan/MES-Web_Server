# 성능 베이스라인 측정 스크립트 (Windows PowerShell)
# 목적: 주요 엔드포인트의 응답시간(p50/p95/p99/평균/최대)을 CSV로 남기고,
#       콘솔에 요약을 출력합니다. perf-gate(퇴행 판정)에서 이 CSV를 사용합니다.
#
# 사용 예시:
#   powershell -File .\scripts\perf-baseline.ps1
#   powershell -File .\scripts\perf-baseline.ps1 -BaseUrl http://localhost:8080 -Iterations 200
#
# 출력:
#   - CSV: C:\MES\perf\perf_baseline_YYYYMMDD_HHMM.csv
#   - 콘솔 요약: 엔드포인트별 p50/p95/p99/avg/max

param(
    [string]$BaseUrl = "http://localhost:8080",
    [int]$Iterations = 200,
    [int]$Concurrency = 1, # 단일 스레드만 지원(확장 여지용 옵션)
    [string]$Tenant = "tenant_a"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 결과 저장 경로 준비
$perfDir = "C:\MES\perf"
if (-not $perfDir) { $perfDir = "C:\MES\perf" } # 혹시라도 비어있을 때 기본값 보정
New-Item -ItemType Directory -Force -Path $perfDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmm"
$csvPath = Join-Path $perfDir ("perf_baseline_{0}.csv" -f $ts)

function Test-Health {
    param($url)
    try {
        $res = Invoke-RestMethod -Method Get -Uri "$url/actuator/health" -TimeoutSec 5
        return $res.status -eq "UP"
    } catch {
        return $false
    }
}

if (-not (Test-Health -url $BaseUrl)) {
    Write-Host "[ERROR] 서버가 기동되어 있지 않습니다. health 확인 실패: $BaseUrl/actuator/health" -ForegroundColor Red
    exit 1
}

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
    if ($count -eq 0) { return @{p50=0;p95=0;p99=0;avg=0;max=0} }
    $p50 = $sorted[(Get-PercentileIndex -count $count -percentile 0.5)]
    $p95 = $sorted[(Get-PercentileIndex -count $count -percentile 0.95)]
    $p99 = $sorted[(Get-PercentileIndex -count $count -percentile 0.99)]
    $avg = [math]::Round(($sorted | Measure-Object -Average).Average,2)
    $max = ($sorted | Measure-Object -Maximum).Maximum
    return @{p50=$p50;p95=$p95;p99=$p99;avg=$avg;max=$max}
}

function Warmup {
    param($url)
    1..5 | ForEach-Object {
        try { Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 5 | Out-Null } catch {}
    }
}

function Measure-Endpoint {
    param(
        [string]$name,
        [ScriptBlock]$invoker
    )
    Warmup ($BaseUrl + "/actuator/health")
    $rows = @()
    $durations = @()
    for ($i=1; $i -le $Iterations; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $status = 0
        try {
            & $invoker | Out-Null
            $status = 200
        } catch {
            $status = 500
        }
        $sw.Stop()
        $ms = [math]::Round($sw.Elapsed.TotalMilliseconds,2)
        $durations += $ms
        $rows += [PSCustomObject]@{
            timestamp = (Get-Date).ToString("o")
            endpoint  = $name
            iteration = $i
            duration_ms = $ms
            status = $status
        }
    }
    $stats = Get-Stats $durations
    return @{rows=$rows; stats=$stats}
}

Write-Host "[INFO] 측정 시작 - BaseUrl=$BaseUrl Iterations=$Iterations Tenant=$Tenant"
Write-Host "[DEBUG] Iterations 값 확인: $Iterations"

# 호출 정의
$echoInvoker = { Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/echo?msg=perf" -TimeoutSec 10 }
$dbInvoker   = { Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/tenant/dbname" -TimeoutSec 10 }
$ingestBody  = @{ source="perf-script"; eventType="PERF"; payload=@{hello="world"} } | ConvertTo-Json -Depth 5
$ingestInvoker = { Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/ingest/raw" -ContentType "application/json" -Body $ingestBody -TimeoutSec 10 }

# 측정
$allRows = @()
$echoRes = Measure-Endpoint -name "GET /api/echo" -invoker $echoInvoker
$allRows += $echoRes.rows
$dbRes = Measure-Endpoint -name "GET /api/tenant/dbname" -invoker $dbInvoker
$allRows += $dbRes.rows
$ingestRes = Measure-Endpoint -name "POST /api/ingest/raw" -invoker $ingestInvoker
$allRows += $ingestRes.rows

# CSV 저장
# Count가 일부 환경에서 비어 보이는 문제가 있어 Measure-Object로 보강
$rowCount = ($allRows | Measure-Object).Count
Write-Host "[DEBUG] 수집된 행 수: $rowCount"
if (-not $rowCount -or $rowCount -eq 0) {
    Write-Error "측정 데이터가 비어 있습니다. 서버 응답을 확인하세요."
    exit 1
}
$allRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
if (-not (Test-Path $csvPath)) {
    Write-Error "CSV 생성에 실패했습니다: $csvPath"
    exit 1
}

# 요약 출력
Write-Host "`n[요약]" -ForegroundColor Cyan
function PrintSummary($name, $stats) {
    "{0,-25} p50={1}ms p95={2}ms p99={3}ms avg={4}ms max={5}ms" -f $name, $stats.p50, $stats.p95, $stats.p99, $stats.avg, $stats.max
}
Write-Host (PrintSummary "GET /api/echo" $echoRes.stats)
Write-Host (PrintSummary "GET /api/tenant/dbname" $dbRes.stats)
Write-Host (PrintSummary "POST /api/ingest/raw" $ingestRes.stats)

Write-Host "`n[결과 CSV]" $csvPath
Write-Host "[완료]" -ForegroundColor Green
