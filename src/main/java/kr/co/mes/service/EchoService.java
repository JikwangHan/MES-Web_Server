package kr.co.mes.service;

import java.util.Map;

/**
 * 초보자용 상세 주석:
 * - 컨트롤러가 사용할 에코 기능의 계약을 정의하는 인터페이스입니다.
 * - 구현체를 분리해두면 필요할 때 다른 구현으로 교체하거나 테스트용 목 객체를 주입하기 쉽습니다.
 */
public interface EchoService {

    /**
     * 전달받은 메시지를 그대로 담아서 응답용 Map을 만들어 반환합니다.
     * - msg가 비어 있으면 내부에서 기본값을 적용할 수 있도록 구현체에 맡깁니다.
     * - 반환되는 Map은 JSON으로 직렬화되어 클라이언트에 전송됩니다.
     *
     * @param msg 사용자가 보낸 메시지 문자열
     * @return msg, 서버 이름, 현재 시간을 담은 Map
     */
    Map<String, Object> echo(String msg);
}
