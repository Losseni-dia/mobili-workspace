package com.mobili.backend.module.booking.booking.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.booking.booking.dto.BookingRequestDTO;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.coupon.service.CouponService;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import com.mobili.backend.module.payment.service.PaymentRefundService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripPricingService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;

/**
 * Couvre la régression : create() calculait bien la remise coupon (variable
 * locale totalPrice), mais booking.setTotalPrice() recalculait ensuite depuis
 * perSeatPrice * requestedSeats + luggageFee, jetant la remise. Le montant
 * final de la réservation (et donc facturé via Stripe/FedaPay) restait au
 * prix plein malgré un coupon valide.
 */
@ExtendWith(MockitoExtension.class)
class BookingServiceCouponPricingTest {

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

    private BookingService bookingService;

    @BeforeEach
    void setUp() {
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
                inboxNotificationService);
    }

    @Test
    void create_appliesCouponDiscountToFinalBookingTotalPrice() {
        Trip trip = new Trip();
        trip.setId(10L);
        User customer = new User();
        customer.setId(1L);

        when(tripService.findById(10L)).thenReturn(trip);
        when(userService.findById(1L)).thenReturn(customer);
        when(tripRunService.lastStopIndex(trip)).thenReturn(1);
        when(tripRunService.minFreeSeatsOnSegment(eq(trip), eq(0), eq(1))).thenReturn(2);
        when(tripPricingService.resolvePricePerSeat(trip, 0, 1)).thenReturn(10_000.0);

        // Coupon 20% : 10 000 -> 8 000
        when(couponService.applyCoupon(eq("PROMO20"), eq(BigDecimal.valueOf(10_000.0))))
                .thenReturn(BigDecimal.valueOf(8_000.0));

        when(bookingRepository.save(any(Booking.class))).thenAnswer(inv -> inv.getArgument(0));
        when(tripRepository.findByIdWithPartnerAndStops(10L)).thenReturn(Optional.of(trip));

        BookingRequestDTO.SeatSelectionDTO seat = new BookingRequestDTO.SeatSelectionDTO();
        seat.setSeatNumber("1A");
        seat.setPassengerName("Test Passager");

        BookingRequestDTO request = new BookingRequestDTO();
        request.setTripId(10L);
        request.setUserId(1L);
        request.setNumberOfSeats(1);
        request.setSelections(List.of(seat));
        request.setCouponCode("PROMO20");

        Booking result = bookingService.create(request);

        // 8 000 (prix remisé) + 0 (pas de bagage) — pas 10 000 (prix plein
        // recalculé, le bug avant correctif).
        assertEquals(8_000.0, result.getTotalPrice());
    }
}
