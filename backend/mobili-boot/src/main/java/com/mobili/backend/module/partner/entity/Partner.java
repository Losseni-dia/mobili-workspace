package com.mobili.backend.module.partner.entity;

import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "partners")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Partner extends AbstractEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "email", nullable = false)
    private String email;// Email officiel de la société

    private String logoUrl;

    private String businessNumber;

    private String phone;

    private boolean enabled = true; // Permet à l'admin de bloquer la société

    /**
     * Code public (généré) pour l’auto-inscription des comptes gare : affiché au dirigeant, saisi par
     * les responsables de gare. Unique (insensible à la casse côté recherche).
     */
    @Column(name = "registration_code", unique = true, length = 12)
    private String registrationCode;

    @OneToOne // Un partenaire a un seul propriétaire
    @JoinColumn(name = "user_id", unique = true)
    private User owner;

    /**
     * {@code true} = partenaire technique Mobili (pool covoiturage particulier), distinct des
     * compagnies « transport / ligne » gérées par l’admin.
     */
    @Column(name = "covoiturage_solo_pool", nullable = false)
    private boolean covoiturageSoloPool = false;
}