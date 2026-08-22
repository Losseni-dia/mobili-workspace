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
    @Mapping(source = "booking.id", target = "bookingId")
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
        int seats = booking.getNumberOfSeats() != null ? booking.getNumberOfSeats() : 1;
        dto.setExtraHoldBags(extraBags);
        dto.setNumberOfSeatsInBooking(seats);

        if (ticket.getTransportFare() != null) {
            // Part transport/bagage propre à CE ticket, jamais mélangée au forfait client
            // (Booking.serviceFee) — même règle que Booking#getGrossAmount au niveau réservation.
            dto.setTransportPrice(ticket.getTransportFare());
            dto.setLuggageFee(ticket.getBaggageFee() != null ? ticket.getBaggageFee() : 0.0);
            return;
        }

        // Ticket antérieur à la scission transportFare/baggageFee par ticket : on répartit la
        // vente brute de la réservation (déjà hors forfait, voir Booking#getActiveTicketsAmount)
        // à parts égales entre les sièges. AUDIT : l'ancien code utilisait
        // totalPrice - luggageFee, qui incluait encore le forfait client dans le montant
        // "Transport" affiché à la gare/au chauffeur au scan du billet.
        double luggageFee = booking.getActiveLuggageFee();
        double transportTotal = booking.getActiveTicketsAmount();
        dto.setLuggageFee(luggageFee);
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
