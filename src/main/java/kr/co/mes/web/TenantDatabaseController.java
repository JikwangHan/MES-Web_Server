package kr.co.mes.web;

import java.util.HashMap;
import java.util.Map;

import jakarta.servlet.http.HttpSession;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import kr.co.mes.support.SessionConstants;
import kr.co.mes.support.TenantContext;

/**
 * 초보자용 상세 주석:
 * - 현재 요청이 연결된 DB 이름을 알려주는 시연용 컨트롤러입니다.
 * - 헤더 X-Tenant-Id 값에 따라 라우팅된 DataSource를 통해 SELECT DATABASE()를 실행합니다.
 * - 멀티테넌트 라우팅이 제대로 동작하는지 눈으로 확인하기 위한 API입니다.
 */
@RestController
@RequestMapping("/api/tenant")
@Profile("local")
public class TenantDatabaseController {

    private final JdbcTemplate jdbcTemplate;

    /**
     * 생성자 주입: 라우팅된 DataSource를 사용하는 JdbcTemplate을 받습니다.
     */
    public TenantDatabaseController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * GET /api/tenant/dbname
     * - SELECT DATABASE() 결과를 JSON으로 반환합니다.
     * - 응답 예: {"tenant":"tenant_b","database":"mes_tenant_b"}
     */
    @GetMapping("/dbname")
    public Map<String, Object> currentDatabase(HttpSession session) {
        String dbName = jdbcTemplate.queryForObject("SELECT DATABASE()", String.class);

        // 세션에 저장된 role/tenant를 함께 내려주어 디버깅에 도움을 줍니다.
        String sessionRole = (String) session.getAttribute(SessionConstants.ATTR_ROLE);
        String sessionTenant = (String) session.getAttribute(SessionConstants.ATTR_TENANT);

        Map<String, Object> body = new HashMap<>();
        body.put("tenant", TenantContext.getTenantIdOrDefault());
        body.put("database", dbName);
        body.put("role", sessionRole == null ? "ANONYMOUS" : sessionRole);
        body.put("sessionTenant", sessionTenant == null ? "N/A" : sessionTenant);
        body.put("source", TenantContext.getSourceOrDefault()); // 테넌트 결정이 어디서 왔는지
        return body;
    }
}
