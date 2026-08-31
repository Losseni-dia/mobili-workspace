package com.mobili.backend.module.booking.booking.dto.mapper;

import com.mobili.backend.module.booking.booking.dto.BookingResponseDTO;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.util.BookingSegmentUtil;
import com.mobili.backend.module.trip.entity.Trip;

import org.mapstruct.AfterMapping;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

@Mapper(componentModel = "spring")
public interface BookingMapper {

    @Mapping(source = "trip.id", target = "tripId")
    @Mapping(source = "trip.departureCity", target = "departureCity")
    @Mapping(source = "trip.arrivalCity", target = "arrivalCity")
    @Mapping(source = "trip.moreInfo", target = "moreInfo")
    @Mapping(source = "trip.departureDateTime", target = "departureDateTime")
    @Mapping(target = "customerName", expression = "java(booking.getCustomer().getFirstname() + \" \" + booking.getCustomer().getLastname())")
    @Mapping(source = "customer.firstname", target = "customerFirstname")
    @Mapping(source = "customer.lastname", target = "customerLastname")
    @Mapping(source = "customer.avatarUrl", target = "customerAvatarUrl")
    // Calculé en @AfterMapping à partir du tronçon réel (boardingCity/alightingCity), pas du
    // trajet complet du voyage — voir fillSegmentLabelsAndUnitPrice.
    @Mapping(target = "tripRoute", ignore = true)
    @Mapping(source = "totalPrice", target = "totalPrice")
    // JAMAIS totalPrice : inclut le forfait client, jamais reversé à la compagnie.
    // Booking.getGrossAmount() est la seule implémentation de ce calcul dans tout le
    // backend (voir son Javadoc) — champ lu directement par les écrans gare/partenaire
    // qui n'ont pas encore leur propre calcul client-side (ex. BookingItem.amount côté gare).
    @Mapping(target = "amount", expression = "java(booking.getGrossAmount())")
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
            String[] cities = BookingSegmentUtil.resolveBoardingAlightingCities(booking);
            dto.setBoardingCity(cities[0]);
            dto.setAlightingCity(cities[1]);
            dto.setTripRoute(cities[0] + " → " + cities[1]);
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

        // Noms passagers
        if (booking.getPassengerNames() != null) {
            dto.setPassengerNames(booking.getPassengerNames());
        }

        // Numéros de sièges
        if (booking.getSeatNumbers() != null) {
            dto.setSeatNumbers(booking.getSeatNumbers());
        }

        // Sièges dont le ticket a été annulé individuellement (voir Javadoc du champ DTO).
        if (booking.getTickets() != null) {
            dto.setCancelledSeatNumbers(
                    booking.getTickets().stream()
                            .filter(t -> t.getStatus() == com.mobili.backend.module.booking.ticket.entity.TicketStatus.ANNULÉ)
                            .map(com.mobili.backend.module.booking.ticket.entity.Ticket::getSeatNumber)
                            .filter(java.util.Objects::nonNull)
                            .collect(java.util.stream.Collectors.toSet()));
        }
    }
}
