# 로컬 실행 스크립트 (Windows PowerShell)
# 사용 방법:
#   1) 예시 파일 ../config/env.local.ps1.example 참고 후 env.local.ps1 생성 후 dot-source로 로드
#      예) . ..\config\env.local.ps1
#   2) MariaDB 컨테이너와 포트(8080/3306) 상태 확인
#   3) 이 스크립트를 실행하면 Spring Boot가 시작됩니다.

param(
    [switch]$AutoCrypto = $true
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 환경변수 로드: 필요 시 아래 줄의 주석을 해제
# . "..\config\env.local.ps1"

# JAVA_HOME 자동 설정(없으면 기본 경로 사용)
if (-not $env:JAVA_HOME) {
    $defaultJdk = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
    if (Test-Path $defaultJdk) {
        $env:JAVA_HOME = $defaultJdk
        $env:Path = "$($env:JAVA_HOME)\bin;$env:Path"
        Write-Host "[INFO] JAVA_HOME을 기본 경로로 설정했습니다."
    } else {
        Write-Host "[WARN] JAVA_HOME이 설정되지 않았습니다. Java 17 설치 경로를 확인하세요." -ForegroundColor Yellow
    }
}

# 암호화 환경변수 자동 생성(기본 ON)
if ($AutoCrypto) {
    if (-not $env:MES_CRYPTO_KEYS -or -not $env:MES_CRYPTO_ACTIVE_KEY_ID) {
        $bytes = New-Object byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $k = [Convert]::ToBase64String($bytes)
        $env:MES_CRYPTO_KEYS = "v1=$k"
        $env:MES_CRYPTO_ACTIVE_KEY_ID = "v1"
        if (-not $env:MES_CRYPTO_ALLOW_PLAINTEXT) { $env:MES_CRYPTO_ALLOW_PLAINTEXT = "false" }
        Write-Host "[INFO] 암호화 키를 세션에 임시 주입했습니다. (keyId=v1, length=32 bytes)"
    }
}

Write-Host "[INFO] JAVA_HOME:" $env:JAVA_HOME
Write-Host "[INFO] 프로파일:" $env:SPRING_PROFILES_ACTIVE
Write-Host "[INFO] 암호화키 ID:" $env:MES_CRYPTO_ACTIVE_KEY_ID

# 로그 파일 경로
$logDir = "C:\MES\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("boot_run_{0}.log" -f $ts)

# 애플리케이션 실행 (백그라운드) + health 폴링
Set-Location "$PSScriptRoot"
$proc = Start-Process -FilePath "java" -ArgumentList "-jar",".\mes-web.jar" -RedirectStandardOutput $logPath -RedirectStandardError $logPath -PassThru

$baseUrl = "http://localhost:8080/actuator/health"
$maxAttempts = 24
$ok = $false
for ($i=1; $i -le $maxAttempts; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri $baseUrl -TimeoutSec 5
        if ($resp.status -eq "UP") { $ok = $true; break }
    } catch {}
    Start-Sleep -Seconds 5
}

if ($ok) {
    Write-Host "[INFO] READY: $baseUrl"
} else {
    Write-Host "[WARN] 서버가 아직 준비되지 않았습니다. 로그를 확인하세요: $logPath" -ForegroundColor Yellow
}

# 서버가 계속 실행되도록 대기
Wait-Process -Id $proc.Id
