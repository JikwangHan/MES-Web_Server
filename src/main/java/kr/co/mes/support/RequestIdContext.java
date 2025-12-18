package kr.co.mes.support;

import java.util.UUID;

/**
 * 초보자용 상세 주석:
 * - 요청 하나마다 고유한 request_id를 저장해 두는 공간입니다.
 * - ThreadLocal을 사용하므로 같은 요청 처리 흐름 안에서만 값이 유지됩니다.
 * - 요청이 끝나면 반드시 clear()로 비워야 메모리 누수를 막을 수 있습니다.
 */
public final class RequestIdContext {
    private static final ThreadLocal<String> REQUEST_ID = new ThreadLocal<>();

    private RequestIdContext() {}

    /**
     * 현재 요청의 request_id를 저장합니다.
     */
    public static void set(String requestId) {
        REQUEST_ID.set(requestId);
    }

    /**
     * 현재 요청의 request_id를 가져옵니다.
     */
    public static String get() {
        return REQUEST_ID.get();
    }

    /**
     * request_id가 없으면 새로 생성하고 반환합니다.
     */
    public static String getOrCreate() {
        String current = REQUEST_ID.get();
        if (current == null || current.isBlank()) {
            current = UUID.randomUUID().toString();
            REQUEST_ID.set(current);
        }
        return current;
    }

    /**
     * 요청이 끝났을 때 값을 비웁니다.
     */
    public static void clear() {
        REQUEST_ID.remove();
    }
}
