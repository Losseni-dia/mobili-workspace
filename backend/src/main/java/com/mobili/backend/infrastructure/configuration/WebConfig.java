package com.mobili.backend.infrastructure.configuration;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Utiliser System.getProperty("user.dir") garantit qu'on part de la racine du
        // processus Java
        String rootPath = System.getProperty("user.dir");
        String location = "file:" + rootPath + "/uploads/";

        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(location)
                .setCachePeriod(0);

        System.out.println("🚀 Serveur d'images configuré sur : " + location);
    }
}