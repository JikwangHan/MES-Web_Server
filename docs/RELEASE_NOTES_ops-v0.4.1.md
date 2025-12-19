# Release Notes - ops-v0.4.1

## 1. 태그/커밋
- Tag: ops-v0.4.1
- Branch: main
- Commit: 2544e20

## 2. 변경 요약
System.Object[]

## 3. 운영 검증 결과
- OPS_STATUS: PASS
- HEALTH: UP
- PERF_GATE_EXITCODE: N/A

## 4. 증빙 경로
- PERF_CSV: C:\MES\perf\perf_baseline_20251219_1331.csv
- PERF_GATE_JSON: C:\MES\perf\perf_gate_20251219_1331.json
- EVIDENCE_ZIP: C:\MES\evidence\evidence_20251219_1331.zip
- OPS_LOG: C:\MES\ops\ops_daily_20251219_1331.log

## 5. 상태 스냅샷
- Service: Paused / Automatic
- Port 8080:
System.Object[]

## 6. Known Issues
- 없음

## 7. 재현 커맨드
- ops-daily-check: `powershell -File .\scripts\ops-daily-check.ps1`
- deploy-rehearsal: `powershell -File .\scripts\deploy-rehearsal.ps1 -ZipPath <latest>`
- service check: `Get-Service -Name "MES-Web"`
