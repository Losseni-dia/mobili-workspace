
package com.mobili.backend.module.booking.booking.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.projection.TripStatsAggrJpa;
import com.mobili.backend.module.booking.booking.projection.TripStatsPerTripJpa;

public interface BookingRepository extends JpaRepository<Booking, Long> {
        // Tri par date de réservation (récente d'abord) directement en base — le front (web/app)
        // s'appuyait jusqu'ici uniquement sur son propre tri client, jamais garanti par la requête.
        List<Booking> findByCustomerIdOrderByBookingDateDesc(Long userId);

        List<Booking> findByTripId(Long tripId);

        List<Booking> findByStatusAndCreatedAtBefore(BookingStatus status, LocalDateTime cutoff);

        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE t.id = :tripId " +
                        "ORDER BY b.bookingDate DESC")
        List<Booking> findAllByTripIdWithDetails(@Param("tripId") Long tripId);

        // LEFT JOIN FETCH b.tickets : cancelBooking/cancelTickets (annulation, cascade vers les
        // tickets) et getGrossAmount() en ont besoin sans lazy-load.
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.station " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.tickets " +
                        "WHERE b.id = :id")
        Optional<Booking> findByIdWithDetails(@Param("id") Long id);

        // LEFT JOIN FETCH b.tickets : TripRunService.seatsOccupiedOnLeg() doit savoir si une
        // réservation a déjà des tickets générés pour ne pas compter en double avec la boucle
        // ticket (seule source fiable une fois les tickets émis, notamment après une
        // annulation partielle — voir son Javadoc).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.tickets " +
                        "WHERE b.trip.id = :tripId " +
                        "AND b.status != com.mobili.backend.module.booking.booking.entity.BookingStatus.CANCELLED")
        List<Booking> findByTripIdWithSeats(@Param("tripId") Long tripId);


        // JOIN FETCH b.trip / b.customer / b.tickets : sans ça, BookingMapper.toDto()
        // déréférence plusieurs proxies Hibernate hors session (open-in-view désactivé) ->
        // LazyInitializationException -> 500 avalé en liste vide côté frontend (modale
        // "Passagers" toujours vide malgré des réservations bien présentes en base) :
        // - trip.id/departureCity/... et customer.firstname/lastname (mapping direct),
        // - b.tickets, via booking.getGrossAmount() -> hasActiveTicketFareSplit()
        //   (tickets.isEmpty()) appelé pour calculer le montant affiché (amount).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.tickets " +
                        "WHERE t.id = :tripId " +
                        "AND b.status IN (" +
                        "com.mobili.backend.module.booking.booking.entity.BookingStatus.CONFIRMED, " +
                        "com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE)")
        List<Booking> findConfirmedByTripIdWithDetails(@Param("tripId") Long tripId);


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

        // LEFT JOIN FETCH b.tickets : Booking.getGrossAmount() (appelée par PartnerMapper sur
        // cette liste) lit les tickets pour exclure ceux ANNULÉ — sans ce fetch, chaque appel
        // déclencherait un lazy-load N+1 par réservation.
        // status IN (...) : exclut les tentatives de paiement échouées/abandonnées (PENDING,
        // CANCELLED, EXPIRED...) de "Dernières réservations" (feedback testeurs) — seules les
        // réservations réellement payées/valides doivent y figurer.
        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames LEFT JOIN FETCH b.seatNumbers LEFT JOIN FETCH b.tickets " +
                        "WHERE t.partner.id = :partnerId AND t.station.id = :stationId " +
                        "AND b.status IN ('CONFIRMED', 'OFFLINE_SALE', 'COMPLETED') ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByPartnerAndStation(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId);

        @Query("SELECT COUNT(b) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.trip.station.id = :stationId AND b.status = 'CONFIRMED'")
        long countBookingsByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

        @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.trip.station.id = :stationId AND b.status = 'CONFIRMED'")
        Double calculateRevenueByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

        // LEFT JOIN FETCH b.tickets : voir findRecentBookingsByPartnerAndStation. status IN (...) :
        // même exclusion des tentatives échouées/abandonnées, voir commentaire ci-dessus.
        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.passengerNames LEFT JOIN FETCH b.seatNumbers LEFT JOIN FETCH b.tickets " +
                        "WHERE t.partner.id = :partnerId " +
                        "AND b.status IN ('CONFIRMED', 'OFFLINE_SALE', 'COMPLETED') ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByPartner(@Param("partnerId") Long partnerId);

        /** Dashboard conducteur covoiturage : réservations sur SES trajets, jamais ceux du pool entier. */
        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.passengerNames LEFT JOIN FETCH b.seatNumbers LEFT JOIN FETCH b.tickets " +
                        "WHERE t.covoiturageOrganizer.id = :organizerId ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByCovoiturageOrganizer(@Param("organizerId") Long organizerId);


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

        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "WHERE t.partner.id = :partnerId " +
                        "AND b.createdAt >= :from AND b.createdAt <= :to " +
                        "ORDER BY b.createdAt DESC")
        List<Booking> findAllByPartnerIdAndDateRange(
                        @Param("partnerId") Long partnerId,
                        @Param("from") java.time.LocalDateTime from,
                        @Param("to") java.time.LocalDateTime to);

        @Query("SELECT b FROM Booking b " +
                        "LEFT JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "LEFT JOIN FETCH t.station " +
                        "LEFT JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "WHERE t.partner.id = :partnerId AND t.station.id = :stationId " +
                        "AND b.createdAt >= :from AND b.createdAt <= :to " +
                        "ORDER BY b.createdAt DESC")
        List<Booking> findAllByPartnerIdAndStationIdAndDateRange(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId,
                        @Param("from") java.time.LocalDateTime from,
                        @Param("to") java.time.LocalDateTime to);

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


        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE b.trip.id = :tripId AND b.status = :status " +
                        "ORDER BY b.createdAt ASC")
        List<Booking> findByTripIdAndStatus(@Param("tripId") Long tripId, @Param("status") BookingStatus status);

        /**
         * Scheduler : demandes covoiturage dont le délai de réponse chauffeur est
         * dépassé.
         */
        List<Booking> findByStatusAndDriverResponseDeadlineBefore(BookingStatus status, LocalDateTime cutoff);

        /** Scheduler : réservations acceptées dont le délai de paiement est dépassé. */
        List<Booking> findByStatusAndPaymentDeadlineBefore(BookingStatus status, LocalDateTime cutoff);

        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer c " +
                        "WHERE t.covoiturageOrganizer.id = :organizerId " +
                        "AND b.status = com.mobili.backend.module.booking.booking.entity.BookingStatus.PENDING_DRIVER_APPROVAL "
                        +
                        "ORDER BY b.createdAt ASC")
        List<Booking> findPendingCovoiturageRequestsForOrganizer(@Param("organizerId") Long organizerId);


        @Query("SELECT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "JOIN FETCH b.customer c " +
                        "WHERE b.bookingDate >= :from AND b.bookingDate <= :to " +
                        "AND (:search IS NULL OR :search = '' " +
                        "     OR LOWER(b.reference) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.firstname) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.lastname) LIKE LOWER(CONCAT('%', :search, '%'))) " +
                        "ORDER BY b.bookingDate DESC")
        List<Booking> findForAdminList(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("search") String search);

        /**
         * Réservations effectivement payées (CONFIRMED/OFFLINE_SALE) — seules celles-ci ont des
         * tickets avec commission calculée (voir BookingService.generateTicketsWithCommission,
         * déclenché uniquement à la confirmation du paiement). Tickets fetch-joints pour sommer
         * transportFare/baggageFee/commissionAmount côté service sans requête supplémentaire.
         */
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "LEFT JOIN FETCH t.station " +
                        "JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.tickets " +
                        "WHERE b.status IN (com.mobili.backend.module.booking.booking.entity.BookingStatus.CONFIRMED, " +
                        "                   com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE) " +
                        "AND b.bookingDate >= :from AND b.bookingDate <= :to " +
                        "AND (:search IS NULL OR :search = '' " +
                        "     OR LOWER(b.reference) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.firstname) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.lastname) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(t.partner.name) LIKE LOWER(CONCAT('%', :search, '%'))) " +
                        "ORDER BY b.bookingDate DESC")
        List<Booking> findConfirmedForAdminTransactions(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("search") String search);

        // LEFT JOIN FETCH b.tickets : voir findRecentBookingsByPartnerAndStation — alimente
        // BookingMapper.toDto (champ amount = booking.getGrossAmount()).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.tickets " +
                        "WHERE t.partner.id = :partnerId AND (:stationId IS NULL OR t.station.id = :stationId) " +
                        "AND b.createdAt >= :from AND b.createdAt <= :to " +
                        "ORDER BY b.createdAt DESC")
        List<Booking> findAllByPartnerIdAndOptionalStationIdAndDateRange(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId,
                        @Param("from") java.time.LocalDateTime from,
                        @Param("to") java.time.LocalDateTime to);

        /**
         * Réservations payées d'un partenaire (CONFIRMED/OFFLINE_SALE) — même filtre statut que
         * findConfirmedForAdminTransactions, scopé au partenaire (+ gare optionnelle). Tickets
         * fetch-joints pour sommer commissionAmount/transportFare/baggageFee côté service.
         */
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.tickets " +
                        "WHERE t.partner.id = :partnerId AND (:stationId IS NULL OR t.station.id = :stationId) " +
                        "AND b.status IN (com.mobili.backend.module.booking.booking.entity.BookingStatus.CONFIRMED, " +
                        "                 com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE) " +
                        "AND b.bookingDate >= :from AND b.bookingDate <= :to " +
                        "ORDER BY b.bookingDate DESC")
        List<Booking> findConfirmedForPartnerTransactions(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId,
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to);
}