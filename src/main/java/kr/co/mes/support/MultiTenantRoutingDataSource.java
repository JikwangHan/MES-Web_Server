package kr.co.mes.support;

import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;

/**
 * 초보자용 상세 주석:
 * - Spring의 AbstractRoutingDataSource를 상속해 현재 테넌트에 맞는 DataSource를 선택합니다.
 * - determineCurrentLookupKey()에서 TenantContext에 저장된 테넌트 ID를 반환하고,
 *   해당 키에 매핑된 실제 DataSource가 사용됩니다.
 */
public class MultiTenantRoutingDataSource extends AbstractRoutingDataSource {

    @Override
    protected Object determineCurrentLookupKey() {
        // ThreadLocal에 보관된 테넌트 ID를 조회하고, 없으면 기본 테넌트를 사용합니다.
        return TenantContext.getTenantIdOrDefault();
    }
}
