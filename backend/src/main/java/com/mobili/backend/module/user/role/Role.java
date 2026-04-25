package com.mobili.backend.module.user.role;

import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "roles")
@Getter
@Setter
@NoArgsConstructor
public class Role extends AbstractEntity {
    @Enumerated(EnumType.STRING)
    @Column(unique = true, nullable = false)
    private UserRole name; // ROLE_USER, ROLE_COMPANY, ROLE_ADMIN, ROLE_DRIVER
}