package kr.co.mes.support;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * 초보자용 상세 주석:
 * - 애플리케이션 기동 시 테넌트 DB마다 원시 로그 테이블(raw_ingest_log)을 생성합니다.
 * - CREATE TABLE IF NOT EXISTS와 인덱스 생성으로 여러 번 실행되어도 안전합니다.
 */
@Component
@Profile("local")
public class RawLogTableInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(RawLogTableInitializer.class);

    private final JdbcTemplate tenantAJdbcTemplate;
    private final JdbcTemplate tenantBJdbcTemplate;

    public RawLogTableInitializer(
            @Qualifier("tenantAJdbcTemplate") JdbcTemplate tenantAJdbcTemplate,
            @Qualifier("tenantBJdbcTemplate") JdbcTemplate tenantBJdbcTemplate) {
        this.tenantAJdbcTemplate = tenantAJdbcTemplate;
        this.tenantBJdbcTemplate = tenantBJdbcTemplate;
    }

    @Override
    public void run(ApplicationArguments args) {
        createTable(tenantAJdbcTemplate, "tenant_a");
        createTable(tenantBJdbcTemplate, "tenant_b");
    }

    private void createTable(JdbcTemplate jdbcTemplate, String tenantName) {
        // 테이블 생성
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS raw_ingest_log (
                  id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  tenant_id VARCHAR(50),
                  source VARCHAR(50),
                  event_type VARCHAR(80),
                  payload_json LONGTEXT,
                  payload_enc LONGTEXT,
                  payload_nonce VARCHAR(32),
                  payload_key_id VARCHAR(20),
                  payload_alg VARCHAR(20),
                  payload_sha256 CHAR(64),
                  received_at TIMESTAMP(6),
                  request_id VARCHAR(64),
                  user_id VARCHAR(50),
                  role VARCHAR(20)
                )
                """);
        // 기존 테이블에 없을 수 있는 컬럼을 추가합니다.
        jdbcTemplate.execute("ALTER TABLE raw_ingest_log ADD COLUMN IF NOT EXISTS payload_enc LONGTEXT");
        jdbcTemplate.execute("ALTER TABLE raw_ingest_log ADD COLUMN IF NOT EXISTS payload_nonce VARCHAR(32)");
        jdbcTemplate.execute("ALTER TABLE raw_ingest_log ADD COLUMN IF NOT EXISTS payload_key_id VARCHAR(20)");
        jdbcTemplate.execute("ALTER TABLE raw_ingest_log ADD COLUMN IF NOT EXISTS payload_alg VARCHAR(20)");
        // 인덱스 생성 (없으면 생성, 이미 있으면 무시)
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_raw_log_received_at ON raw_ingest_log(received_at)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_raw_log_event_time ON raw_ingest_log(event_type, received_at)");
        log.info("raw_ingest_log 테이블 준비 완료 - tenant={}", tenantName);
    }
}
