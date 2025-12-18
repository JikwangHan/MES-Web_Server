package kr.co.mes.support;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * 초보자용 상세 주석:
 * - 스케줄러(@Scheduled)를 활성화하기 위한 설정입니다.
 * - local 프로파일에서만 켜집니다.
 */
@Configuration
@EnableScheduling
@Profile("local")
public class LocalSchedulingConfig {
}
