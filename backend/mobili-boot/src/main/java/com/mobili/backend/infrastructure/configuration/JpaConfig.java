package com.mobili.backend.infrastructure.configuration;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@Configuration
@EnableJpaAuditing // C'est cette ligne qui rend le "createdAt" automatique
public class JpaConfig {
}