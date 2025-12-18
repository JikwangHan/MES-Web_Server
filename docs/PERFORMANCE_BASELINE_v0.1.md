# 성능 베이스라인 v0.1

## 1. 측정 목적
- 현재(암호화, 원시로그, 스케줄러 적용) 상태의 응답 지연을 수치화
- 이후 변경 시 성능 퇴행 여부를 빠르게 감지

## 2. 측정 환경 예시
- OS: Windows 11 / PowerShell 7+
- JDK: Temurin 17
- DB: MariaDB 컨테이너 (mes_tenant_a, mes_tenant_b)
- 프로필: local
- 서버 포트: 8080
- 암호화: AES-GCM(키는 환경변수로 주입)

## 3. 실행 방법
1) 서버 기동: `./mvnw.cmd spring-boot:run` 또는 release-template/bin 스크립트 사용
2) PowerShell에서 성능 스크립트 실행:
   ```
   pwsh -File .\scripts\perf-baseline.ps1
   ```
3) 결과 CSV 확인: `C:\MES\perf\perf_baseline_YYYYMMDD_HHMM.csv`

## 4. 지표 정의
- p50: 중앙값
- p95: 상위 5% 이하로 들어오는 응답 시간
- p99: 상위 1% 이하 응답 시간
- avg/max: 평균 및 최대 응답 시간

## 5. 퇴행 판단 규칙(초안)
- 기준선 대비 p95가 20% 이상 증가하면 FAIL로 간주하고 원인 분석
- 재측정 시 조건 동일(프로필, DB, payload, Iterations=200) 유지

## 6. 측정 대상 엔드포인트
- GET /api/echo?msg=perf
- GET /api/tenant/dbname
- POST /api/ingest/raw (작은 JSON)

## 7. 성능에 영향 주는 요소 메모
- 로그 출력 수준/패턴 (파일 I/O)
- 암호화 키 로딩/암복호화 오버헤드
- 원시 로그 INSERT 및 인덱스
- Docker I/O(윈도우 WSL2) 및 DB 컨테이너 리소스

## 8. 퇴행 발생 시 조사 순서
1) 로그량/로그 경로 확인
2) DB 상태/컨테이너 리소스(CPU/IO) 확인
3) GC 로그(필요 시) 또는 heap/메모리 사용량 확인
4) 암호화 키/환경변수 변경 여부 확인
