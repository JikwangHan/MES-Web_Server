package kr.co.mes.web;

import java.util.Base64;

/**
 * 테스트 실행 전에 AES-GCM 키 환경을 셋업하는 도우미입니다.
 * - 운영에서는 환경변수로 주입하지만, 테스트에서는 System.setProperty로 대체합니다.
 */
public final class TestCryptoEnv {
    private TestCryptoEnv() {}

    public static void ensure() {
        if (System.getProperty("MES_CRYPTO_KEYS") == null && System.getenv("MES_CRYPTO_KEYS") == null) {
            // 32바이트 0 값 키(Base64). 테스트용이므로 단순 값 사용.
            byte[] keyBytes = new byte[32];
            String k = Base64.getEncoder().encodeToString(keyBytes);
            System.setProperty("MES_CRYPTO_KEYS", "v1=" + k + ";v2=" + k);
            System.setProperty("MES_CRYPTO_ACTIVE_KEY_ID", "v1");
            System.setProperty("MES_CRYPTO_ALLOW_PLAINTEXT", "false");
        }
    }
}
