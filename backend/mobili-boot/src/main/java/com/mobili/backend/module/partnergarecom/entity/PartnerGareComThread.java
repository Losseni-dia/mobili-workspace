package com.mobili.backend.module.partnergarecom.entity;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "partner_gare_com_threads")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class PartnerGareComThread extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partner_id", nullable = false)
    private Partner partner;

    @Enumerated(EnumType.STRING)
    @Column(name = "scope", nullable = false, length = 20)
    private PartnerGareComThreadScope scope;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "last_activity_at", nullable = false)
    private LocalDateTime lastActivityAt;

    @OneToMany(mappedBy = "thread", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PartnerGareComThreadTarget> targets = new ArrayList<>();
}
