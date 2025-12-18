# 운영 패키징 런북 (v0.2)

## 1. 패키지 구조
```
release-template/
  bin/           # 실행 스크립트 (Windows/Linux)
  config/        # 환경변수 템플릿
  scripts/       # 백업/복원/성능 측정·판정 스크립트
  logs/          # 로그 출력 위치
  backup/        # 백업 파일 저장 위치
  docs/          # 성능 임계치(perf-thresholds)
  README_RUNBOOK.md
```

## 2. 사전 준비
- Java 17 설치
- MariaDB 컨테이너 기동(tenant_a, tenant_b 준비)
- 암호화 키 환경변수: 32바이트 Base64, 예) `MES_CRYPTO_KEYS="v1=BASE64KEY"`

## 3. 환경변수 설정
- Windows: `config/env.local.ps1.example`를 복사 후 값 설정 → `. .\env.local.ps1`
- Linux: `config/env.prod.sh.example`를 복사 후 값 설정 → `source env.prod.sh`
- 주요 변수
  - MES_CRYPTO_KEYS: "v1=BASE64;v2=BASE64"
  - MES_CRYPTO_ACTIVE_KEY_ID: "v1"
  - MES_CRYPTO_ALLOW_PLAINTEXT: "false"
  - SPRING_PROFILES_ACTIVE: local/dev/prod
  - SPRING_DATASOURCE_URL / USERNAME / PASSWORD

## 4. 실행 방법
- Windows 로컬: `bin\run-local.ps1`
- Windows 운영: 서비스/계정에 맞게 `bin\run-prod.ps1` (NSSM 등으로 서비스화 가능)
- Linux: `chmod +x bin/run-linux.sh && bin/run-linux.sh`
- 기본 포트 8080 (필요 시 SERVER_PORT 환경변수로 변경)

## 5. 로그
- 경로: release-template/logs
- logback-spring.xml 기준으로 콘솔 + 일자별 롤링(UTF-8)

## 6. 백업/복원 (기본 스크립트)
- tenant_a 백업: `scripts/backup-tenant-a.ps1`
- tenant_b 백업: `scripts/backup-tenant-b.ps1`
- 복원: `scripts/restore-tenant.ps1 -Tenant tenant_a -DumpPath "C:\MES\backup\mes_tenant_a_xxx.sql"`
- 백업 파일 저장 위치: release-template/backup

## 7. 성능 측정 (S-1 베이스라인)
- 실행: `pwsh -File .\scripts\perf-baseline.ps1`
- 전제: 서버 기동 상태, 로컬 DB/암호화 설정 완료
- 결과: `C:\MES\perf\perf_baseline_YYYYMMDD_HHMM.csv`
- 출력 지표: p50/p95/p99/avg/max (엔드포인트별)
- 기준 예시: 기존 대비 p95가 20% 이상 상승 시 FAIL 판단

## 7-1. 성능 퇴행 판정 (S-1b)
- 실행: `pwsh -File .\scripts\perf-gate.ps1 -CsvPath C:\MES\perf\perf_baseline_YYYYMMDD_HHMM.csv`
- 임계치 파일: `docs\perf-thresholds.v0.1.json` (regression_pct=0 고정 권장)
- 결과: `C:\MES\perf\perf_gate_YYYYMMDD_HHMM.json` 저장 + 콘솔 PASS/FAIL 출력
- 실패 시 exit code 1로 자동 차단 가능

## 8. 장애/점검 체크리스트
1) 컨테이너 상태: `docker ps` (mes-mariadb)
2) 포트: 3306(MariaDB), 8080(웹)
3) 헬스: `http://localhost:8080/actuator/health`
4) 현재 DB 확인: `/api/tenant/dbname`
5) 원시 로그 조회(ADMIN 세션): `/api/admin/raw-logs`

## 9. Linux systemd 예시 (수동 등록)
```
[Unit]
Description=MES Web
After=network.target

[Service]
User=mes
WorkingDirectory=/opt/mes-web/bin
EnvironmentFile=/opt/mes-web/config/env.prod.sh
ExecStart=/usr/bin/java -jar /opt/mes-web/bin/mes-web.jar
Restart=always

[Install]
WantedBy=multi-user.target
```
- 등록: `sudo systemctl enable mes-web && sudo systemctl start mes-web`

## 10. 보안/키 관리
- MES_CRYPTO_KEYS는 OS 환경변수나 Vault로 주입, 코드/DB에 저장 금지
- 키 교체 시 activeKeyId 교체 → 기존 키를 registry에 함께 두어 복호화 가능하게 유지

## 11. 릴리스 ZIP 만들기
- `build-release.ps1` 실행 → `C:\MES\dist\mes-web_release_YYYYMMDD_HHMM.zip` 생성
- ZIP 포함 항목: bin/, config/, scripts/, docs/, logs/, backup/, README_RUNBOOK.md, mes-web.jar

