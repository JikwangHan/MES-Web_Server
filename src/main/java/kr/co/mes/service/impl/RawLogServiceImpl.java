package kr.co.mes.service.impl;

import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedCaseInsensitiveMap;

import com.fasterxml.jackson.databind.ObjectMapper;

import kr.co.mes.crypto.AesGcmCrypto;
import kr.co.mes.crypto.CryptoKeyRegistry;
import kr.co.mes.service.RawLogService;

/**
 * 초보자용 상세 주석:
 * - 라우팅된 JdbcTemplate을 사용해 현재 테넌트 DB에 원시 로그를 저장/조회합니다.
 * - JPA 없이 순수 JDBC로 작성해 구조를 단순하게 유지했습니다.
 */
@Service
public class RawLogServiceImpl implements RawLogService {

    private final JdbcTemplate jdbcTemplate;
    private final CryptoKeyRegistry keyRegistry;
    private final AesGcmCrypto crypto;
    private final ObjectMapper objectMapper;

    public RawLogServiceImpl(JdbcTemplate jdbcTemplate, CryptoKeyRegistry keyRegistry, AesGcmCrypto crypto, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.keyRegistry = keyRegistry;
        this.crypto = crypto;
        this.objectMapper = objectMapper;
    }

    @Override
    public long save(String tenantId, String source, String eventType, String payloadJson, String payloadSha256,
                     OffsetDateTime receivedAt, String requestId, String userId, String role) {
        // 1) 페이로드 암호화: AES-GCM 256bit, nonce 12바이트
        CryptoKeyRegistry.EncryptedPayload enc = crypto.encrypt(payloadJson, keyRegistry.getActiveKeyId());

        // 2) allowPlaintext=false이면 평문은 저장하지 않습니다.
        String plainToStore = keyRegistry.isAllowPlaintext() ? payloadJson : null;

        String sql = """
                INSERT INTO raw_ingest_log
                  (tenant_id, source, event_type, payload_json, payload_sha256, received_at,
                   request_id, user_id, role, payload_enc, payload_nonce, payload_key_id, payload_alg)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;

        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            var ps = connection.prepareStatement(sql, new String[]{"id"});
            ps.setString(1, tenantId);
            ps.setString(2, source);
            ps.setString(3, eventType);
            ps.setString(4, plainToStore);
            ps.setString(5, payloadSha256);
            ps.setTimestamp(6, Timestamp.from(receivedAt.toInstant()));
            ps.setString(7, requestId);
            ps.setString(8, userId);
            ps.setString(9, role);
            ps.setString(10, enc.cipherTextBase64());
            ps.setString(11, enc.nonceBase64());
            ps.setString(12, enc.keyId());
            ps.setString(13, "AES-GCM");
            return ps;
        }, keyHolder);

        Number key = keyHolder.getKey();
        return key == null ? -1 : key.longValue();
    }

    @Override
    public Map<String, Object> findLogs(OffsetDateTime from, OffsetDateTime to, String eventType, String source,
                                        String requestId, int limit, int offset) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, tenant_id, source, event_type, received_at, request_id, user_id, role,
                       payload_json, payload_enc, payload_nonce, payload_key_id
                FROM raw_ingest_log
                WHERE 1=1
                """);
        var params = new java.util.ArrayList<Object>();

        if (from != null) {
            sql.append(" AND received_at >= ? ");
            params.add(Timestamp.from(from.toInstant()));
        }
        if (to != null) {
            sql.append(" AND received_at <= ? ");
            params.add(Timestamp.from(to.toInstant()));
        }
        if (eventType != null && !eventType.isBlank()) {
            sql.append(" AND event_type = ? ");
            params.add(eventType);
        }
        if (source != null && !source.isBlank()) {
            sql.append(" AND source = ? ");
            params.add(source);
        }
        if (requestId != null && !requestId.isBlank()) {
            sql.append(" AND request_id = ? ");
            params.add(requestId);
        }

        sql.append(" ORDER BY received_at DESC, id DESC ");
        int safeLimit = Math.min(Math.max(limit, 1), 200);
        int safeOffset = Math.max(offset, 0);
        sql.append(" LIMIT ? OFFSET ? ");
        params.add(safeLimit);
        params.add(safeOffset);

        List<Map<String, Object>> rows = jdbcTemplate.query(sql.toString(), params.toArray(), (rs, rowNum) -> mapRowWithPreview(rs));

