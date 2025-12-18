package kr.co.mes.service.impl;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

import org.springframework.stereotype.Service;

import kr.co.mes.service.EchoService;

/**
 * 초보자용 상세 주석:
 * - EchoService의 실제 동작을 담당하는 구현 클래스입니다.
 * - 현재 서버 시간을 ISO-8601 문자열로 만들어 함께 돌려줍니다.
 * - 서버 이름은 상수로 관리하여 어디서나 동일한 값을 재사용합니다.
 */
@Service
public class EchoServiceImpl implements EchoService {

    /**
     * 응답에 고정적으로 넣어줄 서버 식별자입니다.
     * - 환경에 따라 변경할 수 있도록 상수로 분리해 두었습니다.
     */
    private static final String SERVER_NAME = "mes-web";

    /**
     * 메시지를 받아 응답 Map을 생성합니다.
     * - 전달된 msg가 null이거나 공백뿐이면 기본 문자열 "hello"를 사용합니다.
     * - ts는 서버 현재 시각을 ISO-8601(Offset 포함) 형식으로 생성합니다.
     * - 최종 Map은 컨트롤러에서 그대로 반환되어 JSON으로 직렬화됩니다.
     *
     * @param msg 사용자가 입력한 메시지
     * @return msg, ts, server 정보를 담은 Map
     */
    @Override
    public Map<String, Object> echo(String msg) {
        Map<String, Object> result = new HashMap<>();

        // 1) 메시지 정리: 비어 있으면 기본값으로 대체
        String safeMsg = (msg == null || msg.isBlank()) ? "hello" : msg;

        // 2) ISO-8601 형식의 시각 문자열 생성 (UTC 기준 Offset 포함)
        String timestamp = OffsetDateTime.now(ZoneOffset.UTC)
                .format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);

        // 3) 응답 Map 구성
        result.put("msg", safeMsg);
        result.put("ts", timestamp);
        result.put("server", SERVER_NAME);

        return result;
    }
}
