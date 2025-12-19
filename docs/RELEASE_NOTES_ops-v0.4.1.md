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

## 遺濡?A. ?щ????먮룞 湲곕룞 寃利?1??
- ?ㅽ뻾 ?쒓컖(KST): 2025-12-19 16:19:54
- ?쒕퉬?? MES-Web (StartType=Automatic)
- SERVICE_STATUS: Running
- PORT_8080: LISTEN
- HEALTH: UP
- 濡쒓렇: C:\MES\logs\post_reboot_verify_20251219_161952.log
- 寃곕줎: ?щ??????먮룞 湲곕룞 諛??ъ뒪 ?뺤긽(?댁쁺 ?먮룞 湲곕룞 ?좊ː??湲곗? 異⑹”)

二? ?댁쟾 ?쏱aused???쒓린???ㅻ깄???쒖젏???쇱떆 ?곹깭?怨? ?щ???寃利?寃곌낵濡?Running/UP??理쒖쥌 ?뺤씤??

## 최종 QA 종료 선언
- 최종 판정: PASS
- 기준 태그: ops-v0.4.1
- 재부팅 검증 로그: C:\MES\logs\post_reboot_verify_20251219_161952.log
- 서비스 상태: Running / health UP / 8080 LISTEN
- 증빙: C:\MES\evidence\evidence_20251219_1331.zip
- 비고: mes-web-service.err.log의 "-NoProfile" 로그는 과거 잔재로, 현재 운영에는 영향 없음
