package com.mobili.backend.module.booking.booking.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.HashSet;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.coupon.service.CouponService;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import com.mobili.backend.module.payment.service.PaymentRefundService;
import com.mobili.backend.module.pricing.entity.PartnerMonthlyTicketCounter;
import com.mobili.backend.module.pricing.repository.PartnerMonthlyTicketCounterRepository;
import com.mobili.backend.module.pricing.service.BookingFeeService;
import com.mobili.backend.module.pricing.service.CompanyCommissionService;
import com.mobili.backend.module.pricing.service.PartnerMonthlyVolumeService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripPricingService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;

/**
 * Scénario de la spec : compagnie à 498 tickets vendus ce mois-ci, réservation de 4 tickets
 * qui chevauche la frontière 500 — les tickets n°499/500 doivent sortir à 9%, les n°501/502
 * à 7%. CompanyCommissionService et PartnerMonthlyVolumeService sont utilisés RÉELLEMENT ici
 * (pas mockés) — seul le dépôt du compteur (PartnerMonthlyTicketCounterRepository) et les
 * dépendances externes à BookingService sont mockés — pour vérifier que l'orchestration réelle
 * (positions attribuées dans l'ordre, prix transmis correctement) fonctionne de bout en bout.
 */
@ExtendWith(MockitoExtension.class)
class BookingServiceCommissionIntegrationTest {

    @Mock
    private BookingRepository bookingRepository;
    @Mock
    private TripService tripService;
    @Mock
    private TripRepository tripRepository;
    @Mock
    private UserService userService;
    @Mock
    private TicketService ticketService;
    @Mock
    private UserRepository userRepository;
    @Mock
    private PartnerService partnerService;
    @Mock
    private TripRunService tripRunService;
    @Mock
    private TripPricingService tripPricingService;
    @Mock
    private AnalyticsEventService analyticsEventService;
    @Mock
    private InboxNotificationService inboxNotificationService;
    @Mock
    private CouponService couponService;
    @Mock
    private PaymentRefundService paymentRefundService;
    @Mock
    private PaymentRepository paymentRepository;
    @Mock
    private BookingFeeService bookingFeeService;
    @Mock
    private PartnerMonthlyTicketCounterRepository counterRepository;

    private BookingService bookingService;

    @BeforeEach
    void setUp() {
        CompanyCommissionService realCommissionService = new CompanyCommissionService();
        PartnerMonthlyVolumeService realVolumeService = new PartnerMonthlyVolumeService(counterRepository);

        bookingService = new BookingService(
                bookingRepository,
                tripService,
                tripRepository,
                userService,
                ticketService,
                userRepository,
                partnerService,
                tripRunService,
                tripPricingService,
                analyticsEventService,
                couponService,
                paymentRefundService,
                paymentRepository,
                inboxNotificationService,
                bookingFeeService,
                realCommissionService,
                realVolumeService);
    }

    @Test
    void bookingOfFourTickets_atCompanyPosition498_splitsAcrossTwoCommissionRates() {
        Partner partner = new Partner();
        partner.setId(7L);

        Trip trip = new Trip();
        trip.setId(10L);
        trip.setPartner(partner);

        User customer = new User();
        customer.setId(42L);

        Booking booking = new Booking();
        booking.setId(1L);
        booking.setCustomer(customer);
        booking.setTrip(trip);
        booking.setNumberOfSeats(4);
        booking.setStatus(BookingStatus.PENDING);
        booking.setTicketsTotalAmount(20_000.0); // 4 tickets à 5000 FCFA chacun
        booking.setServiceFee(300);
        booking.setTotalPrice(20_000.0 + 300); // pas de bagage
        booking.setPassengerNames(new HashSet<>(java.util.List.of("A", "B", "C", "D")));
        booking.setSeatNumbers(new HashSet<>(java.util.List.of("1", "2", "3", "4")));

        when(bookingRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(booking));
        when(bookingRepository.save(any(Booking.class))).thenAnswer(inv -> inv.getArgument(0));
        when(tripRepository.findByIdWithPartnerAndStops(10L)).thenReturn(Optional.of(trip));

        PartnerMonthlyTicketCounter counter = new PartnerMonthlyTicketCounter();
        counter.setPartnerId(7L);
        counter.setTicketCount(498);
        when(counterRepository.findByPartnerIdAndYearMonthForUpdate(eq(7L), anyString()))
                .thenReturn(Optional.of(counter));
        when(counterRepository.save(any(PartnerMonthlyTicketCounter.class))).thenAnswer(inv -> inv.getArgument(0));

        bookingService.confirmBookingAfterPayment(1L);

        // 4 tickets à 5000 FCFA (transport pur, pas de bagage) : positions 499,500 -> 9%,
        // positions 501,502 -> 7%.
        verify(ticketService, org.mockito.Mockito.times(2))
                .createFromBooking(any(), anyString(), anyString(), eq(5000.0), eq(0.0),
                        argThatRate(0.09), any());
        verify(ticketService, org.mockito.Mockito.times(2))
                .createFromBooking(any(), anyString(), anyString(), eq(5000.0), eq(0.0),
                        argThatRate(0.07), any());

        assertEquals(502, counter.getTicketCount());
    }

    private com.mobili.backend.module.pricing.dto.CommissionResult argThatRate(double rate) {
        return org.mockito.ArgumentMatchers.argThat(c -> c != null && c.rate() == rate);
    }
}
