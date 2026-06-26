package com.mobili.backend.module.admincom.entity;

import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "admin_com_threads")
@Getter
@Setter
@NoArgsConstructor
public class AdminComThread extends AbstractEntity {

    @Column(nullable = false, length = 300)
    private String subject;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private AdminComType type = AdminComType.PARTNER;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "admin_user_id", nullable = false)
    private User adminUser;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partner_user_id", nullable = false)
    private User partnerUser;

    @Column(nullable = false)
    private LocalDateTime lastActivityAt = LocalDateTime.now();
}