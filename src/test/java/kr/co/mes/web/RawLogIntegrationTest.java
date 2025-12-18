package kr.co.mes.web;

import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

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
 * - 원시 로그 저장/조회/보안 제한을 통합으로 검증합니다.
 * - ADMIN과 USER 권한 차이를 확인합니다.
 */
@SpringBootTest
@AutoConfigureMockMvc
class RawLogIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    static {
        TestCryptoEnv.ensure();
    }

    @Test
    @DisplayName("USER는 저장 가능, ADMIN만 조회/상세 가능")
    void userCanIngestAdminCanQuery() throws Exception {
        // USER 로그인
        MvcResult userLogin = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"user\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession userSession = (MockHttpSession) userLogin.getRequest().getSession(false);

        // USER가 원시 로그 저장
        MvcResult ingest = mockMvc.perform(post("/api/ingest/raw")
                        .session(userSession)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"source\":\"test-client\",\"eventType\":\"LOGIN\",\"payload\":{\"foo\":\"bar\"}}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ok", equalTo(true)))
                .andExpect(jsonPath("$.id").exists())
                .andReturn();

        // USER가 관리자 조회 요청 → 403
        mockMvc.perform(get("/api/admin/raw-logs").session(userSession))
                .andExpect(status().isForbidden());

        // ADMIN 로그인
        MvcResult adminLogin = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"admin\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession adminSession = (MockHttpSession) adminLogin.getRequest().getSession(false);

        // ADMIN 목록 조회
        MvcResult listResult = mockMvc.perform(get("/api/admin/raw-logs")
                        .session(adminSession)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.items[0]", hasKey("payload_preview")))
                .andReturn();

        // 목록 첫 번째 id로 상세 조회
        String responseBody = listResult.getResponse().getContentAsString();
        String idStr = responseBody.replaceAll("(?s).*\"id\"\\s*:\\s*(\\d+).*", "$1");
        long id = Long.parseLong(idStr);

        mockMvc.perform(get("/api/admin/raw-logs/{id}", id).session(adminSession))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.payload_json").exists());
    }

    @Test
    @DisplayName("X-Request-Id가 있으면 응답 헤더와 response body에 반영된다")
    void requestIdHeaderPreferred() throws Exception {
        String requestId = "REQ-TEST-001";
        MvcResult userLogin = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"user\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession userSession = (MockHttpSession) userLogin.getRequest().getSession(false);

        mockMvc.perform(post("/api/ingest/raw")
                        .session(userSession)
                        .header("X-Request-Id", requestId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"source\":\"test-client\",\"eventType\":\"PING\",\"payload\":{\"hello\":\"world\"}}"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Request-Id", requestId))
                .andExpect(jsonPath("$.requestId", equalTo(requestId)));
    }

    @Test
    @DisplayName("목록 조회 limit이 200 초과면 400")
    void listLimitGuard() throws Exception {
        MvcResult adminLogin = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"admin\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession adminSession = (MockHttpSession) adminLogin.getRequest().getSession(false);

        mockMvc.perform(get("/api/admin/raw-logs")
                        .session(adminSession)
                        .param("limit", "999"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Export는 7일 초과 범위면 400")
    void exportRangeGuard() throws Exception {
        MvcResult adminLogin = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":\"admin\",\"password\":\"pass\"}"))
                .andExpect(status().isOk())
                .andReturn();
        MockHttpSession adminSession = (MockHttpSession) adminLogin.getRequest().getSession(false);

        OffsetDateTime from = OffsetDateTime.now(ZoneOffset.UTC).minusDays(10);
        OffsetDateTime to = OffsetDateTime.now(ZoneOffset.UTC);

        mockMvc.perform(get("/api/admin/raw-logs/export")
                        .session(adminSession)
                        .param("from", from.toString())
                        .param("to", to.toString()))
                .andExpect(status().isBadRequest());
    }
}
