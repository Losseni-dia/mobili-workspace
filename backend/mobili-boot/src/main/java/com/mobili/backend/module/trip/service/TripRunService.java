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
import com.mobili.backend.module.trip.entity.TripStop;
import com.mobili.backend.module.trip.entity.TripStopEvent;
import com.mobili.backend.module.trip.entity.TripStopEventType;
import com.mobili.backend.module.trip.repository.TripStopEventRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TripRunService {

    private final TripStopEventRepository tripStopEventRepository;
    private final BookingRepository bookingRepository;
    private final TicketRepository ticketRepository;
    private final TripStopSyncService tripStopSyncService;

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
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d’embarquement invalide.");
        }
        if (alightingStopIndex <= boardingStopIndex || alightingStopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Indice de descente invalide (doit être après l’embarquement).");
        }
    }

    /** Vente / réservation avec embarquement à cet arrêt encore autorisée (horaire + événement départ). */
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
                    "L’heure planifiée de départ depuis cet arrêt est passée : plus de réservation.");
        }
    }

    @Transactional
    public void recordDepartureFromStop(Trip trip, int stopIndex, LocalDateTime recordedAt) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        if (stopIndex < 0 || stopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d’arrêt invalide.");
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
    }

    @Transactional(readOnly = true)
    public List<AlightingPassengerResponse> listAlightingPassengers(Trip trip, int stopIndex) {
        ensureStops(trip);
        int last = lastStopIndex(trip);
        if (stopIndex < 0 || stopIndex > last) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Indice d’arrêt invalide.");
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

    /**
     * Sièges occupés sur le tronçon (arrêt legIndex → legIndex+1).
     *
     * @param defaultAlightingStopIndex indice du terminus pour les tickets/résas sans fin de segment explicite
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
            if (b.getStatus() != BookingStatus.PENDING
                    && b.getStatus() != BookingStatus.CONFIRMED
                    && b.getStatus() != BookingStatus.OFFLINE_SALE) {
                continue;
            }
            int from = Optional.ofNullable(b.getBoardingStopIndex()).orElse(0);
            int to = Optional.ofNullable(b.getAlightingStopIndex()).orElse(defaultAlightingStopIndex);
            if (!(from <= legIndex && legIndex < to)) {
                continue;
            }
            seats.addAll(b.getSeatNumbers());
        }
        return seats;
    }

    /** Nombre minimum de places libres sur tous les tronçons du segment [board, alight). */
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
