package com.mobili.backend.module.payment.entity;

import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "payments", indexes = {
    @Index(name = "idx_payments_external_ref", columnList = "external_reference")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Payment extends AbstractEntity {

    @Column(nullable = false)
    private Long bookingId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentProvider provider;

    private String externalReference;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentStatus status;

    @Column(nullable = false)
    private Long amount; // Montant envoyé au provider

    @Column(nullable = false)
    private String currency; // Devise du provider

    private Long originalAmount; // Montant métier (XOF)

    private String originalCurrency; // Devise métier ("XOF")

    @Column(precision = 19, scale = 4)
    private java.math.BigDecimal exchangeRate;

    private LocalDateTime updatedAt;

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
