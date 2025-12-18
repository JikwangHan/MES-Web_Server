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
 * - 가장 단순한 세션 기반 로그인/로그아웃을 제공합니다.
 * - userId/password가 일치하면 세션에 role, tenantId를 저장합니다.
 * - 실제 서비스에서는 비밀번호 해시, JWT, CSRF 등 보안 요소를 더해야 합니다.
 */
@RestController
@RequestMapping(path = "/api/auth", produces = MediaType.APPLICATION_JSON_VALUE)
public class AuthController {

    /**
     * 로그인 요청 DTO: userId, password만 받습니다.
     */
    public record LoginRequest(String userId, String password) {}

    /**
     * POST /api/auth/login
     * - 허용 계정: admin/pass (ADMIN), user/pass (USER)
     * - 성공 시 세션에 role, tenantId(기본 tenant_a)를 저장합니다.
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request, HttpSession session) {
        Map<String, Object> body = new HashMap<>();

        String role = authenticate(request.userId(), request.password());
        if (role == null) {
            body.put("ok", false);
            body.put("error", "invalid credentials");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(body);
        }

        session.setAttribute(SessionConstants.ATTR_ROLE, role);
        session.setAttribute(SessionConstants.ATTR_TENANT, TenantContext.DEFAULT_TENANT);
        session.setAttribute(SessionConstants.ATTR_USER_ID, request.userId());

        body.put("ok", true);
        body.put("role", role);
        body.put("tenant", TenantContext.DEFAULT_TENANT);
        body.put("userId", request.userId());
        return ResponseEntity.ok(body);
    }

    /**
     * POST /api/auth/logout
     * - 현재 세션을 무효화하여 로그아웃합니다.
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout(HttpSession session) {
        session.invalidate();
        Map<String, Object> body = new HashMap<>();
        body.put("ok", true);
        return ResponseEntity.ok(body);
    }

    /**
     * 아주 단순한 인증 로직 (데모용).
     * - admin/pass → ADMIN
     * - user/pass  → USER
     * - 그 외 → null (실패)
     */
    private String authenticate(String userId, String password) {
        if ("admin".equalsIgnoreCase(userId) && "pass".equals(password)) {
            return "ADMIN";
        }
        if ("user".equalsIgnoreCase(userId) && "pass".equals(password)) {
            return "USER";
        }
        return null;
    }
}
