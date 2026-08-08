package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Service
@Slf4j
@RequiredArgsConstructor
public class PaymentCreationService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;

    @Transactional
    public Payment createPayment(
            Long bookingId,
            PaymentProvider provider,
            Long providerAmount,
            String providerCurrency,
            Long bookingAmount,
            String bookingCurrency,
            BigDecimal exchangeRate) {

        log.info("📝 Initialisation paiement PENDING pour Booking #{} avec {}", bookingId, provider);

        // 1. Vérifier que le booking existe
        if (!bookingRepository.existsById(bookingId)) {
            log.error("❌ Booking introuvable : #{}", bookingId);
            throw new IllegalArgumentException("Booking inexistant : " + bookingId);
        }

        // 2. Vérifier qu'un paiement PENDING n'existe pas déjà pour ce booking
        paymentRepository.findAll().stream()
                .filter(p -> p.getBookingId().equals(bookingId) && p.getStatus() == PaymentStatus.PENDING)
                .findFirst()
                .ifPresent(p -> {
                    log.warn("⚠️ Un paiement PENDING existe déjà pour Booking #{}", bookingId);
                    throw new IllegalStateException("Un paiement est déjà en cours pour cette réservation.");
                });

        // 3. Créer le paiement
        Payment payment = new Payment();
        payment.setBookingId(bookingId);
        payment.setProvider(provider);
        payment.setStatus(PaymentStatus.PENDING);
        payment.setAmount(providerAmount);
        payment.setCurrency(providerCurrency);
        payment.setOriginalAmount(bookingAmount);
        payment.setOriginalCurrency(bookingCurrency);
        payment.setExchangeRate(exchangeRate);
        payment.setCreatedAt(LocalDateTime.now()); // AbstractEntity might set this, but good to be safe

        log.info("✅ Paiement PENDING créé pour Booking #{}", bookingId);
        return paymentRepository.save(payment);
    }
}
