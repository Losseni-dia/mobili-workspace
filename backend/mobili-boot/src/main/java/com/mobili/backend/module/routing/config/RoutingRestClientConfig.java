package com.mobili.backend.module.routing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

/**
 * Déclare explicitement le bean {@link RestClient.Builder} consommé par
 * {@code MapboxDirectionsService}/{@code GoogleMapsDirectionsService} — première utilisation de
 * {@link RestClient} dans ce projet (jusqu'ici uniquement {@code RestTemplate}/aucun client HTTP
 * sortant). Avec {@code spring-boot-starter-webmvc} (nommage Spring Boot 4), ce bean n'est pas
 * auto-configuré comme il l'aurait été avec l'ancien {@code spring-boot-starter-web} — sans cette
 * déclaration, le démarrage échoue en {@code UnsatisfiedDependencyException} dès que le contexte
 * Spring va assez loin pour instancier ces services (masqué en local par l'échec Postgres qui
 * arrête le contexte avant, voir BackendApplicationTests.contextLoads).
 */
@Configuration
public class RoutingRestClientConfig {

    @Bean
    public RestClient.Builder restClientBuilder() {
        return RestClient.builder();
    }
}
