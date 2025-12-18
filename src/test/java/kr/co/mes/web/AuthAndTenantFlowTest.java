package kr.co.mes.web;

import static org.hamcrest.Matchers.equalTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 초보자용 상세 주석:
 * - 세션 기반 테넌트 강제 및 관리자 테넌트 변경 흐름을 검증하는 통합 테스트입니다.
 * - USER는 헤더로 테넌트를 바꿀 수 없고, ADMIN만 API로 변경 가능한지 확인합니다.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AuthAndTenantFlowTest {

    @Autowired
    private MockMvc mockMvc;

    static {
        TestCryptoEnv.ensure();
    }

    @Test
    @DisplayName("로그인 없이 호출하면 기본 테넌트 tenant_a가 사용된다")
    void anonymousUsesDefaultTenant() throws Exception {
        mockMvc.perform(get("/api/tenant/dbname").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tenant", equalTo("tenant_a")))
                .andExpect(jsonPath("$.source", equalTo("default")));
    }

    @Test
    @DisplayName("USER는 헤더로 테넌트를 바꿀 수 없다 (세션의 tenant_a 유지)")
    void userCannotChangeTenantWithHeader() throws Exception {
        // 1) USER 로그인
        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"user\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession session = (MockHttpSession) login.getRequest().getSession(false);

        // 2) 헤더로 tenant_b를 보내더라도 세션의 tenant_a가 유지
        mockMvc.perform(get("/api/tenant/dbname")
                        .session(session)
                        .header("X-Tenant-Id", "tenant_b")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tenant", equalTo("tenant_a")))
                .andExpect(jsonPath("$.source", equalTo("session")));
    }

    @Test
    @DisplayName("ADMIN은 API로 테넌트를 tenant_b로 변경할 수 있다")
    void adminCanSelectTenantB() throws Exception {
        // 1) ADMIN 로그인
        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"admin\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession session = (MockHttpSession) login.getRequest().getSession(false);

        // 2) ADMIN이 테넌트 선택 API 호출
        mockMvc.perform(post("/api/admin/tenant/select")
                        .session(session)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"tenant\":\"tenant_b\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ok", equalTo(true)))
                .andExpect(jsonPath("$.tenant", equalTo("tenant_b")));

        // 3) 이후 요청에서 tenant_b로 적용되었는지 확인
        mockMvc.perform(get("/api/tenant/dbname")
                        .session(session)
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tenant", equalTo("tenant_b")))
                .andExpect(jsonPath("$.source", equalTo("session")));
    }
}
