package com.mobili.backend;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import io.github.cdimascio.dotenv.Dotenv;

@SpringBootTest
class BackendApplicationTests {

	@BeforeAll
	static void setup() {
		// On charge le .env AVANT que Spring ne démarre pour les tests
		Dotenv dotenv = Dotenv.configure().ignoreIfMissing().load();
		dotenv.entries().forEach(entry -> {
			System.setProperty(entry.getKey(), entry.getValue());
		});
	}
	

	@Test
	void contextLoads() {
	}

}


