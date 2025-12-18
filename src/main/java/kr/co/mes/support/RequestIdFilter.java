package kr.co.mes.support;

import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 초보자용 상세 주석:
 * - 모든 요청에 대해 request_id를 만들고 응답 헤더에도 심어줍니다.
 * - 이미 X-Request-Id가 있으면 안전한 형식인지 확인한 뒤 사용합니다.
 * - 로그 MDC에 request_id, user_id, role을 넣어 추적성을 높입니다.
 * - 요청이 끝나면 반드시 MDC/ThreadLocal을 비웁니다.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

    private static final String HEADER_REQUEST_ID = "X-Request-Id";
    private static final Pattern SAFE = Pattern.compile("^[A-Za-z0-9\\-_.]{1,64}$");

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        // 1) 요청 헤더에서 request_id를 읽고, 안전한 형식인지 검사한다.
        String header = request.getHeader(HEADER_REQUEST_ID);
        String requestId = (header != null && SAFE.matcher(header).matches())
                ? header
                : UUID.randomUUID().toString();

        // 2) ThreadLocal과 MDC에 저장한다.
        RequestIdContext.set(requestId);
        MDC.put("request_id", requestId);

        // 3) 세션 사용자 정보도 MDC에 함께 넣어 로그 추적을 쉽게 한다.
        HttpSession session = request.getSession(false);
        String userId = session == null ? null : (String) session.getAttribute(SessionConstants.ATTR_USER_ID);
        String role = session == null ? null : (String) session.getAttribute(SessionConstants.ATTR_ROLE);
        if (userId != null) {
            MDC.put("user_id", userId);
        }
        if (role != null) {
            MDC.put("role", role);
        }

        // 4) 응답 헤더에 request_id를 심어 클라이언트가 추적할 수 있게 한다.
        response.setHeader(HEADER_REQUEST_ID, requestId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            // 5) 요청 종료 시 MDC/ThreadLocal을 비운다.
            MDC.clear();
            RequestIdContext.clear();
        }
    }
}
