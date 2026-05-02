package com.mobili.backend.module.trip.service;

import java.util.List;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.trip.dto.TripLegFareRequest;
import com.mobili.backend.module.trip.dto.TripLegFareResponse;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripSegmentFare;
import com.mobili.backend.module.trip.repository.TripSegmentFareRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TripPricingService {

    private final TripRunService tripRunService;
    private final TripSegmentFareRepository tripSegmentFareRepository;

    /**
     * Si des tarifs existent en base pour chaque tronçon consécutif du segment demandé, retourne leur somme.
     * Sinon prorata du prix global du voyage sur les indices d'arrêt.
     */
    @Transactional(readOnly = true)
    public double resolvePricePerSeat(Trip trip, int boardingStopIndex, int alightingStopIndex) {
        tripRunService.ensureStops(trip);
        int last = tripRunService.lastStopIndex(trip);
        if (last <= 0) {
            return trip.getPrice() != null ? trip.getPrice() : 0.0;
        }
        // Parcours entier (premier → dernier arrêt) : tarif dédié, indépendant de la somme des tronçons.
        if (boardingStopIndex == 0 && alightingStopIndex == last
                && trip.getOriginDestinationPrice() != null) {
            return trip.getOriginDestinationPrice();
        }
        if (trip.getId() != null) {
            double sum = 0.0;
            boolean allPresent = true;
            for (int leg = boardingStopIndex; leg < alightingStopIndex; leg++) {
                Optional<TripSegmentFare> row = tripSegmentFareRepository.findByTrip_IdAndFromStopIndexAndToStopIndex(
                        trip.getId(), leg, leg + 1);
                if (row.isEmpty()) {
                    allPresent = false;
                    break;
                }
                sum += row.get().getPrice();
            }
            if (allPresent && alightingStopIndex > boardingStopIndex) {
                return sum;
            }
        }
        double base = trip.getPrice() != null ? trip.getPrice() : 0.0;
        return base * (alightingStopIndex - boardingStopIndex) / last;
    }

    /** Somme des prix des tronçons consécutifs [boarding, alighting) à partir d'une liste (aperçu sans persistance). */
    public double sumLegFaresForPath(List<TripLegFareRequest> legFares, int boardingStopIndex, int alightingStopIndex) {
        double sum = 0.0;
        for (int leg = boardingStopIndex; leg < alightingStopIndex; leg++) {
            final int from = leg;
            final int to = leg + 1;
            double p = legFares.stream()
                    .filter(f -> f.getFromStopIndex() != null && f.getToStopIndex() != null
                            && f.getFromStopIndex() == from && f.getToStopIndex() == to)
                    .map(TripLegFareRequest::getPrice)
                    .filter(v -> v != null)
                    .findFirst()
                    .orElseThrow(() -> new MobiliException(
                            MobiliErrorCode.VALIDATION_ERROR,
                            "Tarif manquant pour le tronçon " + from + " → " + to + "."));
            sum += p;
        }
        return sum;
    }

    @Transactional
    public void replaceConsecutiveLegFares(Trip trip, List<TripLegFareRequest> items) {
        if (trip.getId() == null) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Voyage non persisté : impossible d'enregistrer les tarifs tronçon.");
        }
        tripRunService.ensureStops(trip);
        int last = tripRunService.lastStopIndex(trip);
        tripSegmentFareRepository.deleteByTrip_Id(trip.getId());
        if (last <= 0) {
            return;
        }
        validateConsecutiveLegFaresAndSum(trip, items);
        for (int i = 0; i < last; i++) {
            final int from = i;
            TripLegFareRequest it = items.stream()
                    .filter(f -> f.getFromStopIndex() != null && f.getFromStopIndex() == from
                            && f.getToStopIndex() != null && f.getToStopIndex() == from + 1)
                    .findFirst()
                    .orElseThrow(() -> new MobiliException(
                            MobiliErrorCode.VALIDATION_ERROR, "Tronçon manquant : " + from + " → " + (from + 1) + "."));
            TripSegmentFare row = new TripSegmentFare();
            row.setTrip(trip);
            row.setFromStopIndex(from);
            row.setToStopIndex(from + 1);
            row.setPrice(it.getPrice());
            tripSegmentFareRepository.save(row);
        }
    }

    @Transactional
    public void clearSegmentFaresForTrip(Long tripId) {
        if (tripId == null) {
            return;
        }
        tripSegmentFareRepository.deleteByTrip_Id(tripId);
    }

    @Transactional(readOnly = true)
    public List<TripLegFareResponse> listLegFareResponses(Long tripId) {
        return tripSegmentFareRepository.findByTrip_IdOrderByFromStopIndexAscToStopIndexAsc(tripId).stream()
                .map(r -> new TripLegFareResponse(r.getFromStopIndex(), r.getToStopIndex(), r.getPrice()))
                .toList();
    }

    /**
     * Vérifie que la liste couvre exactement les tronçons 0→1, …, (last-1)→last et retourne la somme des prix.
     */
    public double validateConsecutiveLegFaresAndSum(Trip trip, List<TripLegFareRequest> items) {
        tripRunService.ensureStops(trip);
        int last = tripRunService.lastStopIndex(trip);
        if (last <= 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Au moins deux arrêts sont requis pour des tarifs par tronçon.");
        }
        if (items == null || items.size() != last) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR,
                    "Nombre de tarifs tronçon invalide : attendu " + last + " tronçon(s).");
        }
        double sum = 0.0;
        for (int i = 0; i < last; i++) {
            final int from = i;
            TripLegFareRequest it = items.stream()
                    .filter(f -> f.getFromStopIndex() != null && f.getFromStopIndex() == from
                            && f.getToStopIndex() != null && f.getToStopIndex() == from + 1)
                    .findFirst()
                    .orElseThrow(() -> new MobiliException(
                            MobiliErrorCode.VALIDATION_ERROR,
                            "Tronçon manquant : " + from + " → " + (from + 1) + "."));
            if (it.getPrice() == null || it.getPrice() < 0) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Prix tronçon invalide.");
            }
            sum += it.getPrice();
        }
        return sum;
    }
}
