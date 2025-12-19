# 로컬 부팅 진단 스크립트 (Windows PowerShell)
# 목적: Spring Boot 부팅 실패 원인을 자동으로 수집하고, 가능한 부분은 자동으로 보정합니다.
# 주의: 비밀번호, 키, 전체 payload 같은 민감정보는 출력하지 않습니다.

param(
    [switch]$AutoCrypto = $true,
    [int]$Port = 8080,
    [int]$HealthTimeoutSec = 120,
    [int]$HealthIntervalSec = 2
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Info {
    param([string]$msg)
    Write-Host "[INFO] $msg"
}

function Write-Warn {
    param([string]$msg)
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$msg)
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

function Write-Summary {
    param(
        [string]$Health,
        [string]$BootLog,
        [string]$PerfCsv,
        [string]$PerfGateJson,
        [string]$PerfGateExit
    )
    Write-Output ""
    Write-Output "===== SUMMARY ====="
    Write-Output "HEALTH: $Health"
    Write-Output "BOOT_LOG: $BootLog"
    Write-Output "PERF_CSV: $PerfCsv"
    Write-Output "PERF_GATE_JSON: $PerfGateJson"
    Write-Output "PERF_GATE_EXITCODE: $PerfGateExit"
    Write-Output "==================="
}

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
$mvnw = Join-Path $projectRoot "mvnw.cmd"
$jar = Join-Path $projectRoot "bin\mes-web.jar"
$runLocal = Join-Path $projectRoot "bin\run-local.ps1"
$mode = if (Test-Path $mvnw) { "source" } elseif (Test-Path $jar) { "deploy" } else { "unknown" }
$logDir = "C:\MES\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# 1) JAVA_HOME/Path 점검
if (-not $env:JAVA_HOME) {
    $defaultJdk = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
    if (Test-Path $defaultJdk) {
        $env:JAVA_HOME = $defaultJdk
        $env:Path = "$($env:JAVA_HOME)\bin;$env:Path"
        Write-Info "JAVA_HOME이 없어 기본 경로로 설정했습니다."
    } else {
        Write-Warn "JAVA_HOME이 설정되어 있지 않습니다. Java 17 설치 경로를 확인하세요."
    }
} else {
    Write-Info "JAVA_HOME 확인됨."
}

# 2) 실행 모드 확인(소스/배포본)
if ($mode -eq "unknown") {
    Write-Err "실행 모드를 판별할 수 없습니다. mvnw.cmd 또는 bin\mes-web.jar가 필요합니다."
    Write-Summary -Health "FAIL" -BootLog "N/A" -PerfCsv "N/A" -PerfGateJson "N/A" -PerfGateExit "N/A"
    exit 1
}
Write-Info "실행 모드: $mode"

# 3) 프로필 확인(가능하면 local 권장)
$profile = $env:SPRING_PROFILES_ACTIVE
if (-not $profile) {
    $appYml = Join-Path $projectRoot "src\main\resources\application.yml"
    if (Test-Path $appYml) {
        $text = Get-Content -Path $appYml -Raw
        $match = [regex]::Match($text, "(?m)^\s*active:\s*(\S+)")
        if ($match.Success) { $profile = $match.Groups[1].Value }
    }
}
if ($profile) {
    Write-Info "SPRING_PROFILES_ACTIVE = $profile"
} else {
    Write-Warn "SPRING_PROFILES_ACTIVE를 확인하지 못했습니다. local 프로필 권장."
}

# 4) 암호화 환경변수 점검 및 자동 생성(기본 ON)
$cryptoKeys = $env:MES_CRYPTO_KEYS
$cryptoActive = $env:MES_CRYPTO_ACTIVE_KEY_ID
$cryptoAllowPlain = $env:MES_CRYPTO_ALLOW_PLAINTEXT

if ((-not $cryptoKeys) -or (-not $cryptoActive) -or (-not $cryptoAllowPlain)) {
    if ($AutoCrypto) {
        $bytes = New-Object byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $k = [Convert]::ToBase64String($bytes)
        $env:MES_CRYPTO_KEYS = "v1=$k"
        $env:MES_CRYPTO_ACTIVE_KEY_ID = "v1"
        $env:MES_CRYPTO_ALLOW_PLAINTEXT = "false"
        Write-Info "암호화 키를 세션에 임시 주입했습니다. (keyId=v1, length=32 bytes)"
    } else {
        Write-Warn "암호화 환경변수가 부족합니다. AutoCrypto를 켜거나 직접 설정하세요."
    }
} else {
    Write-Info "암호화 환경변수 확인됨."
}

# 5) 8080 점유 여부 점검
$listen = netstat -ano | findstr ":$Port" | findstr LISTENING
if ($listen) {
    Write-Warn "포트 $Port 사용 중입니다. 아래 PID를 확인하세요."
    $listen | ForEach-Object { $_.Trim() } | ForEach-Object {
        $procId = ($_ -split "\s+")[-1]
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($p) {
            Write-Host "  PID=$procId NAME=$($p.ProcessName)"
        } else {
            Write-Host "  PID=$procId"
        }
    }
}

# 6) 실행 + 로그 저장
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("boot_run_{0}.log" -f $ts)
Write-Info "부팅 로그 파일: $logPath"

if ($mode -eq "source") {
    $cmd = @"
cd "$projectRoot"
.\mvnw.cmd spring-boot:run 2>&1 | Tee-Object -FilePath "$logPath"
"@
    Start-Process powershell -ArgumentList "-NoExit","-Command", $cmd | Out-Null
} else {
    if (Test-Path $runLocal) {
        Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File", $runLocal | Out-Null
    } else {
        $cmd = @"
cd "$projectRoot"
java -jar .\bin\mes-web.jar 2>&1 | Tee-Object -FilePath "$logPath"
"@
        Start-Process powershell -ArgumentList "-NoExit","-Command", $cmd | Out-Null
    }
}

# 7) health 폴링
$baseUrl = "http://localhost:$Port/actuator/health"
$maxAttempts = [int]([math]::Ceiling($HealthTimeoutSec / $HealthIntervalSec))
$ok = $false
for ($i=1; $i -le $maxAttempts; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri $baseUrl -TimeoutSec 5
        if ($resp.status -eq "UP") { $ok = $true; break }
    } catch {}
    Start-Sleep -Seconds $HealthIntervalSec
}

