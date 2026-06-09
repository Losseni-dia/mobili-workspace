package com.mobili.backend.module.trip.service;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.trip.dto.TripRatingRequest;
import com.mobili.backend.module.trip.dto.TripRatingResponse;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripRating;
import com.mobili.backend.module.trip.repository.TripRatingRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class TripRatingService {

    private final TripRatingRepository ratingRepository;
    private final TripRepository tripRepository;

    @Transactional
    public TripRatingResponse rate(Long tripId, TripRatingRequest request, UserPrincipal principal) {
        // Vérifier que le voyage existe
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Voyage introuvable"));

        // Vérifier si déjà noté
        if (ratingRepository.existsByTripIdAndUserId(tripId, principal.getUser().getId())) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Vous avez déjà noté ce voyage");
        }

        TripRating rating = TripRating.builder()
                .trip(trip)
                .user(principal.getUser())
                .note(request.note())
                .comment(request.comment())
                .build();

        rating = ratingRepository.save(rating);

        return new TripRatingResponse(
                rating.getId(),
                tripId,
                rating.getNote(),
                rating.getComment(),
                rating.getCreatedAt());
    }

    @Transactional(readOnly = true)
    public boolean hasRated(Long tripId, UserPrincipal principal) {
        return ratingRepository.existsByTripIdAndUserId(tripId, principal.getUser().getId());
    }

    @Transactional(readOnly = true)
    public Double getAverageForTrip(Long tripId) {
        return ratingRepository.findAverageByTripId(tripId).orElse(null);
    }

    @Transactional(readOnly = true)
    public Double getAverageForPartner(Long partnerId) {
        return ratingRepository.findAverageByPartnerId(partnerId).orElse(null);
    }

    @Transactional(readOnly = true)
    public Double getAverageForStation(Long stationId) {
        return ratingRepository.findAverageByStationId(stationId).orElse(null);
    }

    @Transactional(readOnly = true)
    public long countForTrip(Long tripId) {
        return ratingRepository.countByTripId(tripId);
    }
}