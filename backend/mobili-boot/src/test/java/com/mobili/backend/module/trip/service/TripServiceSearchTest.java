package com.mobili.backend.module.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.entity.TransportType;
import com.mobili.backend.module.trip.entity.VehicleType;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.shared.sharedService.UploadService;
import com.mobili.backend.module.partner.service.PartnerService;

@ExtendWith(MockitoExtension.class)
class TripServiceSearchTest {

    @Mock
    private TripRepository tripRepository;
    @Mock
    private PartnerService partenaireService;
    @Mock
    private UploadService uploadService;

    @InjectMocks
    private TripService tripService;

    private LocalDateTime baseTime;
    private LocalDate searchDate;

    @BeforeEach
    void setUp() {
        baseTime = LocalDateTime.of(2030, 6, 1, 8, 0);
        searchDate = LocalDate.of(2030, 6, 1);
    }

    @Test
    void buildCityChain_ordersDepartureStopsArrival() {
        Trip trip = trip("Abidjan", "Issia", "Divo, Gagnoa, Lakota");

        List<String> chain = tripService.buildCityChain(trip);

        assertEquals(List.of("abidjan", "divo", "gagnoa", "lakota", "issia"), chain);
    }

    @Test
    void searchTrips_findsSegmentOnLongRoute() {
        Trip longRoute = trip("Abidjan", "Issia", "Divo, Gagnoa, Lakota");
        when(tripRepository.findAllUpcomingTrips(eq(searchDate.atStartOfDay())))
                .thenReturn(List.of(longRoute));

        List<Trip> hits = tripService.searchTrips("abidjan", "gagnoa", searchDate);

        assertEquals(1, hits.size());
    }

    @Test
    void searchTrips_excludesWhenArrivalBeforeDepartureOnChain() {
        Trip longRoute = trip("Abidjan", "Issia", "Divo, Gagnoa");
        when(tripRepository.findAllUpcomingTrips(eq(searchDate.atStartOfDay())))
                .thenReturn(List.of(longRoute));

        List<Trip> hits = tripService.searchTrips("gagnoa", "abidjan", searchDate);

        assertTrue(hits.isEmpty());
    }

    @Test
    void searchTrips_exactTerminusWithoutStops() {
        Trip direct = trip("Abidjan", "Gagnoa", null);
        when(tripRepository.findAllUpcomingTrips(eq(searchDate.atStartOfDay())))
                .thenReturn(List.of(direct));

        List<Trip> hits = tripService.searchTrips("abidjan", "gagnoa", searchDate);

        assertEquals(1, hits.size());
    }

    @Test
    void searchTrips_blankDepartureAndArrival_returnsAllCandidates() {
        when(tripRepository.findAllUpcomingTrips(eq(searchDate.atStartOfDay())))
                .thenReturn(List.of(trip("A", "B", null)));

        List<Trip> hits = tripService.searchTrips("  ", "", searchDate);

        assertEquals(1, hits.size());
    }

    private Trip trip(String dep, String arr, String moreInfo) {
        Trip t = new Trip();
        t.setDepartureCity(dep);
        t.setArrivalCity(arr);
        t.setMoreInfo(moreInfo);
        t.setBoardingPoint("gare");
        t.setVehiculePlateNumber("AB-123-CI");
        t.setDepartureDateTime(baseTime.plusHours(1));
        t.setPrice(5000.0);
        t.setTotalSeats(50);
        t.setAvailableSeats(10);
        t.setStatus(TripStatus.PROGRAMMÉ);
        t.setVehicleType(VehicleType.MINIBUS);
        t.setTransportType(TransportType.PUBLIC);
        Partner p = new Partner();
        p.setName("Test Partner");
        t.setPartner(p);
        return t;
    }
}
