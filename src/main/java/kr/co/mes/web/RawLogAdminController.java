package kr.co.mes.web;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import jakarta.servlet.http.HttpSession;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import kr.co.mes.service.RawLogService;
import kr.co.mes.support.SessionConstants;

/**
 * 초보자용 상세 주석:
 * - 원시 로그를 관리자 권한으로 조회하는 API입니다.
 * - 세션 role이 ADMIN인지 확인하고, 테넌트는 세션 확정값을 사용합니다.
 */
@RestController
@RequestMapping(path = "/api/admin/raw-logs", produces = MediaType.APPLICATION_JSON_VALUE)
@Profile("local")
public class RawLogAdminController {

    private final RawLogService rawLogService;
    private final boolean localProfile;

    public RawLogAdminController(RawLogService rawLogService,
                                 @Value("${spring.profiles.active:local}") String activeProfile) {
        this.rawLogService = rawLogService;
        this.localProfile = activeProfile != null && activeProfile.toLowerCase().contains("local");
    }

    /**
     * 관리자 목록 조회.
     * - from/to: ISO-8601 문자열(예 2025-12-17T00:00:00Z)
     * - eventType, source, requestId: 선택 필터
     * - limit: 최대 200, offset: 0 이상
     */
    @GetMapping
    public ResponseEntity<?> findLogs(
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(required = false) String eventType,
            @RequestParam(required = false) String source,
            @RequestParam(required = false) String requestId,
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(defaultValue = "0") int offset,
            HttpSession session) {

        if (!isAdmin(session)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error("forbidden"));
        }
        if (limit < 1 || limit > 200) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("limit must be 1~200"));
        }
        if (offset < 0) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("offset must be >= 0"));
        }

        OffsetDateTime fromTs = parseOrNull(from);
        OffsetDateTime toTs = parseOrNull(to);

        Map<String, Object> result = rawLogService.findLogs(fromTs, toTs, eventType, source, requestId, limit, offset);
        return ResponseEntity.ok(result);
    }

    /**
     * 관리자 단건 상세 조회.
     */
    @GetMapping("/{id}")
    public ResponseEntity<?> findById(@PathVariable long id, HttpSession session) {
        if (!isAdmin(session)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error("forbidden"));
        }
        Map<String, Object> row = rawLogService.findById(id);
        if (row == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error("not found"));
        }
        return ResponseEntity.ok(row);
    }

    /**
     * 관리자 Export (CSV).
     * - from/to 필수
     * - 기간 최대 7일
     * - limit 최대 5000
     * - includeDecrypted는 local 프로파일에서만 허용
     */
    @GetMapping(value = "/export", produces = "text/csv")
    public ResponseEntity<?> export(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) String eventType,
            @RequestParam(required = false) String source,
            @RequestParam(required = false) String requestId,
            @RequestParam(defaultValue = "1000") int limit,
            @RequestParam(defaultValue = "false") boolean includeDecrypted,
            HttpSession session) {

        if (!isAdmin(session)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error("forbidden"));
        }
        if (limit < 1 || limit > 5000) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("limit must be 1~5000"));
        }
        if (includeDecrypted && !localProfile) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("includeDecrypted allowed only in local"));
        }

        OffsetDateTime fromTs = parseOrNull(from);
        OffsetDateTime toTs = parseOrNull(to);
        if (fromTs == null || toTs == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("from/to is required"));
        }
        if (toTs.isBefore(fromTs)) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("to must be >= from"));
        }
        Duration range = Duration.between(fromTs, toTs);
        if (range.toDays() > 7) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error("range must be within 7 days"));
        }

        List<Map<String, Object>> rows = rawLogService.exportLogs(fromTs, toTs, eventType, source, requestId, limit, includeDecrypted);
        String csv = toCsv(rows, includeDecrypted);

        return ResponseEntity.ok()
                .contentType(MediaType.valueOf("text/csv"))
                .header("Content-Disposition", "attachment; filename=raw_logs.csv")
                .body(csv);
    }

    private boolean isAdmin(HttpSession session) {
        String role = (String) session.getAttribute(SessionConstants.ATTR_ROLE);
        return "ADMIN".equalsIgnoreCase(role);
    }

    private Map<String, Object> error(String msg) {
        Map<String, Object> body = new HashMap<>();
        body.put("ok", false);
        body.put("error", msg);
        return body;
    }

    private OffsetDateTime parseOrNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return OffsetDateTime.parse(value, DateTimeFormatter.ISO_OFFSET_DATE_TIME);
    }

    private String toCsv(List<Map<String, Object>> rows, boolean includeDecrypted) {
        StringBuilder sb = new StringBuilder();
        sb.append("id,tenant_id,source,event_type,received_at,request_id,user_id,role,payload_preview");
        if (includeDecrypted) {
            sb.append(",decrypted_payload");
        }
        sb.append("\n");

        for (Map<String, Object> row : rows) {
            sb.append(csv(row.get("id"))).append(",");
            sb.append(csv(row.get("tenant_id"))).append(",");
            sb.append(csv(row.get("source"))).append(",");
            sb.append(csv(row.get("event_type"))).append(",");
            sb.append(csv(row.get("received_at"))).append(",");
            sb.append(csv(row.get("request_id"))).append(",");
            sb.append(csv(row.get("user_id"))).append(",");
            sb.append(csv(row.get("role"))).append(",");
            sb.append(csv(row.get("payload_preview")));
            if (includeDecrypted) {
                sb.append(",").append(csv(row.get("decrypted_payload")));
            }
            sb.append("\n");
        }
        return sb.toString();
    }

    private String csv(Object value) {
        if (value == null) {
            return "\"\"";
        }
        String s = String.valueOf(value).replace("\"", "\"\"");
        return "\"" + s + "\"";
    }
}
