
package com.mobili.backend.module.booking.booking.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.projection.TripStatsAggrJpa;
import com.mobili.backend.module.booking.booking.projection.TripStatsPerTripJpa;

public interface BookingRepository extends JpaRepository<Booking, Long> {
        List<Booking> findByCustomerId(Long userId);

        List<Booking> findByTripId(Long tripId);

        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.station " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE b.id = :id")
        Optional<Booking> findByIdWithDetails(@Param("id") Long id);

        @Query("SELECT DISTINCT b FROM Booking b " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE b.trip.id = :tripId " +
                        "AND b.status != com.mobili.backend.module.booking.booking.entity.BookingStatus.CANCELLED")
        List<Booking> findByTripIdWithSeats(@Param("tripId") Long tripId);


        // Compter les réservations pour les trajets d'un partenaire
        @Query("SELECT COUNT(b) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.status = 'CONFIRMED'")
        long countBookingsByPartner(@Param("partnerId") Long partnerId);

        // Calculer le revenu total
        @Query("SELECT SUM(b.totalPrice) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.status = 'CONFIRMED'")
        Double calculateRevenueByPartner(@Param("partnerId") Long partnerId);

        // Récupérer les 5 dernières réservations
        @Query("SELECT b FROM Booking b JOIN FETCH b.trip JOIN FETCH b.customer " +
                        "WHERE b.trip.partner.id = :partnerId ORDER BY b.createdAt DESC")
        List<Booking> findTop5RecentBookingsByPartner(@Param("partnerId") Long partnerId);

        @Query("SELECT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer " +
                        "WHERE t.partner.id = :partnerId AND t.station.id = :stationId ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByPartnerAndStation(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId);

        @Query("SELECT COUNT(b) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.trip.station.id = :stationId AND b.status = 'CONFIRMED'")
        long countBookingsByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

        @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.trip.station.id = :stationId AND b.status = 'CONFIRMED'")
        Double calculateRevenueByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

        @Query("SELECT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer c " +
                        "WHERE t.partner.id = :partnerId ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByPartner(@Param("partnerId") Long partnerId);


        @Query("SELECT b FROM Booking b WHERE b.trip.partner.id = :partnerId ORDER BY b.createdAt DESC")
        List<Booking> findAllByTripPartnerId(@Param("partnerId") Long partnerId);

        @Query("SELECT b FROM Booking b " +
                        "LEFT JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "LEFT JOIN FETCH t.station " +
                        "LEFT JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "WHERE t.partner.id = :partnerId AND t.station.id = :stationId " +
                        "ORDER BY b.createdAt DESC")
        List<Booking> findAllByPartnerIdAndStationId(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId);

        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "WHERE t.partner.id = :partnerId " +
                        "ORDER BY b.createdAt DESC")
        List<Booking> findAllByPartnerId(@Param("partnerId") Long partnerId);

        @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.status <> com.mobili.backend.module.booking.booking.entity.BookingStatus.CANCELLED")
        Double sumTotalRevenue();

        @Query("SELECT new com.mobili.backend.module.booking.booking.projection.TripStatsAggrJpa("
                        + "COALESCE(SUM(b.totalPrice), 0.0), COUNT(b), COUNT(DISTINCT t.id)) "
                        + "FROM Booking b JOIN b.trip t "
                        + "WHERE b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                        + "AND b.createdAt >= :from AND b.createdAt < :to")
        TripStatsAggrJpa aggregateForTripStats(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to);

        @Query("SELECT new com.mobili.backend.module.booking.booking.projection.TripStatsPerTripJpa("
                        + "t.id, t.departureCity, t.arrivalCity, p.name, COUNT(b), COALESCE(SUM(b.totalPrice), 0.0)) "
                        + "FROM Booking b JOIN b.trip t JOIN t.partner p "
                        + "WHERE b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                        + "AND b.createdAt >= :from AND b.createdAt < :to "
                        + "GROUP BY t.id, t.departureCity, t.arrivalCity, p.id, p.name "
                        + "ORDER BY COUNT(b) DESC, t.id ASC")
        List<TripStatsPerTripJpa> findTripStatsOrderedByBookingCount(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to);

        @Query("SELECT new com.mobili.backend.module.booking.booking.projection.TripStatsPerTripJpa("
                        + "t.id, t.departureCity, t.arrivalCity, p.name, COUNT(b), COALESCE(SUM(b.totalPrice), 0.0)) "
                        + "FROM Booking b JOIN b.trip t JOIN t.partner p "
                        + "WHERE b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                        + "AND b.createdAt >= :from AND b.createdAt < :to "
                        + "GROUP BY t.id, t.departureCity, t.arrivalCity, p.id, p.name "
                        + "ORDER BY COALESCE(SUM(b.totalPrice), 0.0) DESC, t.id ASC")
        List<TripStatsPerTripJpa> findTripStatsOrderedByRevenue(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to);

        @Query("SELECT COALESCE(SUM(b.numberOfSeats), 0) FROM Booking b "
                        + "WHERE b.trip.id = :tripId AND b.status IN ('CONFIRMED', 'COMPLETED')")
        int sumConfirmedSeatsForTrip(@Param("tripId") Long tripId);

        @Query("SELECT COALESCE(SUM(b.extraHoldBags), 0) FROM Booking b "
                        + "WHERE b.trip.id = :tripId AND b.status IN ('CONFIRMED', 'COMPLETED')")
        int sumExtraHoldBagsForTrip(@Param("tripId") Long tripId);
}