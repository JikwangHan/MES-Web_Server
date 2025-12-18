package kr.co.mes.web;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.servlet.http.HttpSession;

import org.apache.commons.codec.digest.DigestUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import kr.co.mes.service.RawLogService;
import kr.co.mes.support.RequestIdContext;
import kr.co.mes.support.SessionConstants;
import kr.co.mes.support.TenantContext;

/**
 * 초보자용 상세 주석:
 * - 원시 이벤트를 수집해 DB에 저장하는 엔드포인트입니다.
 * - 현재 세션에서 확정된 테넌트 ID를 사용하며, 헤더 위변조는 허용하지 않습니다.
 */
@RestController
@RequestMapping(path = "/api/ingest", produces = MediaType.APPLICATION_JSON_VALUE)
@Profile("local")
public class RawIngestController {

    private static final Logger log = LoggerFactory.getLogger(RawIngestController.class);
    private final RawLogService rawLogService;
    private final ObjectMapper objectMapper;

    /**
     * 생성자 주입.
     */
    public RawIngestController(RawLogService rawLogService, ObjectMapper objectMapper) {
        this.rawLogService = rawLogService;
        this.objectMapper = objectMapper;
    }

    /**
     * 요청 DTO: source, eventType, payload(JSON 객체).
     */
    public record RawIngestRequest(String source, String eventType, Object payload, String requestId) {}

    /**
     * POST /api/ingest/raw
     * - payload를 JSON 문자열로 직렬화 후 SHA-256 해시를 계산하여 저장합니다.
     * - 세션 사용자/역할 정보를 함께 기록합니다.
     */
    @PostMapping("/raw")
    public ResponseEntity<?> ingest(@RequestBody RawIngestRequest request, HttpSession session) {
        Map<String, Object> body = new HashMap<>();

        // 세션에서 사용자/역할/테넌트 정보 조회 (없으면 ANONYMOUS/기본 테넌트)
        String userId = (String) session.getAttribute(SessionConstants.ATTR_USER_ID);
        if (userId == null || userId.isBlank()) {
            userId = "ANONYMOUS";
        }
        String role = (String) session.getAttribute(SessionConstants.ATTR_ROLE);
        if (role == null || role.isBlank()) {
            role = "ANONYMOUS";
        }

        String tenantId = TenantContext.getTenantIdOrDefault();
        String eventType = request.eventType() == null ? "UNKNOWN" : request.eventType();
        String source = request.source() == null ? "UNKNOWN" : request.source();

        // payload 직렬화
        String payloadJson;
        try {
            payloadJson = objectMapper.writeValueAsString(request.payload());
        } catch (JsonProcessingException e) {
            body.put("ok", false);
            body.put("error", "payload serialization failed");
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
        }

        // SHA-256 해시
        String payloadSha = DigestUtils.sha256Hex(payloadJson);

        // received_at UTC, requestId는 필터에서 확정한 값을 사용
        OffsetDateTime receivedAt = OffsetDateTime.now(ZoneOffset.UTC);
        String requestId = RequestIdContext.getOrCreate();

        long id = rawLogService.save(tenantId, source, eventType, payloadJson, payloadSha, receivedAt, requestId, userId, role);

        // 요약 로그(민감정보 제외)
        log.info("raw_ingest summary request_id={}, tenant_id={}, event_type={}, source={}, payload_size={}",
                requestId, tenantId, eventType, source, payloadJson.length());

        body.put("ok", true);
        body.put("id", id);
        body.put("requestId", requestId);
        body.put("tenant", tenantId);
        return ResponseEntity.ok(body);
    }
}
