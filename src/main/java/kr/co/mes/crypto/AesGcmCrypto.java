package kr.co.mes.crypto;

import java.security.SecureRandom;
import java.util.Base64;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import org.springframework.stereotype.Component;

/**
 * 초보자용 상세 주석:
 * - AES-GCM(256bit) 암복호화를 수행하는 유틸입니다.
 * - nonce는 12바이트 랜덤, 암호문은 Base64로 반환합니다.
 */
@Component
public class AesGcmCrypto {

    private static final String ALG = "AES/GCM/NoPadding";
    private static final int TAG_BIT_LENGTH = 128; // GCM 인증 태그 128bit
    private static final int NONCE_LENGTH = 12;    // 12바이트 권장

    private final SecureRandom secureRandom = new SecureRandom();
    private final CryptoKeyRegistry keyRegistry;

    public AesGcmCrypto(CryptoKeyRegistry keyRegistry) {
        this.keyRegistry = keyRegistry;
    }

    /**
     * 평문을 AES-GCM으로 암호화합니다.
     * @param plain 평문
     * @param keyId 사용할 키 ID
     */
    public CryptoKeyRegistry.EncryptedPayload encrypt(String plain, String keyId) {
        try {
            SecretKey key = keyRegistry.getKey(keyId);
            byte[] nonce = new byte[NONCE_LENGTH];
            secureRandom.nextBytes(nonce);

            Cipher cipher = Cipher.getInstance(ALG);
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BIT_LENGTH, nonce));
            byte[] cipherBytes = cipher.doFinal(plain.getBytes(java.nio.charset.StandardCharsets.UTF_8));

            return new CryptoKeyRegistry.EncryptedPayload(
                    Base64.getEncoder().encodeToString(cipherBytes),
                    Base64.getEncoder().encodeToString(nonce),
                    keyId,
                    "AES-GCM"
            );
        } catch (Exception e) {
            throw new IllegalStateException("AES-GCM 암호화 실패: " + e.getMessage(), e);
        }
    }

    /**
     * 암호문을 복호화합니다.
     */
    public String decrypt(String cipherB64, String nonceB64, String keyId) {
        try {
            SecretKey key = keyRegistry.getKey(keyId);
            byte[] cipherBytes = Base64.getDecoder().decode(cipherB64);
            byte[] nonce = Base64.getDecoder().decode(nonceB64);

            Cipher cipher = Cipher.getInstance(ALG);
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BIT_LENGTH, nonce));
            byte[] plainBytes = cipher.doFinal(cipherBytes);
            return new String(plainBytes, java.nio.charset.StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("AES-GCM 복호화 실패: " + e.getMessage(), e);
        }
    }
}
