package kr.co.mes.web;

import java.util.HashMap;
import java.util.Map;

import jakarta.servlet.http.HttpSession;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import kr.co.mes.support.SessionConstants;
import kr.co.mes.support.TenantContext;

/**
 * 초보자용 상세 주석:
 * - 관리자만 테넌트를 변경할 수 있는 API입니다.
 * - 세션 role이 ADMIN인지 확인하고, 허용된 테넌트만 세션에 저장합니다.
 */
@RestController
@RequestMapping(path = "/api/admin/tenant", produces = MediaType.APPLICATION_JSON_VALUE)
public class AdminTenantController {

    /**
     * 테넌트 선택 요청 DTO.
     */
    public record TenantSelectRequest(String tenant) {}

    /**
     * POST /api/admin/tenant/select
     * - ADMIN 권한만 허용
     * - 입력 테넌트가 허용 목록에 있으면 세션 테넌트를 변경합니다.
     */
    @PostMapping("/select")
    public ResponseEntity<?> selectTenant(@RequestBody TenantSelectRequest request, HttpSession session) {
        Map<String, Object> body = new HashMap<>();

        String role = (String) session.getAttribute(SessionConstants.ATTR_ROLE);
        if (!"ADMIN".equalsIgnoreCase(role)) {
            body.put("ok", false);
            body.put("error", "forbidden");
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(body);
        }

        String tenant = request.tenant();
        if (!TenantContext.isAllowedTenant(tenant)) {
            body.put("ok", false);
            body.put("error", "invalid tenant");
            body.put("allowed", TenantContext.ALLOWED_TENANTS);
            return ResponseEntity.badRequest().body(body);
        }

        session.setAttribute(SessionConstants.ATTR_TENANT, tenant);
        body.put("ok", true);
        body.put("tenant", tenant);
        return ResponseEntity.ok(body);
    }
}
