package kr.co.mes.web;

import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import kr.co.mes.service.EchoService;

/**
 * 초보자용 상세 주석:
 * - 이 클래스는 /api/echo 경로로 들어온 HTTP GET 요청을 받아 그대로 응답하는 가장 단순한 컨트롤러입니다.
 * - 웹 요청을 받아서 내부 서비스(EchoService)를 호출하고, JSON 형태로 돌려주는 역할만 담당합니다.
 * - 스프링이 자동으로 UTF-8로 인코딩/디코딩하므로 한글 쿼리 파라미터도 깨지지 않고 전달됩니다.
 */
@RestController
@RequestMapping("/api")
public class HealthEchoController {

    /**
     * 서비스 객체를 스프링이 주입합니다.
     * - 컨트롤러는 로직을 직접 처리하지 않고 서비스에 위임하여 가독성과 재사용성을 높입니다.
     */
    private final EchoService echoService;

    /**
     * 생성자에서 EchoService를 받아 필드에 저장합니다.
     * - 스프링이 자동으로 구현체(EchoServiceImpl)를 찾아서 넣어줍니다.
     */
    public HealthEchoController(EchoService echoService) {
        this.echoService = echoService;
    }

    /**
     * /api/echo GET 요청을 처리합니다.
     * - msg 쿼리 파라미터를 읽어서 그대로 응답에 실어 보냅니다.
     * - msg가 없거나 비어 있으면 기본값 "hello"를 사용합니다.
     * - 응답 형태: {"msg": "...", "ts": "ISO-8601", "server": "mes-web"}
     *
     * @param msg 사용자가 보낸 문자열 메시지(없으면 기본값 사용)
     * @return 서비스가 만든 응답 Map을 그대로 반환하면 스프링이 JSON으로 직렬화합니다.
     */
    @GetMapping(value = "/echo", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> echo(@RequestParam(name = "msg", required = false, defaultValue = "hello") String msg) {
        // 서비스에게 실제 데이터 구성을 맡기고, 컨트롤러는 입·출력만 담당합니다.
        return echoService.echo(msg);
    }
}
