# eGovFrame MES Next Steps Runbook v0.6

## 개요
- 현재 상태: H-1 패키징, S-1 성능 베이스라인, G-3 암호화까지 완료.
- 목적: 성능 퇴행 자동 판정(S-1b)과 향후 DR Lite(S-3) 실행 절차를 빠르게 참고할 수 있는 요약본.

## S-1b 성능 퇴행 자동 판정 사용법
1. 선행: 서버 기동 + perf-baseline 수행 → `C:\MES\perf\perf_baseline_YYYYMMDD_HHMM.csv` 확보.
2. 실행: `pwsh -File .\scripts\perf-gate.ps1 -CsvPath C:\MES\perf\perf_baseline_YYYYMMDD_HHMM.csv`
3. 임계치: `docs\perf-thresholds.v0.1.json` (p95/p99/avg + regression_pct=20%).
4. 결과: `C:\MES\perf\perf_gate_YYYYMMDD_HHMM.json` 저장, 콘솔 PASS/FAIL 출력, FAIL 시 exit code 1.
5. 권장: CI/CD나 배포 스크립트에서 perf-gate 실행 후 FAIL이면 릴리스 중단.

## S-3 DR Lite(백업 자동화 + 복원 리허설) 제안
- 목표: 테넌트별 복구 가능성을 문서+스크립트로 상시 보장.
- 백업 자동화: PowerShell 스케줄러(Windows) 또는 cron(systemd timer)로 tenant별 dump 실행.
- 복원 리허설: 주기적으로 별도 DB/컨테이너에 복원 후 기본 쿼리(SELECT 1, 테이블 카운트) 검증.
- 보관 주기: 최근 N회(예: 14일)만 유지, 오래된 dump 자동 삭제.
- 보안: 운영 비밀번호/키는 Secret Manager나 Vault를 사용하고, 로컬 예제에는 “개발 전용” 표기.

## 체크리스트 요약
- perf-baseline → perf-gate 순서로 실행 가능한지.
- perf-thresholds가 팀 합의치(목표 p95/p99)와 일치하는지.
- 배포 ZIP에 perf-gate, perf-baseline, perf-thresholds가 포함되는지(build-release.ps1 확인).
- DR Lite: 백업 경로 접근 권한, 보관 주기, 복원 스텝을 운영 계정으로 검증했는지.
