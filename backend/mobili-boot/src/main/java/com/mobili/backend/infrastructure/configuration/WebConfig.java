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

        /*
         * Avatars, logos, photos trajets, photos conducteur/véhicule covoiturage — pas
         * les
         * dossiers sensibles (KYC sous sensitive/, covoiturage-ids = pièces
         * d'identité).
         */
        registry.addResourceHandler("/uploads/users/**").addResourceLocations(location + "users/").setCachePeriod(0);
        registry.addResourceHandler("/uploads/partners/**").addResourceLocations(location + "partners/")
                .setCachePeriod(0);
        registry.addResourceHandler("/uploads/vehicles/**").addResourceLocations(location + "vehicles/")
                .setCachePeriod(0);
        registry.addResourceHandler("/uploads/logos/**").addResourceLocations(location + "logos/").setCachePeriod(0);
        registry.addResourceHandler("/uploads/covoiturage-drivers/**")
                .addResourceLocations(location + "covoiturage-drivers/").setCachePeriod(0);
        registry.addResourceHandler("/uploads/covoiturage-vehicles/**")
                .addResourceLocations(location + "covoiturage-vehicles/").setCachePeriod(0);
    }
}