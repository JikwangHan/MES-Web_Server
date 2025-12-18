package kr.co.mes.support;

import java.util.HashMap;
import java.util.Map;

import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 초보자용 상세 주석:
 * - 로컬 프로파일에서만 활성화되는 멀티테넌트 DataSource 설정입니다.
 * - tenant_a, tenant_b 두 개의 DataSource를 만들고, 라우팅 DataSource를 통해
 *   요청 헤더(X-Tenant-Id)에 따라 알맞은 DB로 연결됩니다.
 */
@Configuration
@Profile("local")
public class TenantDataSourceConfig {

    private static final Logger log = LoggerFactory.getLogger(TenantDataSourceConfig.class);

    /**
     * tenant_a용 DataSource를 생성합니다.
     */
    @Bean
    @Qualifier("tenantADataSource")
    public DataSource tenantADataSource() {
        log.info("tenant_a DataSource 생성");
        return DataSourceBuilder.create()
                .url("jdbc:mariadb://localhost:3306/mes_tenant_a")
                .username("mes")
                .password("mes1234!")
                .driverClassName("org.mariadb.jdbc.Driver")
                .build();
    }

    /**
     * tenant_b용 DataSource를 생성합니다.
     */
    @Bean
    @Qualifier("tenantBDataSource")
    public DataSource tenantBDataSource() {
        log.info("tenant_b DataSource 생성");
        return DataSourceBuilder.create()
                .url("jdbc:mariadb://localhost:3306/mes_tenant_b")
                .username("mes")
                .password("mes1234!")
                .driverClassName("org.mariadb.jdbc.Driver")
                .build();
    }

    /**
     * tenant_a 전용 JdbcTemplate (DDL/배치 등에 사용).
     */
    @Bean
    @Qualifier("tenantAJdbcTemplate")
    public JdbcTemplate tenantAJdbcTemplate(@Qualifier("tenantADataSource") DataSource ds) {
        return new JdbcTemplate(ds);
    }

    /**
     * tenant_b 전용 JdbcTemplate (DDL/배치 등에 사용).
     */
    @Bean
    @Qualifier("tenantBJdbcTemplate")
    public JdbcTemplate tenantBJdbcTemplate(@Qualifier("tenantBDataSource") DataSource ds) {
        return new JdbcTemplate(ds);
    }

    /**
     * 요청별 테넌트에 따라 DataSource를 라우팅합니다.
     * - @Primary로 지정해 기본 DataSource로 사용되도록 합니다.
     */
    @Bean
    @Primary
    public DataSource dataSource(
            @Qualifier("tenantADataSource") DataSource tenantADataSource,
            @Qualifier("tenantBDataSource") DataSource tenantBDataSource) {

        Map<Object, Object> targetDataSources = new HashMap<>();
        targetDataSources.put("tenant_a", tenantADataSource);
        targetDataSources.put("tenant_b", tenantBDataSource);

        MultiTenantRoutingDataSource routingDataSource = new MultiTenantRoutingDataSource();
        routingDataSource.setTargetDataSources(targetDataSources);
        routingDataSource.setDefaultTargetDataSource(tenantADataSource);
        routingDataSource.afterPropertiesSet();

        return routingDataSource;
    }

    /**
     * JdbcTemplate을 라우팅 DataSource 기반으로 제공합니다.
     * - 컨트롤러에서 SQL을 간단히 실행하기 위해 사용합니다.
     */
    @Bean
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
