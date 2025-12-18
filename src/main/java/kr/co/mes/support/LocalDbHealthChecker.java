package kr.co.mes.support;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 초보자용 상세 주석:
 * - 로컬 프로파일에서만 동작하는 DB 연결 점검 러너입니다.
 * - 테넌트가 2개이므로 tenant_a, tenant_b 두 데이터소스 모두에 대해 "SELECT 1"을 실행해 봅니다.
 * - 성공하면 URL과 사용자 정보를 로그로 남기고, 실패하면 가능한 원인을 한글로 안내합니다.
 */
@Component
@Profile("local")
public class LocalDbHealthChecker implements ApplicationRunner {

    /**
     * SLF4J 로거: 콘솔/파일 로그로 메시지를 남기기 위해 사용합니다.
     */
    private static final Logger log = LoggerFactory.getLogger(LocalDbHealthChecker.class);

    /**
     * 테넌트 A용 데이터소스 (기본 테넌트).
     */
    private final DataSource tenantADataSource;

    /**
     * 테넌트 B용 데이터소스.
     */
    private final DataSource tenantBDataSource;

    /**
     * 생성자 주입: 두 데이터소스를 받아 필드에 저장합니다.
     */
    public LocalDbHealthChecker(
            @Qualifier("tenantADataSource") DataSource tenantADataSource,
            @Qualifier("tenantBDataSource") DataSource tenantBDataSource) {
        this.tenantADataSource = tenantADataSource;
        this.tenantBDataSource = tenantBDataSource;
    }

    /**
     * 애플리케이션이 시작될 때 한 번 실행됩니다.
     * - 각 테넌트 데이터소스에 대해 "SELECT 1 AS ok"로 연결 가능 여부를 확인합니다.
     *
     * @param args 애플리케이션 인자 (사용하지 않음)
     */
    @Override
    public void run(ApplicationArguments args) {
        checkTenant("tenant_a", tenantADataSource);
        checkTenant("tenant_b", tenantBDataSource);
    }

    /**
     * 지정된 테넌트 데이터소스에 대해 SELECT 1을 실행하여 연결을 확인합니다.
     */
    private void checkTenant(String tenantId, DataSource ds) {
        try (Connection conn = ds.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT 1 AS ok");
             ResultSet rs = ps.executeQuery()) {

            String url = conn.getMetaData().getURL();
            String user = conn.getMetaData().getUserName();

            if (rs.next() && rs.getInt("ok") == 1) {
                log.info("DB 연결 점검 성공 - tenant={}, url={}, user={}", tenantId, url, user);
            } else {
                log.warn("DB 연결 점검 실패 - tenant={}, SELECT 1 결과가 예상과 다릅니다. url={}, user={}", tenantId, url, user);
            }
        } catch (Exception e) {
            log.error("DB 연결 점검 실패 - tenant={}, 원인 후보: 컨테이너 미기동, 포트(3306/13306) 점유, 계정/DB명 오타, 방화벽 차단. 상세: {}", tenantId, e.getMessage(), e);
        }
    }
}
