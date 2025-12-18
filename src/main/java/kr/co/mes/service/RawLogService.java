package kr.co.mes.service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

/**
 * 원시 로그 저장/조회 서비스 인터페이스입니다.
 * - 멀티테넌트 라우팅된 DataSource를 사용합니다.
 * - 초보자용 상세 주석 포함.
 */
public interface RawLogService {

    /**
     * 원시 로그를 저장하고 생성된 PK를 반환합니다.
     *
     * @param tenantId       현재 테넌트
     * @param source         이벤트 발생 소스(클라이언트/모듈명 등)
     * @param eventType      이벤트 유형
     * @param payloadJson    원문 JSON 문자열
     * @param payloadSha256  payload의 SHA-256 해시
     * @param receivedAt     수신 시각 (UTC)
     * @param requestId      요청 식별자(UUID 등)
     * @param userId         세션 사용자 ID (없으면 ANONYMOUS)
     * @param role           세션 역할 (없으면 ANONYMOUS)
     * @return 생성된 id
     */
    long save(String tenantId, String source, String eventType, String payloadJson, String payloadSha256,
              OffsetDateTime receivedAt, String requestId, String userId, String role);

    /**
     * 관리자 목록 조회.
     *
     * @param from     조회 시작 시각 (nullable)
     * @param to       조회 종료 시각 (nullable)
     * @param eventType 이벤트 타입 필터 (nullable)
     * @param source    소스 필터 (nullable)
     * @param limit     최대 개수 (1~1000)
     * @return items 리스트와 count를 담은 Map
     */
    Map<String, Object> findLogs(OffsetDateTime from, OffsetDateTime to, String eventType, String source,
                                 String requestId, int limit, int offset);

    /**
     * 관리자 Export용 조회.
     *
     * @param from       조회 시작 시각(필수)
     * @param to         조회 종료 시각(필수)
     * @param eventType  이벤트 타입 필터
     * @param source     소스 필터
     * @param requestId  request_id 필터
     * @param limit      최대 건수
     * @param includeDecrypted 복호화 포함 여부(local에서만 허용)
     * @return export용 리스트
     */
    List<Map<String, Object>> exportLogs(OffsetDateTime from, OffsetDateTime to, String eventType, String source,
                                         String requestId, int limit, boolean includeDecrypted);

    /**
     * 단건 상세 조회.
     *
     * @param id PK
     * @return row Map 또는 null
     */
    Map<String, Object> findById(long id);
}
