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

    @Query("SELECT t FROM Ticket t JOIN FETCH t.trip WHERE t.passenger.id = :userId")
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

     @Query("SELECT t FROM Ticket t " +
                    "JOIN FETCH t.trip tr " +
                    "LEFT JOIN FETCH tr.partner " +
                    "JOIN FETCH t.passenger " +
                    "WHERE t.bookingDate >= :from AND t.bookingDate <= :to " +
                    "AND (:search IS NULL OR :search = '' " +
                    "     OR LOWER(t.ticketNumber) LIKE LOWER(CONCAT('%', :search, '%')) " +
                    "     OR LOWER(t.passengerName) LIKE LOWER(CONCAT('%', :search, '%'))) " +
                    "ORDER BY t.bookingDate DESC")
    List<Ticket> findForAdminList(
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("search") String search);
                    
    @Query("SELECT t FROM Ticket t " +
                    "JOIN FETCH t.trip tr " +
                    "LEFT JOIN FETCH tr.station " +
                    "JOIN FETCH t.passenger " +
                    "WHERE tr.partner.id = :partnerId " +
                    "AND (:stationId IS NULL OR tr.station.id = :stationId) " +
                    "AND t.bookingDate >= :from AND t.bookingDate <= :to " +
                    "AND t.status <> 'ANNULÉ' " +
                    "AND (:search IS NULL OR :search = '' OR LOWER(t.passengerName) LIKE LOWER(CONCAT('%', :search, '%'))) "
                    +
                    "ORDER BY t.bookingDate DESC")
    List<Ticket> findForPartnerList(
                    @Param("partnerId") Long partnerId,
                    @Param("stationId") Long stationId,
                    @Param("from") LocalDateTime from,
                    @Param("to") LocalDateTime to,
                    @Param("search") String search);
}