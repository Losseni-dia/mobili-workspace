package com.mobili.backend.module.trip.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.entity.TicketStatus;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.trip.dto.driver.AlightingPassengerResponse;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.entity.TripStop;
import com.mobili.backend.module.trip.entity.TripStopEvent;
import com.mobili.backend.module.trip.entity.TripStopEventType;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.repository.TripStopEventRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TripRunService {

    private final TripStopEventRepository tripStopEventRepository;
    private final BookingRepository bookingRepository;
    private final TicketRepository ticketRepository;
    private final TripStopSyncService tripStopSyncService;
    private final TripRepository tripRepository;

    /**
     * Verrou pessimiste exclusif sur la ligne du trajet (SELECT ... FOR UPDATE), tenu jusqu'au
     * commit de la transaction appelante — à appeler avant toute vérification de disponibilité
     * de sièges (assertSeatsAvailableOnSegment/minFreeSeatsOnSegment) suivie d'une écriture, pour
     * sérialiser les créations de réservation concurrentes sur ce trajet. Doit être appelé dans
     * une méthode {@code @Transactional} de l'appelant (le verrou n'a d'effet que le temps de
     * cette transaction).
     */
    public void lockTrip(Trip trip) {
        tripRepository.lockForSeatUpdate(trip.getId());
    }

    public int lastStopIndex(Trip trip) {
        ensureStops(trip);
        return trip.getStops().stream().mapToInt(TripStop::getStopIndex).max().orElse(0);
    }

    public void ensureStops(Trip trip) {
        if (trip.getStops() == null || trip.getStops().isEmpty()) {
            tripStopSyncService.syncStopsForTrip(trip);
        }
    }

    public void validateSegment(Trip trip, int boardingStopIndex, int alightingStopIndex) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        if (boardingStopIndex < 0 || boardingStopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d'embarquement invalide.");
        }
        if (alightingStopIndex <= boardingStopIndex || alightingStopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Indice de descente invalide (doit être après l'embarquement).");
        }
    }

    /**
     * Vente / réservation avec embarquement à cet arrêt encore autorisée (horaire +
     * événement départ).
     */
    public void assertBoardingStillOpen(Trip trip, int boardingStopIndex, LocalDateTime now) {
        ensureStops(trip);
        TripStop stop = trip.getStops().stream()
                .filter(s -> s.getStopIndex() == boardingStopIndex)
                .findFirst()
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Arrêt inconnu."));

        if (tripStopEventRepository.existsByTripIdAndStopIndexAndEventType(
                trip.getId(), boardingStopIndex, TripStopEventType.DEPARTURE_FROM_STOP)) {
            throw new MobiliException(MobiliErrorCode.BOARDING_CLOSED,
                    "Le car a déjà quitté cet arrêt : plus de réservation avec embarquement ici.");
        }
        if (!now.isBefore(stop.getPlannedDepartureAt())) {
            throw new MobiliException(MobiliErrorCode.BOARDING_CLOSED,
                    "L'heure planifiée de départ depuis cet arrêt est passée : plus de réservation.");
        }
    }

    /**
     * Vrai si le car a déjà quitté cet arrêt (recherche voyageur : un trajet
     * passant par cette ville ne doit plus apparaître comme embarquement
     * possible une fois l'arrêt dépassé).
     */
    @Transactional(readOnly = true)
    public boolean isBoardingClosedAtStop(Long tripId, int stopIndex) {
        return tripStopEventRepository.existsByTripIdAndStopIndexAndEventType(
                tripId, stopIndex, TripStopEventType.DEPARTURE_FROM_STOP);
    }

    /**
     * Ville du prochain arrêt non encore quitté (catalogue voyageur : "En route
     * vers X"). {@code null} si le trajet n'a pas encore démarré ou si le
     * dernier arrêt a déjà été quitté (trajet en fin de course).
     */
    @Transactional(readOnly = true)
    public String nextStopCityOrNull(Trip trip) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        int currentStop = tripStopEventRepository
                .findMaxStopIndexByTripIdAndEventType(trip.getId(), TripStopEventType.DEPARTURE_FROM_STOP)
                .orElse(-1);
        int nextIndex = currentStop + 1;
        if (nextIndex > last) {
            return null;
        }
        return trip.getStops().stream()
                .filter(s -> s.getStopIndex() == nextIndex)
                .map(TripStop::getCityLabel)
                .findFirst()
                .orElse(null);
    }

    @Transactional
    public void recordDepartureFromStop(Trip trip, int stopIndex, LocalDateTime recordedAt) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        if (stopIndex < 0 || stopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d'arrêt invalide.");
        }
        if (tripStopEventRepository.existsByTripIdAndStopIndexAndEventType(
                trip.getId(), stopIndex, TripStopEventType.DEPARTURE_FROM_STOP)) {
            return;
        }
        TripStopEvent ev = new TripStopEvent();
        ev.setTrip(trip);
        ev.setStopIndex(stopIndex);
        ev.setEventType(TripStopEventType.DEPARTURE_FROM_STOP);
        ev.setRecordedAt(recordedAt);
        tripStopEventRepository.save(ev);

        // ── Statuts automatiques ─────────────────────────────────────────────

        // Tickets dont l'arrêt de descente prévu = cet arrêt
        List<Ticket> tickets = ticketRepository.findAllByTripIdOrderBySeatNumberAsc(trip.getId());
        for (Ticket t : tickets) {
            if (t.getStatus() == TicketStatus.ANNULÉ)
                continue;
            int plannedAlight = Optional.ofNullable(t.getAlightingStopIndex()).orElse(last);
            if (plannedAlight != stopIndex)
                continue;
            if (t.getStatus() == TicketStatus.UTILISÉ) {
                // À bord → Arrivé automatiquement
                t.setStatus(TicketStatus.ARRIVÉ);
                t.setAlightedAtStopIndex(stopIndex);
                t.setAlightedAt(recordedAt);
                ticketRepository.saveAndFlush(t);
            }
            // VALIDÉ (non présenté) → reste VALIDÉ, affiché "Non présenté" côté Flutter
        }

        // Dernier arrêt → trajet TERMINÉ ; sinon (y compris le départ de la ville de
        // départ) → trajet EN_COURS.
        tripRepository.findById(trip.getId()).ifPresent(freshTrip -> {
            if (freshTrip.getStatus() != TripStatus.ANNULÉ) {
                freshTrip.setStatus(stopIndex == last ? TripStatus.TERMINÉ : TripStatus.EN_COURS);
            }
            refreshTripAvailableSeatsCounter(freshTrip);
            tripRepository.saveAndFlush(freshTrip);
        });
    }

    /**
     * Annule le <strong>dernier</strong> départ enregistré (erreur de clic du
     * chauffeur) : supprime l'événement, remet "à bord" les billets qui
     * venaient d'être marqués "arrivé" à cet arrêt, et recalcule le statut du
     * trajet. Toujours le dernier arrêt quitté, jamais un arrêt arbitraire,
     * pour ne pas désynchroniser l'historique.
     *
     * @return l'indice de l'arrêt où le car se retrouve (= arrêt dont le
     *         départ vient d'être annulé)
     */
    @Transactional
    public int undoLastDeparture(Trip trip) {
        int currentStop = tripStopEventRepository
                .findMaxStopIndexByTripIdAndEventType(trip.getId(), TripStopEventType.DEPARTURE_FROM_STOP)
                .orElse(-1);
        if (currentStop < 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Aucun départ à annuler.");
        }
        tripStopEventRepository.deleteByTripIdAndStopIndexAndEventType(
                trip.getId(), currentStop, TripStopEventType.DEPARTURE_FROM_STOP);

        for (Ticket t : ticketRepository.findAllByTripIdOrderBySeatNumberAsc(trip.getId())) {
            if (t.getStatus() == TicketStatus.ARRIVÉ
                    && t.getAlightedAtStopIndex() != null
                    && t.getAlightedAtStopIndex() == currentStop) {
                t.setStatus(TicketStatus.UTILISÉ);
                t.setAlightedAtStopIndex(null);
                t.setAlightedAt(null);
                ticketRepository.saveAndFlush(t);
            }
        }

        tripRepository.findById(trip.getId()).ifPresent(freshTrip -> {
            if (freshTrip.getStatus() != TripStatus.ANNULÉ) {
                freshTrip.setStatus(currentStop == 0 ? TripStatus.PROGRAMMÉ : TripStatus.EN_COURS);
            }
            refreshTripAvailableSeatsCounter(freshTrip);
            tripRepository.saveAndFlush(freshTrip);
        });
        return currentStop;
    }

    @Transactional(readOnly = true)
    public List<AlightingPassengerResponse> listAlightingPassengers(Trip trip, int stopIndex) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        if (stopIndex < 0 || stopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d'arrêt invalide.");
        }
        List<AlightingPassengerResponse> out = new ArrayList<>();
        List<Ticket> tickets = ticketRepository.findAllByTripIdOrderBySeatNumberAsc(trip.getId());
        for (Ticket t : tickets) {
            if (t.getStatus() == TicketStatus.ANNULÉ) {
                continue;
            }
            int plannedAlight = Optional.ofNullable(t.getAlightingStopIndex()).orElse(last);
            if (plannedAlight != stopIndex) {
                continue;
            }
            if (t.getAlightedAtStopIndex() != null) {
                continue;
            }
            out.add(new AlightingPassengerResponse(
                    t.getTicketNumber(),
                    t.getPassengerName(),
                    t.getSeatNumber(),
                    t.getStatus().name(),
                    Optional.ofNullable(t.getBoardingStopIndex()).orElse(0)));
        }
        out.sort(Comparator.comparing(AlightingPassengerResponse::seatNumber));
        return out;
    }

    @Transactional(readOnly = true)
    public List<AlightingPassengerResponse> listBoardingPassengers(Trip trip, int stopIndex) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        if (stopIndex < 0 || stopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d'arrêt invalide.");
        }
        List<AlightingPassengerResponse> out = new ArrayList<>();
        List<Ticket> tickets = ticketRepository.findAllByTripIdOrderBySeatNumberAsc(trip.getId());
        for (Ticket t : tickets) {
            if (t.getStatus() == TicketStatus.ANNULÉ)
                continue;
            int plannedBoarding = Optional.ofNullable(t.getBoardingStopIndex()).orElse(0);
            if (plannedBoarding != stopIndex)
                continue;
            out.add(new AlightingPassengerResponse(
                    t.getTicketNumber(),
                    t.getPassengerName(),
                    t.getSeatNumber(),
                    t.getStatus().name(),
                    plannedBoarding));
        }
        out.sort(Comparator.comparing(AlightingPassengerResponse::seatNumber));
        return out;
    }

    /**
     * Sièges occupés sur le tronçon (arrêt legIndex → legIndex+1).
     *
     * Deux sources : les tickets (émis après paiement confirmé, seule source fiable au
     * niveau du SIÈGE puisqu'un ticket peut être annulé individuellement — voir
     * TicketService.cancelTicket) et, pour les réservations sans ticket encore émis
     * (PENDING avant paiement), les sièges bruts de la réservation. Une fois les tickets
     * émis pour une réservation, on ne retombe JAMAIS sur booking.getSeatNumbers() pour
     * elle : cet ensemble reste figé à la vente d'origine et ne reflète pas l'annulation
     * d'un seul ticket parmi plusieurs — le compter en plus des tickets aurait occupé un
     * siège déjà libéré individuellement (siège fantôme, jamais revendable).
     */
    public Set<String> seatsOccupiedOnLeg(Long tripId, int legIndex, int defaultAlightingStopIndex) {
        Set<String> seats = new HashSet<>();
        for (Ticket t : ticketRepository.findAllByTripIdOrderBySeatNumberAsc(tripId)) {
            if (t.getStatus() == TicketStatus.ANNULÉ) {
                continue;
            }
            if (t.getStatus() != TicketStatus.VALIDÉ && t.getStatus() != TicketStatus.UTILISÉ) {
                continue;
            }
            int b = Optional.ofNullable(t.getBoardingStopIndex()).orElse(0);
            int endExclusive = Optional.ofNullable(t.getAlightedAtStopIndex())
                    .orElse(Optional.ofNullable(t.getAlightingStopIndex()).orElse(defaultAlightingStopIndex));
            if (b <= legIndex && legIndex < endExclusive) {
                seats.add(t.getSeatNumber());
            }
        }
        
        List<Booking> bookings = bookingRepository.findByTripIdWithSeats(tripId);
        for (Booking b : bookings) {
            if (b.getStatus() == BookingStatus.CANCELLED) {
                continue;
            }
            // Une fois les tickets émis pour cette réservation, la boucle ticket ci-dessus
            // fait déjà foi pour ses sièges (à jour siège par siège) — la compter ici aussi
            // recompterait un siège déjà libéré par une annulation partielle.
            if (b.getTickets() != null && !b.getTickets().isEmpty()) {
                continue;
            }
            if (b.getStatus() != BookingStatus.PENDING
                    && b.getStatus() != BookingStatus.CONFIRMED
                    && b.getStatus() != BookingStatus.OFFLINE_SALE
                    && b.getStatus() != BookingStatus.PENDING_DRIVER_APPROVAL
                    && b.getStatus() != BookingStatus.AWAITING_PAYMENT) {
                continue;
            }
            int bb = Optional.ofNullable(b.getBoardingStopIndex()).orElse(0);
            int bEndExclusive = Optional.ofNullable(b.getAlightingStopIndex()).orElse(defaultAlightingStopIndex);
            if (bb <= legIndex && legIndex < bEndExclusive) {
                seats.addAll(b.getSeatNumbers());
            }
        }
        return seats;
    }

    /**
     * Nombre minimum de places libres sur tous les tronçons du segment [board,
     * alight).
     */
    public int minFreeSeatsOnSegment(Trip trip, int boardingStopIndex, int alightingStopIndex) {
        ensureStops(trip);
        int lastIdx = lastStopIndex(trip);
        int total = trip.getTotalSeats();
        int minFree = total;
        for (int leg = boardingStopIndex; leg < alightingStopIndex; leg++) {
            int occ = seatsOccupiedOnLeg(trip.getId(), leg, lastIdx).size();
            minFree = Math.min(minFree, total - occ);
        }
        return minFree;
    }

    public void assertSeatsAvailableOnSegment(Trip trip, int boardingStopIndex, int alightingStopIndex,
            List<String> seatNumbers) {
        int lastIdx = lastStopIndex(trip);
        for (String seat : seatNumbers) {
            for (int leg = boardingStopIndex; leg < alightingStopIndex; leg++) {
                Set<String> occ = seatsOccupiedOnLeg(trip.getId(), leg, lastIdx);
                if (occ.contains(seat)) {
                    throw new MobiliException(MobiliErrorCode.NO_SEATS_AVAILABLE,
                            "Le siège " + seat + " est déjà pris sur une portion du trajet.");
                }
            }
        }
    }

    public void refreshTripAvailableSeatsCounter(Trip trip) {
        ensureStops(trip);
        int lastIdx = lastStopIndex(trip);
        int total = trip.getTotalSeats();
        int minFree = total;
        for (int leg = 0; leg < lastIdx; leg++) {
            int occ = seatsOccupiedOnLeg(trip.getId(), leg, lastIdx).size();
            minFree = Math.min(minFree, total - occ);
        }
        trip.setAvailableSeats(Math.max(0, minFree));
    }
}