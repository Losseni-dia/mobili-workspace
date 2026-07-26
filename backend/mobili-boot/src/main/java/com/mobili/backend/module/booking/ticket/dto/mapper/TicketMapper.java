package com.mobili.backend.module.booking.ticket.dto.mapper;

import org.mapstruct.AfterMapping;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

import com.mobili.backend.module.booking.ticket.dto.TicketResponseDTO;
import com.mobili.backend.module.booking.ticket.entity.Ticket;

@Mapper(componentModel = "spring")
public interface TicketMapper {

    @Mapping(source = "passengerName", target = "passengerFullName")
    @Mapping(source = "trip.id", target = "tripId")
    @Mapping(source = "ticketNumber", target = "qrCodeData")
    @Mapping(source = "trip.departureCity", target = "departureCity")
    @Mapping(source = "trip.arrivalCity", target = "arrivalCity")
    @Mapping(source = "booking.trip.partner.name", target = "partnerName")
    @Mapping(source = "trip.departureDateTime", target = "departureDateTime")
    @Mapping(source = "trip.vehiculePlateNumber", target = "vehiculePlateNumber")
    @Mapping(source = "amountPaid", target = "price")
    @Mapping(source = "trip.boardingPoint", target = "boardingPoint")
    @Mapping(source = "boardingStopIndex", target = "boardingStopIndex")
    @Mapping(source = "alightingStopIndex", target = "alightingStopIndex")
    @Mapping(target = "boardingCity", ignore = true)
    @Mapping(target = "alightingCity", ignore = true)
    @Mapping(target = "extraHoldBags", ignore = true)
    @Mapping(target = "luggageFee", ignore = true)
    @Mapping(target = "transportPrice", ignore = true)
    @Mapping(target = "numberOfSeatsInBooking", ignore = true)
    TicketResponseDTO toDto(Ticket ticket);

    @AfterMapping
    default void fillLuggageAndReceiptInfo(Ticket ticket, @MappingTarget TicketResponseDTO dto) {
        var booking = ticket.getBooking();
        var trip = ticket.getTrip();
        if (booking == null || trip == null) {
            return;
        }
        int extraBags = booking.getExtraHoldBags() != null ? booking.getExtraHoldBags() : 0;
        double luggageFee = (extraBags > 0 && trip.getExtraHoldBagPrice() != null)
                ? extraBags * trip.getExtraHoldBagPrice()
                : 0.0;
        double totalPrice = booking.getTotalPrice() != null ? booking.getTotalPrice() : 0.0;
        int seats = booking.getNumberOfSeats() != null ? booking.getNumberOfSeats() : 1;
        double transportTotal = totalPrice - luggageFee;
        dto.setExtraHoldBags(extraBags);
        dto.setLuggageFee(luggageFee);
        dto.setNumberOfSeatsInBooking(seats);
        // Part de transport pour CE ticket (répartition équitable entre les
        // sièges de la même réservation).
        dto.setTransportPrice(seats > 0 ? transportTotal / seats : transportTotal);
    }

    @AfterMapping
    default void fillSegmentCities(Ticket ticket, @MappingTarget TicketResponseDTO dto) {
        if (ticket.getTrip() == null)
            return;
        var trip = ticket.getTrip();

        // Reconstruit la liste des villes
        java.util.List<String> labels = new java.util.ArrayList<>();
        String dep = trip.getDepartureCity();
        if (dep != null && !dep.isBlank())
            labels.add(dep.trim());
        if (trip.getMoreInfo() != null && !trip.getMoreInfo().isBlank()) {
            for (String part : trip.getMoreInfo().split(",")) {
                String t = part.trim();
                if (!t.isEmpty())
                    labels.add(
                            Character.toUpperCase(t.charAt(0)) + t.substring(1).toLowerCase());
            }
        }
        String arr = trip.getArrivalCity();
        if (arr != null && !arr.isBlank()) {
            String a = arr.trim();
            if (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(a))
                labels.add(a);
        }

        int last = Math.max(0, labels.size() - 1);
        int boarding = dto.getBoardingStopIndex() != null ? dto.getBoardingStopIndex() : 0;
        int alighting = dto.getAlightingStopIndex() != null ? dto.getAlightingStopIndex() : last;

        if (boarding >= 0 && boarding < labels.size())
            dto.setBoardingCity(labels.get(boarding));
        if (alighting >= 0 && alighting < labels.size())
            dto.setAlightingCity(labels.get(alighting));
    }
}
