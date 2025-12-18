package kr.co.mes.web;

import static org.hamcrest.Matchers.equalTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 초보자용 상세 주석:
 * - 멀티테넌트 라우팅이 제대로 동작하는지 확인하기 위한 통합 테스트입니다.
 * - 헤더 X-Tenant-Id 값에 따라 DB 이름이 바뀌는지 검증합니다.
 */
@SpringBootTest
@AutoConfigureMockMvc
class TenantDatabaseControllerTest {

    @Autowired
    private MockMvc mockMvc;

    static {
        TestCryptoEnv.ensure();
    }

    @Test
    @DisplayName("헤더 없이 호출하면 기본 테넌트(tenant_a) DB로 라우팅된다")
    void shouldRouteToTenantAByDefault() throws Exception {
        mockMvc.perform(get("/api/tenant/dbname")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tenant", equalTo("tenant_a")))
                .andExpect(jsonPath("$.database", equalTo("mes_tenant_a")));
    }

    @Test
    @DisplayName("헤더에 tenant_b를 주면 tenant_b DB로 라우팅된다")
    void shouldRouteToTenantBWhenHeaderProvided() throws Exception {
        mockMvc.perform(get("/api/tenant/dbname")
                        .header("X-Tenant-Id", "tenant_b")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tenant", equalTo("tenant_b")))
                .andExpect(jsonPath("$.database", equalTo("mes_tenant_b")));
    }

    @Test
    @DisplayName("허용되지 않은 테넌트 값이면 400을 반환한다")
    void shouldRejectInvalidTenantHeader() throws Exception {
        mockMvc.perform(get("/api/tenant/dbname")
                        .header("X-Tenant-Id", "invalid")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest());
    }
}
