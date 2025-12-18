# 운영 실행 스크립트 (Windows PowerShell)
# - 서비스 계정 또는 NSSM 등 서비스 매니저와 함께 사용 권장
# - 환경변수는 OS 서비스 수준에서 등록 후 사용

$ErrorActionPreference = 'Stop'

Write-Host "[INFO] PROD 실행 준비"
Write-Host "SPRING_PROFILES_ACTIVE=" $env:SPRING_PROFILES_ACTIVE
Write-Host "MES_CRYPTO_ACTIVE_KEY_ID=" $env:MES_CRYPTO_ACTIVE_KEY_ID

Set-Location "$PSScriptRoot"
java -jar .\mes-web.jar
