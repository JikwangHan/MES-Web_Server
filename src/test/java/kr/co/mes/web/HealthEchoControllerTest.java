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
 * - 실제 서버를 띄우지 않고 MockMvc로 /api/echo 엔드포인트를 호출해 보는 통합 테스트입니다.
 * - 스프링 애플리케이션 컨텍스트가 정상 구동되는지, 그리고 HTTP 200 응답을 주는지 확인합니다.
 */
@SpringBootTest
@AutoConfigureMockMvc
class HealthEchoControllerTest {

    static {
        TestCryptoEnv.ensure();
    }

    /**
     * MockMvc는 가짜 HTTP 요청을 만들어 컨트롤러를 직접 호출할 수 있는 도구입니다.
     * - @Autowired를 통해 스프링이 준비해 둔 MockMvc 인스턴스를 주입받습니다.
     */
    @Autowired
    private MockMvc mockMvc;

    /**
     * /api/echo?msg=테스트 요청을 보내고 정상 응답이 오는지 확인합니다.
     * - status().isOk(): HTTP 200 여부를 검증합니다.
     * - jsonPath("$.msg"): 응답 JSON의 msg 필드가 기대값과 같은지 확인합니다.
     *
     * @throws Exception MockMvc 수행 중 checked 예외가 발생할 수 있어 선언합니다.
     */
    @Test
    @DisplayName("/api/echo 호출 시 입력 메시지를 그대로 반환한다")
    void shouldReturnEchoWithCustomMessage() throws Exception {
        mockMvc.perform(get("/api/echo")
                        .param("msg", "테스트")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.msg", equalTo("테스트")));
    }
}
