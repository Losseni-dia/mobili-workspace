package com.mobili.backend.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.module.user.role.UserRole;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Configuration
@RequiredArgsConstructor
@Slf4j
public class RoleBootstrapConfig {

    private final RoleRepository roleRepository;

    @Bean
    CommandLineRunner ensureRoles() {
        return args -> {
            for (UserRole ur : UserRole.values()) {
                if (roleRepository.findByName(ur).isEmpty()) {
                    Role r = new Role();
                    r.setName(ur);
                    roleRepository.save(r);
                    log.info("Rôle créé : {}", ur);
                }
            }
        };
    }

    @Bean
    CommandLineRunner ensurePartnerRegistrationCodes(PartnerService partnerService) {
        return args -> partnerService.fillMissingRegistrationCodes();
    }
}
