package kr.co.mes.support;

import java.io.IOException;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.context.annotation.Profile;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import kr.co.mes.support.SessionConstants;

/**
 * 초보자용 상세 주석:
 * - HTTP 요청마다 헤더(X-Tenant-Id)를 읽어서 TenantContext에 테넌트 ID를 보관합니다.
 * - 허용되지 않은 테넌트 값이면 400 Bad Request로 즉시 응답합니다.
 * - 요청 처리가 끝나면 반드시 clear()로 ThreadLocal을 비워 메모리 누수를 막습니다.
 */
@Component
@Profile("local")
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class TenantFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(TenantFilter.class);
    private static final String HEADER_TENANT = "X-Tenant-Id"; // 개발 편의용 (prod에서는 비활성 권장)
    private static final String HEADER_TENANT_OVERRIDE = "X-Tenant-Id-Override"; // ADMIN만 임시 사용 허용

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        // 0) 세션에서 role/tenant를 우선적으로 확인
        var session = request.getSession(false);
        String sessionRole = null;
        String sessionTenant = null;
        if (session != null) {
            sessionRole = (String) session.getAttribute(SessionConstants.ATTR_ROLE);
            sessionTenant = (String) session.getAttribute(SessionConstants.ATTR_TENANT);
        }

        // 1) ADMIN이 세션에 있을 때만 override 헤더 사용 가능 (옵션)
        String overrideTenant = null;
        if ("ADMIN".equalsIgnoreCase(sessionRole)) {
            overrideTenant = request.getHeader(HEADER_TENANT_OVERRIDE);
        }

        // 2) 개발 편의용 기본 헤더(로컬에서만) - prod에서는 끄는 것을 권장
        String devHeaderTenant = request.getHeader(HEADER_TENANT);

        // 3) 우선순위에 따라 테넌트를 결정
        String chosenTenant;
        String source;

        if (isNotBlank(sessionTenant)) {
            chosenTenant = sessionTenant;
            source = "session";
        } else if (isNotBlank(overrideTenant)) {
            chosenTenant = overrideTenant;
            source = "admin-override";
        } else if (isNotBlank(devHeaderTenant)) {
            chosenTenant = devHeaderTenant;
            source = "header";
        } else {
            chosenTenant = TenantContext.DEFAULT_TENANT;
            source = "default";
        }

        // 4) 허용 테넌트 검증: tenant_a, tenant_b 외에는 400
        if (!TenantContext.isAllowedTenant(chosenTenant)) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"error\":\"invalid tenant\",\"allowed\":[\"tenant_a\",\"tenant_b\"]}");
            log.warn("잘못된 테넌트 값 감지 - tenant={}, remoteAddr={}", chosenTenant, request.getRemoteAddr());
            return;
        }

        // 5) ThreadLocal에 테넌트와 소스 저장 + MDC에 tenant_id 기록
        TenantContext.setTenant(chosenTenant, source);
        MDC.put("tenant_id", chosenTenant);

        try {
            filterChain.doFilter(request, response);
        } finally {
            // 6) 요청 완료 후 꼭 비워서 메모리 누수, 교차 요청 오염 방지
            TenantContext.clear();
        }
    }

    private boolean isNotBlank(String value) {
        return value != null && !value.isBlank();
    }
}