if ($ok) {
    Write-Info "서버 기동 확인 완료: $baseUrl"
    Write-Info "서버 창을 닫지 말고 그대로 유지하세요."
    if (-not (Test-Path $logPath)) {
        $latestLog = Get-ChildItem C:\MES\logs\boot_run_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestLog) { $logPath = $latestLog.FullName }
    }

    # 8) UP 성공 시 성능 측정 자동 실행
    $perfCsv = "N/A"
    $perfGateJson = "N/A"
    $perfGateExit = "N/A"

    try {
        powershell -File (Join-Path $projectRoot "scripts\perf-baseline.ps1")
        $csv = Get-ChildItem C:\MES\perf\perf_baseline_*.csv | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $csv) { throw "perf baseline CSV not found" }
        $perfCsv = $csv.FullName

        $stamp = Get-Date -Format "yyyyMMdd_HHmm"
        $outJson = "C:\MES\perf\perf_gate_$stamp.json"
        $gateOutput = powershell -File (Join-Path $projectRoot "scripts\perf-gate.ps1") -CsvPath $csv.FullName -OutJsonPath $outJson
        $perfGateExit = $LASTEXITCODE

        $parsed = $gateOutput | Select-String -Pattern '^OUTPUT_JSON=' | Select-Object -Last 1
        if ($parsed) {
            $perfGateJson = $parsed.Line.Substring(12)
        } elseif (Test-Path $outJson) {
            $perfGateJson = $outJson
        } else {
            $recent = Get-ChildItem C:\MES\perf\perf_gate_*.json | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($recent) { $perfGateJson = $recent.FullName }
        }
    } catch {
        Write-Warn "성능 측정 중 오류가 발생했습니다."
    }

    Write-Summary -Health "UP" -BootLog $logPath -PerfCsv $perfCsv -PerfGateJson $perfGateJson -PerfGateExit $perfGateExit
    if ($perfGateExit -eq 0 -and $perfGateJson -ne "N/A") {
        Write-Info "증빙 패키징을 원하면 다음을 실행하세요:"
        Write-Info "  powershell -File .\scripts\collect-evidence.ps1"
    }
    exit 0
}

# 9) 실패 시 로그 일부 출력 + 원인 후보 분류
Write-Err "서버 기동 실패 또는 지연. 로그 마지막 120줄을 출력합니다."
if (Test-Path $logPath) {
    Get-Content -Path $logPath -Tail 120
} else {
    Write-Warn "로그 파일을 찾을 수 없습니다: $logPath"
}

$logText = ""
if (Test-Path $logPath) {
    $logText = (Get-Content -Path $logPath -Tail 500 | Out-String)
}

$candidates = @()
$evidence = @{}
if ($logText -match "MES_CRYPTO_KEYS" -or $logText -match "Active key" -or $logText -match "Crypto") {
    $candidates += "암호화 키(MES_CRYPTO_KEYS) 누락 또는 파싱 오류"
    $evidence["암호화 키"] = "MES_CRYPTO_KEYS 또는 Crypto 관련 키워드 발견"
}
if ($logText -match "application-local.yml" -or $logText -match "profiles" -or $logText -match "SPRING_PROFILES_ACTIVE") {
    $candidates += "프로필 또는 application-local.yml 설정 문제"
    $evidence["프로필"] = "profiles/application-local 관련 키워드 발견"
}
if ($logText -match "BindException" -or $logText -match "Address already in use") {
    $candidates += "포트 바인딩 오류(8080 점유)"
    $evidence["포트"] = "BindException 또는 Address already in use 발견"
}
if ($logText -match "Failed to obtain JDBC" -or $logText -match "Connection refused" -or $logText -match "Access denied" -or $logText -match "Communications link failure") {
    $candidates += "DB 접속 실패(컨테이너/포트/계정/DB명)"
    $evidence["DB"] = "JDBC/Connection/Access denied 관련 키워드 발견"
}
if ($logText -match "BUILD FAILURE" -or $logText -match "Failed to execute goal" -or $logText -match "Compilation failure") {
    $candidates += "빌드 또는 의존성 오류"
    $evidence["빌드"] = "BUILD FAILURE/Compilation failure 키워드 발견"
}

if ($candidates.Count -gt 0) {
    $top1 = $candidates | Select-Object -First 1
    Write-Info "원인 후보 Top1: $top1"
    if ($evidence.Count -gt 0) {
        $key = $evidence.Keys | Select-Object -First 1
        Write-Info "근거 키워드: $($evidence[$key])"
    }
} else {
    Write-Info "원인 후보를 자동으로 확정하지 못했습니다. 로그를 확인하세요."
}

Write-Summary -Health "FAIL" -BootLog $logPath -PerfCsv "N/A" -PerfGateJson "N/A" -PerfGateExit "N/A"
exit 1