        Map<String, Object> result = new HashMap<>();
        result.put("items", rows);
        result.put("count", rows.size());
        result.put("limit", safeLimit);
        result.put("offset", safeOffset);
        return result;
    }

    @Override
    public List<Map<String, Object>> exportLogs(OffsetDateTime from, OffsetDateTime to, String eventType, String source,
                                                String requestId, int limit, boolean includeDecrypted) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, tenant_id, source, event_type, received_at, request_id, user_id, role,
                       payload_json, payload_enc, payload_nonce, payload_key_id, payload_alg
                FROM raw_ingest_log
                WHERE 1=1
                """);
        var params = new java.util.ArrayList<Object>();

        if (from != null) {
            sql.append(" AND received_at >= ? ");
            params.add(Timestamp.from(from.toInstant()));
        }
        if (to != null) {
            sql.append(" AND received_at <= ? ");
            params.add(Timestamp.from(to.toInstant()));
        }
        if (eventType != null && !eventType.isBlank()) {
            sql.append(" AND event_type = ? ");
            params.add(eventType);
        }
        if (source != null && !source.isBlank()) {
            sql.append(" AND source = ? ");
            params.add(source);
        }
        if (requestId != null && !requestId.isBlank()) {
            sql.append(" AND request_id = ? ");
            params.add(requestId);
        }

        sql.append(" ORDER BY received_at DESC, id DESC ");
        int safeLimit = Math.min(Math.max(limit, 1), 5000);
        sql.append(" LIMIT ").append(safeLimit);

        return jdbcTemplate.query(sql.toString(), params.toArray(),
                (rs, rowNum) -> mapRowForExport(rs, includeDecrypted));
    }

    @Override
    public Map<String, Object> findById(long id) {
        String sql = """
                SELECT id, tenant_id, source, event_type, payload_json, payload_sha256,
                       received_at, request_id, user_id, role,
                       payload_enc, payload_nonce, payload_key_id, payload_alg
                FROM raw_ingest_log
                WHERE id = ?
                """;
        List<Map<String, Object>> list = jdbcTemplate.query(sql, (rs, rowNum) -> mapRowFull(rs), id);
        return list.isEmpty() ? null : list.get(0);
    }

    /**
     * 목록 조회용: payload를 preview만 제공(앞 200자).
     */
    private Map<String, Object> mapRowWithPreview(ResultSet rs) throws java.sql.SQLException {
        Map<String, Object> row = new LinkedCaseInsensitiveMap<>();
        row.put("id", rs.getLong("id"));
        row.put("tenant_id", rs.getString("tenant_id"));
        row.put("source", rs.getString("source"));
        row.put("event_type", rs.getString("event_type"));
        row.put("received_at", rs.getTimestamp("received_at"));
        row.put("request_id", rs.getString("request_id"));
        row.put("user_id", rs.getString("user_id"));
        row.put("role", rs.getString("role"));
        String payload = rs.getString("payload_json");
        if (payload == null) {
            // 평문이 없으면 암호문을 복호화해 프리뷰를 만듭니다.
            String cipher = rs.getString("payload_enc");
            String nonce = rs.getString("payload_nonce");
            String keyId = rs.getString("payload_key_id");
            try {
                payload = crypto.decrypt(cipher, nonce, keyId);
            } catch (Exception e) {
                payload = "[decrypt failed]";
            }
        }
        row.put("payload_preview", preview(payload));
        return row;
    }

    /**
     * 단건 조회용: payload 전체 반환.
     */
    private Map<String, Object> mapRowFull(ResultSet rs) throws java.sql.SQLException {
        Map<String, Object> row = new LinkedCaseInsensitiveMap<>();
        row.put("id", rs.getLong("id"));
        row.put("tenant_id", rs.getString("tenant_id"));
        row.put("source", rs.getString("source"));
        row.put("event_type", rs.getString("event_type"));
        row.put("payload_json", rs.getString("payload_json"));
        row.put("payload_sha256", rs.getString("payload_sha256"));
        row.put("received_at", rs.getTimestamp("received_at"));
        row.put("request_id", rs.getString("request_id"));
        row.put("user_id", rs.getString("user_id"));
        row.put("role", rs.getString("role"));
        row.put("payload_enc", rs.getString("payload_enc"));
        row.put("payload_nonce", rs.getString("payload_nonce"));
        row.put("payload_key_id", rs.getString("payload_key_id"));
        row.put("payload_alg", rs.getString("payload_alg"));

        // ADMIN 상세 조회 시 복호화된 페이로드를 함께 제공합니다.
        String cipher = rs.getString("payload_enc");
        String nonce = rs.getString("payload_nonce");
        String keyId = rs.getString("payload_key_id");
        if (cipher != null && nonce != null && keyId != null) {
            try {
                String plain = crypto.decrypt(cipher, nonce, keyId);
                row.put("decrypted_payload", plain);
            } catch (Exception e) {
                row.put("decrypted_payload", null);
                row.put("decrypt_error", e.getMessage());
            }
        }
        return row;
    }

    /**
     * Export용 행 매핑.
     * - 기본은 payload_preview만 제공한다.
     * - includeDecrypted=true일 때만 decrypted_payload를 포함한다.
     */
    private Map<String, Object> mapRowForExport(ResultSet rs, boolean includeDecrypted) throws java.sql.SQLException {
        Map<String, Object> row = new LinkedCaseInsensitiveMap<>();
        row.put("id", rs.getLong("id"));
        row.put("tenant_id", rs.getString("tenant_id"));
        row.put("source", rs.getString("source"));
        row.put("event_type", rs.getString("event_type"));
        row.put("received_at", rs.getTimestamp("received_at"));
        row.put("request_id", rs.getString("request_id"));
        row.put("user_id", rs.getString("user_id"));
        row.put("role", rs.getString("role"));

        String payload = rs.getString("payload_json");
        String decrypted = null;
        if (payload == null && includeDecrypted) {
            String cipher = rs.getString("payload_enc");
            String nonce = rs.getString("payload_nonce");
            String keyId = rs.getString("payload_key_id");
            if (cipher != null && nonce != null && keyId != null) {
                try {
                    decrypted = crypto.decrypt(cipher, nonce, keyId);
                } catch (Exception e) {
                    decrypted = null;
                }
            }
        }

        String previewSource;
        if (payload != null) {
            previewSource = payload;
        } else if (includeDecrypted && decrypted != null) {
            previewSource = decrypted;
        } else {
            previewSource = "[encrypted]";
        }
        row.put("payload_preview", preview(previewSource));

        if (includeDecrypted) {
            row.put("decrypted_payload", decrypted);
        }
        return row;
    }

    private String preview(String payload) {
        if (payload == null) {
            return null;
        }
        return payload.length() <= 200 ? payload : payload.substring(0, 200);
    }
}
