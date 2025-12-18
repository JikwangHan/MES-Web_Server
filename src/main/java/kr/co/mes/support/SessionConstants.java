package kr.co.mes.support;

/**
 * 세션에 저장하는 키 이름을 모아두는 상수 클래스입니다.
 * - 초보자도 오타 없이 재사용할 수 있도록 중앙에서 관리합니다.
 */
public final class SessionConstants {
    private SessionConstants() {}

    /**
     * 세션에 저장되는 역할 정보(Admin/User 구분).
     */
    public static final String ATTR_ROLE = "role";

    /**
     * 세션에 저장되는 테넌트 ID.
     */
    public static final String ATTR_TENANT = "tenantId";

    /**
        * 세션에 저장되는 사용자 ID.
        */
    public static final String ATTR_USER_ID = "userId";
}
