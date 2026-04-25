package com.mobili.backend.shared.abstractEntity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;
import java.time.LocalDateTime;

@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
public abstract class AbstractEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id; // Toutes tes tables auront maintenant un ID auto-incrémenté

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
}