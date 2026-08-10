package com.mobili.backend.module.booking.booking.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.coupon.service.CouponService;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import com.mobili.backend.module.payment.service.PaymentRefundService;
import com.mobili.backend.module.pricing.service.BookingFeeService;
import com.mobili.backend.module.pricing.service.CompanyCommissionService;
import com.mobili.backend.module.pricing.service.PartnerMonthlyVolumeService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripPricingService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;

/**
 * previewPrice() ne doit RIEN persister (aucun appel à bookingRepository.save) et doit
 * renvoyer exactement le même détail (sous-total, forfait, bagages, total) que create()
 * calculerait — même séquence de calcul partagée (computePricing).
 */
@ExtendWith(MockitoExtension.class)
class BookingServicePricePreviewTest {

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
    private CompanyCommissionService companyCommissionService;
    @Mock
    private PartnerMonthlyVolumeService partnerMonthlyVolumeService;

    private BookingService bookingService;

    @BeforeEach
    void setUp() {
        bookingService = new BookingService(
                bookingRepository, tripService, tripRepository, userService, ticketService,
                userRepository, partnerService, tripRunService, tripPricingService,
                analyticsEventService, couponService, paymentRefundService, paymentRepository,
                inboxNotificationService, bookingFeeService, companyCommissionService,
                partnerMonthlyVolumeService);
    }

    @Test
    void previewPrice_computesBreakdownWithoutPersistingAnything() {
        Trip trip = new Trip();
        trip.setId(10L);
        trip.setExtraHoldBagPrice(500.0);

        when(tripService.findById(10L)).thenReturn(trip);
        when(tripRunService.lastStopIndex(trip)).thenReturn(1);
        when(tripPricingService.resolvePricePerSeat(trip, 0, 1)).thenReturn(2500.0);
        when(bookingFeeService.calculateBookingFee(5000.0)).thenReturn(300);

        BookingService.PricingBreakdown pricing = bookingService.previewPrice(
                10L, 2, null, null, 1, null);

        assertEquals(2500.0, pricing.perSeatPrice());
        assertEquals(5000.0, pricing.seatSubtotal());
        assertEquals(300, pricing.serviceFee());
        assertEquals(500.0, pricing.luggageFee());
        assertEquals(5800.0, pricing.total());

        verify(bookingRepository, never()).save(org.mockito.ArgumentMatchers.any());
        org.mockito.Mockito.verifyNoInteractions(ticketService);
    }
}
