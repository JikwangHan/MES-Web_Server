package kr.co.mes.support;

/**
 * 초보자용 상세 주석:
 * - 현재 요청이 어떤 테넌트(기업)인지 ThreadLocal에 보관하는 도우미입니다.
 * - 헤더(X-Tenant-Id)를 읽은 필터가 이 컨텍스트에 테넌트 ID를 저장하고,
 *   요청 처리가 끝나면 반드시 clear()로 비워줍니다.
 */
public final class TenantContext {

    /**
     * 기본 테넌트: 헤더가 없을 때 fallback으로 사용합니다.
     */
    public static final String DEFAULT_TENANT = "tenant_a";

    /**
     * 허용 가능한 테넌트 값 배열(간단한 검증용).
     */
    public static final String[] ALLOWED_TENANTS = {"tenant_a", "tenant_b"};

    /**
     * 요청 스레드마다 테넌트 ID를 보관하는 ThreadLocal.
     */
    private static final ThreadLocal<String> TENANT_HOLDER = new ThreadLocal<>();

    /**
     * 테넌트 결정이 어디서 왔는지(세션/헤더/기본값 등) 기록하는 ThreadLocal.
     * - 디버깅과 로그 분석을 돕기 위한 용도입니다.
     */
    private static final ThreadLocal<String> SOURCE_HOLDER = new ThreadLocal<>();

    private TenantContext() {
    }

    /**
     * 현재 테넌트 ID를 설정합니다.
     */
    public static void setTenantId(String tenantId) {
        TENANT_HOLDER.set(tenantId);
    }

    /**
     * 테넌트 ID와 결정 소스를 함께 설정합니다.
     */
    public static void setTenant(String tenantId, String source) {
        TENANT_HOLDER.set(tenantId);
        SOURCE_HOLDER.set(source);
    }

    /**
     * 현재 테넌트 ID를 조회합니다. 없으면 기본값을 반환합니다.
     */
    public static String getTenantIdOrDefault() {
        String tenant = TENANT_HOLDER.get();
        return (tenant == null || tenant.isBlank()) ? DEFAULT_TENANT : tenant;
    }

    /**
     * 테넌트 결정 소스를 조회합니다. 없으면 "default"를 반환합니다.
     */
    public static String getSourceOrDefault() {
        String source = SOURCE_HOLDER.get();
        return (source == null || source.isBlank()) ? "default" : source;
    }

    /**
     * ThreadLocal에 저장된 테넌트 ID를 제거합니다.
     * - 요청 처리 후 메모리 누수를 막기 위해 반드시 호출합니다.
     */
    public static void clear() {
        TENANT_HOLDER.remove();
        SOURCE_HOLDER.remove();
    }

    /**
     * 주어진 값이 허용 테넌트인지 간단히 검사합니다.
     */
    public static boolean isAllowedTenant(String tenantId) {
        if (tenantId == null || tenantId.isBlank()) {
            return true; // null/빈 값은 기본 테넌트로 처리 가능
        }
        for (String allowed : ALLOWED_TENANTS) {
            if (allowed.equals(tenantId)) {
                return true;
            }
        }
        return false;
    }
}
