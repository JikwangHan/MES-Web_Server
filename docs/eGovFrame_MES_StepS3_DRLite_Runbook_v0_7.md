# eGovFrame MES Step S-3 DR Lite Runbook v0.7

## 목표
- 테넌트별(DB 별도) 백업을 자동화하고, 복원 리허설을 정기적으로 수행해 장애 시 복구 가능성을 보증한다.
- 안전장치(ConfirmToken)로 오남용을 방지하고, 로그를 남겨 감사/증빙에 활용한다.

## 구성 요소
- 백업 스크립트(Windows): `release-template/scripts/backup-all-tenants.ps1`
- 백업 스크립트(Linux): `release-template/scripts/backup-all-tenants.sh`
- 복원 리허설(Windows): `release-template/scripts/restore-rehearsal.ps1`
- 로그 위치
  - Windows 백업: `C:\MES\backup\backup_run_YYYYMMDD.log`
  - Linux 백업: `/opt/mes/backup/backup_run_YYYYMMDD.log`
  - 복원 리허설: `C:\MES\backup\restore_rehearsal_YYYYMMDD.log`

## 사용 방법 요약
1) 백업(Windows)
- 수동: `powershell -File .\scripts\backup-all-tenants.ps1`
- 스케줄러: 작업 스케줄러에 매일 02:00 실행 등록
2) 백업(Linux)
- 수동: `bash ./scripts/backup-all-tenants.sh`
- cron 예시: `0 2 * * * /bin/bash /opt/mes/scripts/backup-all-tenants.sh`
3) 복원 리허설(Windows, 안전장치)
- `powershell -File .\scripts\restore-rehearsal.ps1 -Tenant tenant_a -DumpPath "<덤프 경로>" -ConfirmToken "RESTORE"`
- ConfirmToken이 맞지 않으면 즉시 중단
- 복원 후 SELECT 1, raw_ingest_log 테이블 확인 로그를 남김

## 체크리스트 (RPO/RTO 관점)
- RPO: 최근 백업 시각이 목표 이내인지(예: 24시간)
- RTO: 복원 리허설이 정기적으로 성공하는지(예: 주 1회)
- 로그 보존: backup_run_*.log, restore_rehearsal_*.log를 일정 기간(예: 30일) 보관
- 보안: 비밀번호/키는 로그에 출력하지 않도록 유지, 덤프 파일 권한 관리

## 장애 시 권장 절차
1) 최근 백업 덤프 선택(backup/tenant_x/mes_tenant_x_*.sql)
2) 복원 리허설 스크립트로 테스트 복원 후 SELECT 1, 테이블 존재 확인
3) 애플리케이션 DB 연결을 새로 맞추고 헬스 체크(/actuator/health) 확인
4) 문제 발생 시 로그(backup_run, restore_rehearsal)와 Docker 로그를 함께 조사
