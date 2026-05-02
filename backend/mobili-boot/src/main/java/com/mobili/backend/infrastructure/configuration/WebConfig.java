package com.mobili.backend.infrastructure.configuration;

import java.nio.file.Path;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    /** Même dossier que {@link com.mobili.backend.shared.sharedService.UploadService} (ex. {@code uploads/…}). */
    @Value("${mobili.backend.upload.root-directory}")
    private String uploadRootDirectory;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path uploadRoot = Path.of(uploadRootDirectory).toAbsolutePath().normalize();
        String location = uploadRoot.toUri().toString();
        if (!location.endsWith("/")) {
            location = location + "/";
        }

        /* Avatars, logos, photos trajets — pas les dossiers sensibles (KYC sous sensitive/, anciens covoiturage-*). */
        registry.addResourceHandler("/uploads/users/**").addResourceLocations(location + "users/").setCachePeriod(0);
        registry.addResourceHandler("/uploads/partners/**").addResourceLocations(location + "partners/").setCachePeriod(0);
        registry.addResourceHandler("/uploads/vehicles/**").addResourceLocations(location + "vehicles/").setCachePeriod(0);

        System.out.println("🚀 Fichiers publics servis depuis : " + location + "(physique=" + uploadRoot + ")");
    }
}