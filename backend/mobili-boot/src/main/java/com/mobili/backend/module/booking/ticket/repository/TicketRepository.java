package com.mobili.backend.module.booking.ticket.repository;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.booking.ticket.entity.Ticket;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface TicketRepository extends JpaRepository<Ticket, Long> {
    
    @EntityGraph(attributePaths = {
            "trip",
            "booking",
            "booking.trip",
            "booking.trip.partner"
    })
    Optional<Ticket> findByTicketNumber(String ticketNumber);

    @Query("SELECT t.seatNumber FROM Ticket t WHERE t.trip.id = :tripId AND t.status != 'ANNULÉ'")
    List<String> findOccupiedSeatNumbersByTripId(@Param("tripId") Long tripId);

    @Query("SELECT t FROM Ticket t WHERE t.trip.id = :tripId ORDER BY t.seatNumber ASC")
    List<Ticket> findAllByTripIdOrderBySeatNumberAsc(@Param("tripId") Long tripId);

    @Query("SELECT t FROM Ticket t WHERE t.booking.id = :bookingId ORDER BY t.seatNumber ASC")
    List<Ticket> findAllByBookingIdOrderBySeatNumberAsc(@Param("bookingId") Long bookingId);

    // Tri par date de réservation (récente d'abord) — même principe que
    // BookingRepository.findByCustomerIdOrderByBookingDateDesc.
    @Query("SELECT t FROM Ticket t JOIN FETCH t.trip WHERE t.passenger.id = :userId ORDER BY t.bookingDate DESC")
    List<Ticket> findAllByUserIdCustom(@Param("userId") Long userId);

    @Query("SELECT DISTINCT t.passenger.id FROM Ticket t WHERE t.trip.id = :tripId AND t.status <> 'ANNULÉ'")
    List<Long> findDistinctPassengerIdsWithActiveTicket(@Param("tripId") Long tripId);

    @Query("SELECT CASE WHEN COUNT(t) > 0 THEN true ELSE false END FROM Ticket t "
                    + "WHERE t.trip.id = :tripId AND t.passenger.id = :userId AND t.status <> 'ANNULÉ'")
    boolean existsActiveTicketForTripAndPassenger(@Param("tripId") Long tripId, @Param("userId") Long userId);

    @Query("SELECT COUNT(t) FROM Ticket t WHERE t.status <> 'ANNULÉ'")
    long countActiveTickets();

    @Query("SELECT COUNT(t) FROM Ticket t WHERE CAST(t.bookingDate AS date) = :date AND t.status <> 'ANNULÉ'")
    long countByBookingDateDate(@Param("date") java.time.LocalDate date);

    @Query(value = "SELECT DATE(booking_date) as day, COUNT(*) as cnt FROM tickets " +
                    "WHERE booking_date >= :from AND booking_date <= :to AND status <> 'ANNULÉ' GROUP BY DATE(booking_date) ORDER BY DATE(booking_date) ASC", nativeQuery = true)
    java.util.List<Object[]> dailyTicketsBetween(@Param("from") java.time.LocalDateTime from,
                    @Param("to") java.time.LocalDateTime to);

    // ===== Stats métier (admin) — comptage au niveau TICKET (unité = un siège vendu), jamais
    // au niveau réservation : une résa de 3 places = 1 booking mais 3 tickets. Avant ce
    // correctif, la page comptait des bookings sous le libellé "Billets", ce qui créait un écart
    // avec "Tickets vendus (actifs)" affiché partout ailleurs dans l'admin (dashboard, page
    // Tickets) — constaté en prod (133 tickets réels vs 124 "billets" = bookings). Filtre sur
    // tr.departureDateTime (date du voyage), jamais bookingDate (date d'achat), comme partout
    // ailleurs dans ce module.

    @Query("SELECT COUNT(tk) FROM Ticket tk JOIN tk.booking b JOIN tk.trip tr "
                    + "WHERE tk.status <> 'ANNULÉ' "
                    + "AND b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                    + "AND tr.departureDateTime >= :from AND tr.departureDateTime < :to "
                    + "AND (:stationId IS NULL OR tr.station.id = :stationId) "
                    + "AND (:partnerId IS NULL OR tr.partner.id = :partnerId)")
    Long countActiveTicketsForPeriod(
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("stationId") Long stationId,
                    @Param("partnerId") Long partnerId);

    // Object[] (tripId, count) plutôt qu'une expression `new ...(...)` — évite toute question de
    // type au niveau JPQL (COUNT() renvoie toujours Long, aucun risque de mismatch avec un champ
    // de constructeur, contrairement à l'incident du 2026-09-01 sur un SUM() d'entier).
    @Query("SELECT tk.trip.id, COUNT(tk) FROM Ticket tk JOIN tk.booking b "
                    + "WHERE tk.status <> 'ANNULÉ' "
                    + "AND b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                    + "AND tk.trip.departureDateTime >= :from AND tk.trip.departureDateTime < :to "
                    + "AND (:stationId IS NULL OR tk.trip.station.id = :stationId) "
                    + "AND (:partnerId IS NULL OR tk.trip.partner.id = :partnerId) "
                    + "GROUP BY tk.trip.id")
    List<Object[]> ticketCountsPerTripForPeriod(
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("stationId") Long stationId,
                    @Param("partnerId") Long partnerId);

    // Courbe de croissance (Stats métier), métrique "Billets" — un point par jour civil, ticket
    // par ticket (jamais bookings). Native SQL comme dailyTripStatsBetween (BookingRepository).
    @Query(value = "SELECT DATE(t.departure_date_time) as day, COUNT(*) as cnt "
                    + "FROM tickets tk "
                    + "JOIN bookings b ON tk.booking_id = b.id "
                    + "JOIN trips t ON tk.trip_id = t.id "
                    + "WHERE tk.status <> 'ANNULÉ' "
                    + "AND b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                    + "AND t.departure_date_time >= :from AND t.departure_date_time < :to "
                    + "AND (:stationId IS NULL OR t.station_id = :stationId) "
                    + "AND (:partnerId IS NULL OR t.partner_id = :partnerId) "
                    + "GROUP BY DATE(t.departure_date_time) ORDER BY DATE(t.departure_date_time) ASC",
                    nativeQuery = true)
    List<Object[]> dailyActiveTicketsBetweenForTripStats(
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("stationId") Long stationId,
                    @Param("partnerId") Long partnerId);

     // Filtre de période sur tr.departureDateTime (date du VOYAGE), jamais t.bookingDate (date
     // d'achat) : voir BookingRepository.findForAdminList pour la justification — le partenaire/
     // gare n'est payé qu'après le voyage effectué, donc un ticket acheté en septembre pour un
     // trajet de novembre ne doit compter que dans les stats de novembre.
     @Query("SELECT t FROM Ticket t " +
                    "JOIN FETCH t.trip tr " +
                    "LEFT JOIN FETCH tr.partner " +
                    "JOIN FETCH t.passenger " +
                    "WHERE tr.departureDateTime >= :from AND tr.departureDateTime <= :to " +
                    "AND (:search IS NULL OR :search = '' " +
                    "     OR LOWER(t.ticketNumber) LIKE LOWER(CONCAT('%', :search, '%')) " +
                    "     OR LOWER(t.passengerName) LIKE LOWER(CONCAT('%', :search, '%'))) " +
                    "ORDER BY tr.departureDateTime DESC")
    List<Ticket> findForAdminList(
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("search") String search);
                    
    @Query("SELECT t FROM Ticket t " +
                    "JOIN FETCH t.trip tr " +
                    "LEFT JOIN FETCH tr.station " +
                    "JOIN FETCH t.passenger " +
                    "LEFT JOIN FETCH t.booking b " +
                    "LEFT JOIN FETCH b.customer " +
                    "WHERE tr.partner.id = :partnerId " +
                    "AND (:stationId IS NULL OR tr.station.id = :stationId) " +
                    // Voir findForAdminList : période sur la date du voyage, pas la date d'achat.
                    "AND tr.departureDateTime >= :from AND tr.departureDateTime <= :to " +
                    "AND (:search IS NULL OR :search = '' OR LOWER(t.passengerName) LIKE LOWER(CONCAT('%', :search, '%'))) "
                    +
                    "ORDER BY tr.departureDateTime DESC")
    List<Ticket> findForPartnerList(
                    @Param("partnerId") Long partnerId,
                    @Param("stationId") Long stationId,
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("search") String search);
}