package kr.co.mes.crypto;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 초보자용 상세 주석:
 * - 환경변수/시스템프로퍼티에서 AES 키 목록을 읽어 keyId -> SecretKey 매핑을 만듭니다.
 * - 포맷: MES_CRYPTO_KEYS = "v1=BASE64;v2=BASE64"
 * - 활성 키 ID: MES_CRYPTO_ACTIVE_KEY_ID (없으면 첫 번째 키 사용)
 * - 평문 저장 허용: MES_CRYPTO_ALLOW_PLAINTEXT (기본 false)
 */
@Component
public class CryptoKeyRegistry {

    private static final Logger log = LoggerFactory.getLogger(CryptoKeyRegistry.class);

    private final Map<String, SecretKey> keyMap;
    private final String activeKeyId;
    private final boolean allowPlaintext;

    public CryptoKeyRegistry() {
        this.keyMap = loadKeys();
        this.activeKeyId = resolveActiveKeyId(keyMap.keySet());
        this.allowPlaintext = resolveAllowPlaintext();

        log.info("CryptoKeyRegistry 초기화 - keyIds={}, activeKeyId={}, allowPlaintext={}",
                keyMap.keySet(), activeKeyId, allowPlaintext);
    }

    /**
     * 활성 키 ID 반환.
     */
    public String getActiveKeyId() {
        return activeKeyId;
    }

    /**
     * 평문 저장 허용 여부 반환.
     */
    public boolean isAllowPlaintext() {
        return allowPlaintext;
    }

    /**
     * keyId로 SecretKey 조회.
     */
    public SecretKey getKey(String keyId) {
        SecretKey key = keyMap.get(keyId);
        if (key == null) {
            throw new IllegalArgumentException("키를 찾을 수 없습니다: " + keyId);
        }
        return key;
    }

    private Map<String, SecretKey> loadKeys() {
        String raw = readEnvOrProp("MES_CRYPTO_KEYS");
        if (raw == null || raw.isBlank()) {
            throw new IllegalStateException("환경변수 MES_CRYPTO_KEYS가 없습니다. 예) v1=BASE64;v2=BASE64");
        }
        Map<String, SecretKey> map = new HashMap<>();
        String[] pairs = raw.split(";");
        for (String pair : pairs) {
            if (pair.isBlank()) continue;
            String[] kv = pair.split("=");
            if (kv.length != 2) {
                throw new IllegalStateException("MES_CRYPTO_KEYS 형식 오류: " + pair);
            }
            String id = kv[0].trim();
            String b64 = kv[1].trim();
            byte[] keyBytes = Base64.getDecoder().decode(b64);
            if (keyBytes.length != 32) {
                throw new IllegalStateException("키 길이가 32바이트가 아닙니다. keyId=" + id);
            }
            SecretKey key = new SecretKeySpec(keyBytes, "AES");
            map.put(id, key);
        }
        if (map.isEmpty()) {
            throw new IllegalStateException("MES_CRYPTO_KEYS에 유효한 키가 없습니다.");
        }
        return Collections.unmodifiableMap(map);
    }

    private String resolveActiveKeyId(Set<String> keyIds) {
        String active = readEnvOrProp("MES_CRYPTO_ACTIVE_KEY_ID");
        if (active != null && keyIds.contains(active)) {
            return active;
        }
        // 기본: 첫 번째 키 사용
        return keyIds.iterator().next();
    }

    private boolean resolveAllowPlaintext() {
        String flag = readEnvOrProp("MES_CRYPTO_ALLOW_PLAINTEXT");
        if (flag == null) return false;
        return flag.equalsIgnoreCase("true") || flag.equalsIgnoreCase("1") || flag.equalsIgnoreCase("yes");
    }

    /**
     * 환경변수 우선, 없으면 시스템 프로퍼티에서 읽습니다.
     * - 테스트에서 System.setProperty로 주입 가능하게 함.
     */
    private String readEnvOrProp(String name) {
        String env = System.getenv(name);
        if (env != null && !env.isBlank()) {
            return env;
        }
        String prop = System.getProperty(name);
        return (prop == null || prop.isBlank()) ? null : prop;
    }

    /**
     * 테스트 편의를 위해 32바이트 랜덤 키(Base64)를 생성하는 유틸(운영에서는 사용 안 함).
     */
    public static String generateRandomBase64Key() {
        byte[] b = new byte[32];
        new SecureRandom().nextBytes(b);
        return Base64.getEncoder().encodeToString(b);
    }

    /**
     * 암호문/nonce/keyId/알고리즘을 함께 보관하기 위한 DTO.
     */
    public record EncryptedPayload(String cipherTextBase64, String nonceBase64, String keyId, String alg) {}
}
