package com.mobili.backend;

import com.mobili.backend.infrastructure.configuration.MobiliCorsSettings;
import com.mobili.backend.infrastructure.configuration.MobiliDotenvBootstrap;
import com.mobili.backend.infrastructure.configuration.MobiliRateLimitProperties;
import com.mobili.backend.infrastructure.configuration.MobiliSecurityRefreshSettings;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
@EnableConfigurationProperties({
    MobiliCorsSettings.class,
    MobiliSecurityRefreshSettings.class,
    MobiliRateLimitProperties.class,
})
public class BackendApplication {

	public static void main(String[] args) {
		// 1–2 .env → System properties (voir MobiliDotenvBootstrap)
		MobiliDotenvBootstrap.loadIntoSystemProperties();

		// 3. Lancer l'application normalement
		SpringApplication.run(BackendApplication.class, args);
	}
}