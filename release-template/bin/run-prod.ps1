# 운영 실행 스크립트 (Windows PowerShell)
# - 운영 환경에서는 prod 프로필을 기본으로 사용합니다.
# - 민감정보는 출력하지 않습니다.

$ErrorActionPreference = 'Stop'

if (-not $env:SPRING_PROFILES_ACTIVE) { $env:SPRING_PROFILES_ACTIVE = "prod" }

Write-Host "[INFO] PROD 실행 준비"
Write-Host "SPRING_PROFILES_ACTIVE=" $env:SPRING_PROFILES_ACTIVE
Write-Host "MES_CRYPTO_ACTIVE_KEY_ID=" $env:MES_CRYPTO_ACTIVE_KEY_ID

Set-Location "$PSScriptRoot"
java -Dspring.profiles.active=$($env:SPRING_PROFILES_ACTIVE) -jar .\mes-web.jar
