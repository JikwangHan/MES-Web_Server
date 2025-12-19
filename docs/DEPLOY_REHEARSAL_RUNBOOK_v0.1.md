# 배포 리허설 런북 v0.1

## 1) 목적
- 배포 ZIP을 실제 경로에 전개하고, ops 점검과 서비스 설치까지 한 번에 확인합니다.

## 2) 실행 순서
1. ZIP 전개 + ops 점검 + 서비스 설치
   - `powershell -File .\scripts\deploy-rehearsal.ps1`
2. 관리자 권한이 필요하면 -AsAdmin으로 재실행합니다.

## 3) 실패 시 체크 포인트
- 8080 포트 점유: `netstat -ano | findstr :8080`
- Docker 데몬 상태: `docker info`
- DB 컨테이너: `docker ps --filter "name=mes-mariadb"`
- JAVA_HOME 설정 여부
- 암호화 키(MES_CRYPTO_KEYS) 환경변수
- 서비스 로그: C:\MES\logs\mes-web-service.out.log / err.log

## 4) 결과 요약
- 출력 SUMMARY:
  - DEPLOY_ZIP, DEPLOY_DIR, OPS_STATUS, SERVICE_STATUS, HEALTH, REHEARSAL_EVIDENCE_ZIP
