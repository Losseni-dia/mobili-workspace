package com.mobili.backend.module.booking.ticket.dto.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import com.mobili.backend.module.booking.ticket.dto.TicketResponseDTO;
import com.mobili.backend.module.booking.ticket.entity.Ticket;

@Mapper(componentModel = "spring")
public interface TicketMapper {

    // ✅ On prend directement le nom stocké dans l'entité Ticket
    @Mapping(source = "passengerName", target = "passengerFullName")
    @Mapping(source = "trip.id", target = "tripId")

    @Mapping(source = "ticketNumber", target = "qrCodeData")
    @Mapping(source = "trip.departureCity", target = "departureCity")
    @Mapping(source = "trip.arrivalCity", target = "arrivalCity")
    @Mapping(source = "booking.trip.partner.name", target = "partnerName")
    @Mapping(source = "trip.departureDateTime", target = "departureDateTime")
    @Mapping(source = "trip.vehiculePlateNumber", target = "vehiculePlateNumber")
    @Mapping(source = "amountPaid", target = "price")
    TicketResponseDTO toDto(Ticket ticket);
}
