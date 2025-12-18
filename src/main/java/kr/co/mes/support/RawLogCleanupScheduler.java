package kr.co.mes.support;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 초보자용 상세 주석:
 * - 매일 새벽 02:10에 30일 지난 원시 로그를 삭제합니다.
 * - tenant_a, tenant_b 두 DB에 대해 각각 수행합니다.
 */
@Component
@Profile("local")
public class RawLogCleanupScheduler {

    private static final Logger log = LoggerFactory.getLogger(RawLogCleanupScheduler.class);

    private final JdbcTemplate tenantAJdbcTemplate;
    private final JdbcTemplate tenantBJdbcTemplate;

    public RawLogCleanupScheduler(
            @Qualifier("tenantAJdbcTemplate") JdbcTemplate tenantAJdbcTemplate,
            @Qualifier("tenantBJdbcTemplate") JdbcTemplate tenantBJdbcTemplate) {
        this.tenantAJdbcTemplate = tenantAJdbcTemplate;
        this.tenantBJdbcTemplate = tenantBJdbcTemplate;
    }

    /**
     * 매일 02:10 실행 (초 분 시 일 월 요일).
     */
    @Scheduled(cron = "0 10 2 * * *")
    public void cleanup() {
        OffsetDateTime cutoff = OffsetDateTime.now(ZoneOffset.UTC).minusDays(30);
        int deletedA = deleteOld(tenantAJdbcTemplate, "tenant_a", cutoff);
        int deletedB = deleteOld(tenantBJdbcTemplate, "tenant_b", cutoff);
        log.info("원시 로그 정리 완료 - cutoff={}, tenant_a deleted={}, tenant_b deleted={}", cutoff, deletedA, deletedB);
    }

    private int deleteOld(JdbcTemplate jdbcTemplate, String tenantName, OffsetDateTime cutoff) {
        return jdbcTemplate.update("DELETE FROM raw_ingest_log WHERE received_at < ?", java.sql.Timestamp.from(cutoff.toInstant()));
    }
}
