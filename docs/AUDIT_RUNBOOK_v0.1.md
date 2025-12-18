# 감사 대응 Runbook v0.1

## 목적
- request_id 기반으로 장애와 사용자 행동을 추적 가능하게 한다.
- 조회/Export 안전장치를 넣어 과도한 조회로 인한 성능 저하를 방지한다.

## 핵심 기능
1) request_id 표준화
- 요청 헤더 X-Request-Id가 있으면 검증 후 사용
- 없거나 형식이 잘못되면 서버에서 UUID 생성
- 응답 헤더에 X-Request-Id를 항상 포함
- 로그 MDC에 request_id, tenant_id, user_id, role 포함

2) 관리자 조회 안전장치
- 목록 조회 limit 최대 200
- offset은 0 이상만 허용
- 기본 정렬: received_at desc, id desc

3) Export 제한
- from/to 필수
- 기간 최대 7일
- limit 최대 5000
- 기본은 payload_preview만 포함
- includeDecrypted는 local 프로파일에서만 허용

## 운영 체크리스트
- 로그에서 request_id가 보이는지 확인
- 관리 조회 limit/offset이 정상 동작하는지 확인
- Export가 기간/건수 제한을 넘을 때 400이 반환되는지 확인
