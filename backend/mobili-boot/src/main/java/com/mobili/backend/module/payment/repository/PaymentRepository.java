package com.mobili.backend.module.payment.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;

import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByExternalReference(String externalReference);
    Optional<Payment> findByBookingIdAndProvider(Long bookingId, PaymentProvider provider);
    Optional<Payment> findByBookingIdAndExternalReference(Long bookingId, String externalReference);
}
