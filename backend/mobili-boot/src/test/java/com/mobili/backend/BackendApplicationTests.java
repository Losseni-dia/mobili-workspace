package com.mobili.backend;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import com.mobili.backend.infrastructure.configuration.MobiliDotenvBootstrap;

@SpringBootTest
class BackendApplicationTests {

	@BeforeAll
	static void setup() {
		// Aligné sur BackendApplication : .env racine mobili/, backend/, mobili-boot/ (répertoire de travail Maven)
		MobiliDotenvBootstrap.loadIntoSystemProperties();
	}
	

	@Test
	void contextLoads() {
	}

}


