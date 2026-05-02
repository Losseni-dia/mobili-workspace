package com.mobili.backend.module.booking.booking.dto.mapper;

import java.util.ArrayList;
import java.util.List;

import com.mobili.backend.module.booking.booking.dto.BookingResponseDTO;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.trip.entity.Trip;

import org.mapstruct.AfterMapping;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

@Mapper(componentModel = "spring")
public interface BookingMapper {

    @Mapping(source = "trip.departureCity", target = "departureCity")
    @Mapping(source = "trip.arrivalCity", target = "arrivalCity")
    @Mapping(source = "trip.moreInfo", target = "moreInfo")
    @Mapping(source = "trip.departureDateTime", target = "departureDateTime")
    @Mapping(target = "customerName", expression = "java(booking.getCustomer().getFirstname() + \" \" + booking.getCustomer().getLastname())")
    @Mapping(target = "tripRoute", expression = "java(booking.getTrip().getDepartureCity() + \" -> \" + booking.getTrip().getArrivalCity())")
    @Mapping(source = "totalPrice", target = "totalPrice")
    @Mapping(source = "totalPrice", target = "amount")
    @Mapping(source = "createdAt", target = "date")
    @Mapping(source = "extraHoldBags", target = "extraHoldBags")
    BookingResponseDTO toDto(Booking booking);

    /**
     * Calcule les libellés d'arrêts (embarquement / descente) et le prix par place,
     * une fois le mapping de base terminé.
     */
    @AfterMapping
    default void fillSegmentLabelsAndUnitPrice(Booking booking, @MappingTarget BookingResponseDTO dto) {
        Trip trip = booking.getTrip();
        if (trip != null) {
            List<String> labels = buildCityLabels(trip.getDepartureCity(), trip.getArrivalCity(), trip.getMoreInfo());
            int last = Math.max(0, labels.size() - 1);
            int boarding = dto.getBoardingStopIndex() != null ? dto.getBoardingStopIndex() : 0;
            int alighting = dto.getAlightingStopIndex() != null ? dto.getAlightingStopIndex() : last;
            if (boarding >= 0 && boarding < labels.size()) {
                dto.setBoardingCity(labels.get(boarding));
            }
            if (alighting >= 0 && alighting < labels.size()) {
                dto.setAlightingCity(labels.get(alighting));
            }
        }

        Integer seats = dto.getNumberOfSeats();
        Double total = dto.getTotalPrice();
        if (seats != null && seats > 0 && total != null) {
            dto.setPricePerSeat(total / seats);
        }

        if (booking.getExtraHoldBags() != null
                && booking.getExtraHoldBags() > 0
                && trip != null
                && trip.getExtraHoldBagPrice() != null) {
            dto.setLuggageFee(booking.getExtraHoldBags() * trip.getExtraHoldBagPrice());
        } else {
            dto.setLuggageFee(0.0);
        }
    }

    /**
     * Construit la liste ordonnée des villes traversées par le voyage.
     * Aligné sur la logique frontend {@code buildTripCityLabels}.
     */
    private static List<String> buildCityLabels(String departureCity, String arrivalCity, String moreInfoCsv) {
        List<String> labels = new ArrayList<>();
        String dep = trimCity(departureCity);
        if (!dep.isEmpty()) {
            labels.add(dep);
        }
        if (moreInfoCsv != null && !moreInfoCsv.trim().isEmpty()) {
            for (String raw : moreInfoCsv.split(",")) {
                String trimmed = trimCity(raw);
                if (!trimmed.isEmpty()
                        && (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(trimmed))) {
                    labels.add(trimmed);
                }
            }
        }
        String arr = trimCity(arrivalCity);
        if (!arr.isEmpty() && (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(arr))) {
            labels.add(arr);
        }
        return labels;
    }

    private static String trimCity(String raw) {
        if (raw == null) {
            return "";
        }
        String t = raw.trim();
        if (t.isEmpty()) {
            return "";
        }
        return Character.toUpperCase(t.charAt(0)) + t.substring(1).toLowerCase();
    }
}