## 12. DR Lite (백업 자동화 + 복원 리허설)
- 백업(Windows): `scripts/backup-all-tenants.ps1` (tenant_a → tenant_b 순서)
  - 경로: `C:\MES\backup\{tenant}\mes_{tenant}_YYYYMMDD_HHMMSS.sql`
  - 로그: `C:\MES\backup\backup_run_YYYYMMDD.log`
  - 작업 스케줄러 예시: 매일 02:00에 `powershell -File <스크립트 경로>`
- 백업(Linux): `scripts/backup-all-tenants.sh`
  - cron 예시: `0 2 * * * /bin/bash /opt/mes/scripts/backup-all-tenants.sh`
  - 로그: `/opt/mes/backup/backup_run_YYYYMMDD.log`
- 복원 리허설(Windows, ConfirmToken 필요):
  - `powershell -File .\scripts\restore-rehearsal.ps1 -Tenant tenant_a -DumpPath "<덤프 경로>" -ConfirmToken "RESTORE"`
  - 복원 후 SELECT 1, raw_ingest_log 테이블 존재 확인 로그 기록
- DR Lite 검증 스크립트:
  - `powershell -File .\scripts\verify-dr-lite.ps1`

### 12-1. DR Lite 환경변수(권장)
- MES_DB_CONTAINER: Docker 컨테이너명 (기본 mes-mariadb)
- MES_DB_USER: 백업 계정 (기본 mes)
- MES_DB_USER_PASSWORD: 백업 비밀번호 (기본 mes1234!)
- MES_DB_RESTORE_USER: 복원 계정 (기본 root)
- MES_DB_RESTORE_PASSWORD: 복원 비밀번호 (기본 root1234!)

### 12-2. DR Lite 트러블슈팅(Access denied)
- 비밀번호에 특수문자(!)가 포함되어도 스크립트는 환경변수로 전달하므로 안전합니다.
- 문제가 계속되면:
  1) `docker exec -i mes-mariadb mariadb -uroot -proot1234! -e "SELECT 1"` 직접 확인
  2) `MES_DB_RESTORE_PASSWORD` 값 재확인
  3) 컨테이너 이름, DB 매핑(tenant_a → mes_tenant_a) 확인

## 13. 감사 대응 문서
- 상세 가이드는 `docs/AUDIT_RUNBOOK_v0.1.md`를 참고하세요.

## 12-3. Docker 데몬 미기동 트러블슈팅
- 확인: `docker info`가 실패하면 Docker Desktop이 꺼져 있는 상태입니다.
- 조치 1: Docker Desktop을 실행하고 Engine running 상태인지 확인합니다.
- 조치 2: 컨테이너 확인 `docker ps -a --filter "name=mes-mariadb"`
- 조치 3: 중지 상태면 `docker start mes-mariadb`
- 조치 4: 다시 `powershell -File .\scripts\verify-dr-lite.ps1` 실행

## 12-4. 부팅 실패 진단(자동)
- 실행: `powershell -File .\scripts\diagnose-boot.ps1`
- 생성 로그: `C:\MES\logs\boot_run_YYYYMMDD_HHmmss.log`
- health 폴링 후 실패 시 로그 마지막 120줄이 자동 출력됩니다.
- 원인 후보(암호화키, 프로필, DB, 포트, 빌드)를 안내합니다.

## 12-5. 성능 리포트 생성 확인
- diagnose-boot 실행 후 JSON 리포트 생성 여부 확인
  - 경로: `C:\MES\perf\perf_gate_*.json`
- exit code 의미:
  - 0 = PASS(리포트 생성 포함)
  - 1 = FAIL(성능 퇴행)
  - 2 = ERROR(리포트 생성 실패)

## 12-6. 증빙 ZIP 생성
- 실행: `powershell -File .\scripts\collect-evidence.ps1`
- 생성 경로: `C:\MES\evidence\evidence_yyyyMMdd_HHmm\`
- ZIP: `C:\MES\evidence\evidence_yyyyMMdd_HHmm.zip`
- 포함 파일: boot_run_*.log, perf_baseline_*.csv, perf_gate_*.json, evidence_summary.json

## 12-7. S-4 운영 점검 자동화
- 실행: `powershell -File .\scripts\ops-daily-check.ps1`
- 로그: `C:\MES\ops\ops_daily_YYYYMMDD_HHMM.log`
- exit code 의미:
  - 0 = PASS
  - 1 = 운영 FAIL(검증 실패)
  - 2 = 환경 ERROR(데몬/파일/증빙 생성 실패)
- 작업 스케줄러 등록 예시(매일 02:10):
  - 프로그램/스크립트: `powershell`
  - 인수: `-File C:\MES\dev\mes-web\mes-web\scripts\ops-daily-check.ps1`
  - '가장 높은 권한으로 실행' 체크 권장(도커 접근)
