package com.mobili.backend.module.user.role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    // Permet de récupérer l'entité Role complète à partir de son nom Enum
    Optional<Role> findByName(UserRole name);
}