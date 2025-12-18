# 개발 서버 실행 스크립트 (Windows PowerShell)
# 사용 방법:
#   1) ../config/env.local.ps1.example를 복사해 env.dev.ps1 등으로 작성 후 dot-source로 로드
#      예:  . ..\config\env.dev.ps1
#   2) 필요한 포트/DB/MariaDB 컨테이너 상태 확인
#   3) 실행: powershell -File run-dev.ps1

$ErrorActionPreference = 'Stop'

# 환경변수 로드 (필요 시 주석 해제)
# . "..\config\env.dev.ps1"

Write-Host "[INFO] PROF:" $env:SPRING_PROFILES_ACTIVE
Write-Host "[INFO] KEY:" $env:MES_CRYPTO_ACTIVE_KEY_ID

Set-Location "$PSScriptRoot"
java -jar .\mes-web.jar
