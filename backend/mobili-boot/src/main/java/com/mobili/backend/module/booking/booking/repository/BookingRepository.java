
package com.mobili.backend.module.booking.booking.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

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

        // Rattrapage ponctuel : BookingService.createOfflineSale() n'appelait jamais
        // generateTicketsWithCommission() avant son correctif — toute vente guichet enregistrée
        // avant ce fix n'a donc aucun Ticket associé. `b.tickets IS EMPTY` cible précisément ces
        // réservations pour leur générer leurs tickets manquants a posteriori (voir
        // BookingService.backfillMissingOfflineSaleTickets). LEFT JOIN FETCH sur trip/partner
        // seuls (to-one), aucun risque de duplication de collection.
        @Query("SELECT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "WHERE b.status = com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE " +
                        "AND b.tickets IS EMPTY")
        List<Booking> findOfflineSaleBookingsWithoutTickets();

        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE t.id = :tripId " +
                        "ORDER BY b.bookingDate DESC")
        List<Booking> findAllByTripIdWithDetails(@Param("tripId") Long tripId);

        // ATTENTION : b.tickets (List) n'est PLUS fetch-jointe ici avec b.passengerNames/
        // b.seatNumbers (Set) — combiner un fetch de List avec un ou plusieurs fetch de Set(s)
        // dans la même requête JPQL produit un produit cartésien que Hibernate hydrate en
        // DUPLIQUANT chaque entrée de la List autant de fois qu'il y a de lignes SQL générées
        // par les autres collections (ex: 2 sièges × 2 noms passagers = chaque ticket dupliqué
        // ×4 dans booking.getTickets()) — DISTINCT sur `b` ne déduplique QUE l'entité racine,
        // jamais ses collections filles. Bug constaté en production : montants multipliés par
        // 4 sur les réservations à plusieurs sièges (Booking.getGrossAmount() sommant des
        // tickets dupliqués), et risque équivalent sur toute logique itérant sur les tickets
        // (annulation, remboursement, décompte de sièges). Voir findByIdWithDetails ci-dessous
        // pour le correctif (méthode default qui charge les tickets dans une requête séparée).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.station " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE b.id = :id")
        Optional<Booking> findByIdWithDetailsRaw(@Param("id") Long id);

        /**
         * cancelBooking/cancelTickets (annulation, cascade vers les tickets) et getGrossAmount()
         * ont besoin de b.tickets sans lazy-load — chargée ici dans une requête séparée (jamais
         * dans la même que passengerNames/seatNumbers, voir Javadoc de findByIdWithDetailsRaw).
         */
        @Transactional(readOnly = true)
        default Optional<Booking> findByIdWithDetails(Long id) {
                return findByIdWithDetailsRaw(id).map(b -> {
                        b.getTickets().size();
                        return b;
                });
        }

        // ATTENTION : voir Javadoc de findByIdWithDetailsRaw — b.tickets ne doit jamais être
        // fetch-jointe avec b.seatNumbers dans la même requête (duplication des tickets).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE b.trip.id = :tripId " +
                        "AND b.status != com.mobili.backend.module.booking.booking.entity.BookingStatus.CANCELLED")
        List<Booking> findByTripIdWithSeatsRaw(@Param("tripId") Long tripId);

        /**
         * TripRunService.seatsOccupiedOnLeg() doit savoir si une réservation a déjà des tickets
         * générés pour ne pas compter en double avec la boucle ticket (seule source fiable une
         * fois les tickets émis, notamment après une annulation partielle — voir son Javadoc).
         */
        @Transactional(readOnly = true)
        default List<Booking> findByTripIdWithSeats(Long tripId) {
                List<Booking> bookings = findByTripIdWithSeatsRaw(tripId);
                bookings.forEach(b -> b.getTickets().size());
                return bookings;
        }


        // JOIN FETCH b.trip / b.customer : sans ça, BookingMapper.toDto() déréférence plusieurs
        // proxies Hibernate hors session (open-in-view désactivé) -> LazyInitializationException
        // -> 500 avalé en liste vide côté frontend (modale "Passagers" toujours vide malgré des
        // réservations bien présentes en base) : trip.id/departureCity/... et
        // customer.firstname/lastname (mapping direct). b.tickets chargée séparément ci-dessous
        // (jamais fetch-jointe avec seatNumbers/passengerNames, voir Javadoc de
        // findByIdWithDetailsRaw : duplication des tickets sinon, montants faussés).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "WHERE t.id = :tripId " +
                        "AND b.status IN (" +
                        "com.mobili.backend.module.booking.booking.entity.BookingStatus.CONFIRMED, " +
                        "com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE)")
        List<Booking> findConfirmedByTripIdWithDetailsRaw(@Param("tripId") Long tripId);

        @Transactional(readOnly = true)
        default List<Booking> findConfirmedByTripIdWithDetails(Long tripId) {
                List<Booking> bookings = findConfirmedByTripIdWithDetailsRaw(tripId);
                bookings.forEach(b -> b.getTickets().size());
                return bookings;
        }


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

        // b.tickets chargée séparément (méthode default ci-dessous) — jamais fetch-jointe avec
        // passengerNames/seatNumbers, voir Javadoc de findByIdWithDetailsRaw (duplication des
        // tickets, montants "Dernières réservations" multipliés par le nb de sièges/passagers).
        // status IN (...) : exclut les tentatives de paiement échouées/abandonnées (PENDING,
        // CANCELLED, EXPIRED...) de "Dernières réservations" (feedback testeurs) — seules les
        // réservations réellement payées/valides doivent y figurer.
        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer " +
                        "LEFT JOIN FETCH b.passengerNames LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE t.partner.id = :partnerId AND t.station.id = :stationId " +
                        "AND b.status IN ('CONFIRMED', 'OFFLINE_SALE', 'COMPLETED') ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByPartnerAndStationRaw(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId);

        /** Booking.getGrossAmount() (PartnerMapper) lit les tickets pour exclure ceux ANNULÉ. */
        @Transactional(readOnly = true)
        default List<Booking> findRecentBookingsByPartnerAndStation(Long partnerId, Long stationId) {
                List<Booking> bookings = findRecentBookingsByPartnerAndStationRaw(partnerId, stationId);
                bookings.forEach(b -> b.getTickets().size());
                return bookings;
        }

        @Query("SELECT COUNT(b) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.trip.station.id = :stationId AND b.status = 'CONFIRMED'")
        long countBookingsByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

        @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.trip.partner.id = :partnerId AND b.trip.station.id = :stationId AND b.status = 'CONFIRMED'")
        Double calculateRevenueByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

        // b.tickets chargée séparément, voir findRecentBookingsByPartnerAndStationRaw. status IN
        // (...) : même exclusion des tentatives échouées/abandonnées, voir commentaire ci-dessus.
        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.passengerNames LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE t.partner.id = :partnerId " +
                        "AND b.status IN ('CONFIRMED', 'OFFLINE_SALE', 'COMPLETED') ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByPartnerRaw(@Param("partnerId") Long partnerId);

        @Transactional(readOnly = true)
        default List<Booking> findRecentBookingsByPartner(Long partnerId) {
                List<Booking> bookings = findRecentBookingsByPartnerRaw(partnerId);
                bookings.forEach(b -> b.getTickets().size());
                return bookings;
        }

        /** Dashboard conducteur covoiturage : réservations sur SES trajets, jamais ceux du pool entier. */
        @Query("SELECT DISTINCT b FROM Booking b JOIN FETCH b.trip t JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.passengerNames LEFT JOIN FETCH b.seatNumbers " +
                        "WHERE t.covoiturageOrganizer.id = :organizerId ORDER BY b.createdAt DESC")
        List<Booking> findRecentBookingsByCovoiturageOrganizerRaw(@Param("organizerId") Long organizerId);

        @Transactional(readOnly = true)
        default List<Booking> findRecentBookingsByCovoiturageOrganizer(Long organizerId) {
                List<Booking> bookings = findRecentBookingsByCovoiturageOrganizerRaw(organizerId);
                bookings.forEach(b -> b.getTickets().size());
                return bookings;
        }


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

        // CA plateforme all-time par canal (vue d'ensemble admin) — AdminService.getGlobalStats()
        // additionne les deux pour le total affiché : plus de sumTotalRevenue() séparé (ancienne
        // requête sommant TOUTE réservation non-CANCELLED, y compris PENDING/EXPIRED jamais
        // payées — un périmètre plus large et incohérent avec cette répartition CONFIRMED/
        // OFFLINE_SALE, qui faisait paraître une vente guichet "juste visible" dans le détail
        // sans être reflétée dans le total).
        @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.status = com.mobili.backend.module.booking.booking.entity.BookingStatus.CONFIRMED")
        Double sumRevenueOnline();

        @Query("SELECT COALESCE(SUM(b.totalPrice), 0) FROM Booking b WHERE b.status = com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE")
        Double sumRevenueOffline();

        // Période sur t.departureDateTime (date du VOYAGE), jamais b.createdAt (date d'achat) —
        // voir findForAdminList/findConfirmedForAdminTransactions pour la justification :
        // une résa faite aujourd'hui pour un trajet le mois prochain ne doit compter que dans
        // les stats du mois du voyage, pas celles d'aujourd'hui. stationId/partnerId optionnels
        // pour scoper les Stats métier à une gare ou une compagnie précise.
        @Query("SELECT new com.mobili.backend.module.booking.booking.projection.TripStatsAggrJpa("
                        + "COALESCE(SUM(b.totalPrice), 0.0), COUNT(b), COUNT(DISTINCT t.id), "
                        + "COALESCE(SUM(CASE WHEN b.status = com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE THEN 0.0 ELSE b.totalPrice END), 0.0), "
                        + "COALESCE(SUM(CASE WHEN b.status = com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE THEN b.totalPrice ELSE 0.0 END), 0.0), "
                        // b.serviceFee est un entier (Integer) : SUM() sur un entier renvoie un Long en
                        // JPQL, incompatible avec le paramètre Double du constructeur TripStatsAggrJpa —
                        // Hibernate valide ces types au démarrage pour une expression `new ...(...)`, un
                        // tel mismatch a fait planter tout le contexte Spring en prod (incident du
                        // 2026-09-01). `* 1.0` force la promotion en double AVANT l'agrégation.
                        + "COALESCE(SUM(b.serviceFee * 1.0), 0.0)) "
                        + "FROM Booking b JOIN b.trip t "
                        + "WHERE b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                        + "AND t.departureDateTime >= :from AND t.departureDateTime < :to "
                        + "AND (:stationId IS NULL OR t.station.id = :stationId) "
                        + "AND (:partnerId IS NULL OR t.partner.id = :partnerId)")
        TripStatsAggrJpa aggregateForTripStats(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("stationId") Long stationId,
                        @Param("partnerId") Long partnerId);

        // Commission Mobili prélevée sur la période — au niveau TICKET (jamais réservation, la
        // commission se calcule par siège/ticket, voir CompanyCommissionService), tickets actifs
        // uniquement (hors ANNULÉ). Requête séparée de aggregateForTripStats ci-dessus : joindre
        // b.tickets dans une requête d'agrégat SUM(b.totalPrice) sans GROUP BY par booking
        // dupliquerait ces sommes (Cartesian product), voir Javadoc findByIdWithDetailsRaw.
        @Query("SELECT COALESCE(SUM(t.commissionAmount), 0) FROM Ticket t "
                        + "JOIN t.booking b JOIN t.trip tr "
                        + "WHERE t.status <> com.mobili.backend.module.booking.ticket.entity.TicketStatus.ANNULÉ "
                        + "AND b.status IN (com.mobili.backend.module.booking.booking.entity.BookingStatus.CONFIRMED, "
                        + "                 com.mobili.backend.module.booking.booking.entity.BookingStatus.COMPLETED, "
                        + "                 com.mobili.backend.module.booking.booking.entity.BookingStatus.OFFLINE_SALE) "
                        + "AND tr.departureDateTime >= :from AND tr.departureDateTime < :to "
                        + "AND (:stationId IS NULL OR tr.station.id = :stationId) "
                        + "AND (:partnerId IS NULL OR tr.partner.id = :partnerId)")
        // t.commissionAmount est un Integer : SUM() renvoie un Long en JPQL — retour déclaré en
        // Long (pas Integer) pour rester exact, même si Spring convertit silencieusement Long→
        // Integer sur un résultat scalaire simple (contrairement à une expression `new ...(...)`).
        Long sumCommissionForPeriod(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("stationId") Long stationId,
                        @Param("partnerId") Long partnerId);

        @Query("SELECT new com.mobili.backend.module.booking.booking.projection.TripStatsPerTripJpa("
                        + "t.id, t.departureCity, t.arrivalCity, p.name, "
                        + "CASE WHEN t.station IS NOT NULL THEN t.station.name ELSE '—' END, "
                        + "COUNT(b), COALESCE(SUM(b.totalPrice), 0.0)) "
                        + "FROM Booking b JOIN b.trip t JOIN t.partner p "
                        + "WHERE b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                        + "AND t.departureDateTime >= :from AND t.departureDateTime < :to "
                        + "AND (:stationId IS NULL OR t.station.id = :stationId) "
                        + "AND (:partnerId IS NULL OR t.partner.id = :partnerId) "
                        + "GROUP BY t.id, t.departureCity, t.arrivalCity, p.id, p.name, t.station.name "
                        + "ORDER BY COALESCE(SUM(b.totalPrice), 0.0) DESC, t.id ASC")
        List<TripStatsPerTripJpa> findTripStatsOrderedByRevenue(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("stationId") Long stationId,
                        @Param("partnerId") Long partnerId);

        // Courbe de croissance (Stats métier) : un point par jour civil, sur la date de départ
        // du trajet — même principe que les requêtes ci-dessus. Native SQL (comme
        // TicketRepository.dailyTicketsBetween déjà existant) : DATE() sur une jointure native
        // est plus simple à exprimer qu'en JPQL portable.
        @Query(value = "SELECT DATE(t.departure_date_time) as day, COUNT(*) as cnt, COALESCE(SUM(b.total_price), 0) as rev "
                        + "FROM bookings b JOIN trips t ON b.trip_id = t.id "
                        + "WHERE b.status IN ('CONFIRMED','COMPLETED','OFFLINE_SALE') "
                        + "AND t.departure_date_time >= :from AND t.departure_date_time < :to "
                        + "AND (:stationId IS NULL OR t.station_id = :stationId) "
                        + "AND (:partnerId IS NULL OR t.partner_id = :partnerId) "
                        + "GROUP BY DATE(t.departure_date_time) ORDER BY DATE(t.departure_date_time) ASC", nativeQuery = true)
        List<Object[]> dailyTripStatsBetween(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("stationId") Long stationId,
                        @Param("partnerId") Long partnerId);

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


        // Filtre de période sur t.departureDateTime (date du VOYAGE), jamais b.bookingDate (date
        // d'achat) : le partenaire/gare n'est payé qu'une fois le voyage effectué, donc une
        // vente de septembre pour un trajet de novembre ne doit apparaître que dans le mois de
        // novembre — sinon la gare voit un montant qu'elle ne peut pas encore percevoir.
        @Query("SELECT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "LEFT JOIN FETCH t.partner " +
                        "JOIN FETCH b.customer c " +
                        "WHERE t.departureDateTime >= :from AND t.departureDateTime <= :to " +
                        "AND (:search IS NULL OR :search = '' " +
                        "     OR LOWER(b.reference) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.firstname) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.lastname) LIKE LOWER(CONCAT('%', :search, '%'))) " +
                        "ORDER BY t.departureDateTime DESC")
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
                        // Voir findForAdminList : période sur la date du voyage, pas la date d'achat.
                        "AND t.departureDateTime >= :from AND t.departureDateTime <= :to " +
                        "AND (:search IS NULL OR :search = '' " +
                        "     OR LOWER(b.reference) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.firstname) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(c.lastname) LIKE LOWER(CONCAT('%', :search, '%')) " +
                        "     OR LOWER(t.partner.name) LIKE LOWER(CONCAT('%', :search, '%'))) " +
                        // Chronologique croissant (1er, 2, 3... du mois) — le regroupement par
                        // jour de la page Transactions se lit alors dans l'ordre naturel, jamais
                        // à l'envers (30, 29, 28...).
                        "ORDER BY t.departureDateTime ASC")
        List<Booking> findConfirmedForAdminTransactions(
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to,
                        @Param("search") String search);

        // b.tickets chargée séparément (méthode default ci-dessous, + initLazyCollections côté
        // service) — jamais fetch-jointe avec seatNumbers/passengerNames, voir Javadoc de
        // findByIdWithDetailsRaw : duplication des tickets sinon — BUG CONSTATÉ EN PRODUCTION,
        // montants "/partenaire/bookings" multipliés par le nb de sièges×passagers sur toute
        // réservation à plusieurs tickets (Booking.getGrossAmount() sommant des doublons).
        // Alimente BookingMapper.toDto (champ amount = booking.getGrossAmount()).
        @Query("SELECT DISTINCT b FROM Booking b " +
                        "JOIN FETCH b.trip t " +
                        "JOIN FETCH b.customer c " +
                        "LEFT JOIN FETCH b.seatNumbers " +
                        "LEFT JOIN FETCH b.passengerNames " +
                        "WHERE t.partner.id = :partnerId AND (:stationId IS NULL OR t.station.id = :stationId) " +
                        // Voir findForAdminList : période sur la date du voyage, pas la date de création.
                        "AND t.departureDateTime >= :from AND t.departureDateTime <= :to " +
                        "ORDER BY t.departureDateTime DESC")
        List<Booking> findAllByPartnerIdAndOptionalStationIdAndDateRangeRaw(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId,
                        @Param("from") java.time.LocalDateTime from,
                        @Param("to") java.time.LocalDateTime to);

        @Transactional(readOnly = true)
        default List<Booking> findAllByPartnerIdAndOptionalStationIdAndDateRange(
                        Long partnerId, Long stationId, java.time.LocalDateTime from, java.time.LocalDateTime to) {
                List<Booking> bookings = findAllByPartnerIdAndOptionalStationIdAndDateRangeRaw(partnerId, stationId, from, to);
                bookings.forEach(b -> b.getTickets().size());
                return bookings;
        }

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
                        // Voir findForAdminList : période sur la date du voyage, pas la date d'achat.
                        "AND t.departureDateTime >= :from AND t.departureDateTime <= :to " +
                        // Chronologique croissant (1er, 2, 3... du mois) — voir
                        // findConfirmedForAdminTransactions.
                        "ORDER BY t.departureDateTime ASC")
        List<Booking> findConfirmedForPartnerTransactions(
                        @Param("partnerId") Long partnerId,
                        @Param("stationId") Long stationId,
                        @Param("from") LocalDateTime from,
                        @Param("to") LocalDateTime to);
}