package kr.co.mes;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class MesWebApplicationTests {

	static {
		kr.co.mes.web.TestCryptoEnv.ensure();
	}

	@Test
	void contextLoads() {
	}

}
