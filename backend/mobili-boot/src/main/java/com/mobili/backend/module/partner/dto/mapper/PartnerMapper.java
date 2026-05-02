package com.mobili.backend.module.partner.dto.mapper;

import java.util.List;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import com.mobili.backend.module.admin.dto.PartnerAdminResponse;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.partner.dto.PartnerProfileDTO;
import com.mobili.backend.module.partner.dto.PartnerRegisterDTO;
import com.mobili.backend.module.partner.dto.RecentBookingDTO;
import com.mobili.backend.module.partner.entity.Partner;

@Mapper(componentModel = "spring")
public interface PartnerMapper {

    // Pour l'inscription (Register -> Entity)
    Partner toEntity(PartnerRegisterDTO dto);

    // Pour la mise à jour (Profile -> Entity)
    Partner toEntity(PartnerProfileDTO dto);

    // Pour l'affichage (Entity -> Profile)
    PartnerProfileDTO toProfileDto(Partner partner);

    @Mapping(target = "ownerName", expression = "java(partner.getOwner() != null ? partner.getOwner().getFirstname() + \" \" + partner.getOwner().getLastname() : \"Sans propriétaire\")")
    PartnerAdminResponse toAdminDto(Partner partner);

    @Mapping(target = "customerName", expression = "java(booking.getCustomer().getFirstname() + \" \" + booking.getCustomer().getLastname())")
    @Mapping(target = "tripRoute", expression = "java(booking.getTrip().getDepartureCity() + \" -> \" + booking.getTrip().getArrivalCity())")
    @Mapping(target = "date", source = "createdAt")
    @Mapping(target = "amount", source = "totalPrice")
    @Mapping(target = "status", expression = "java(booking.getStatus().name())")
    RecentBookingDTO toRecentBookingDto(Booking booking);

    List<RecentBookingDTO> toRecentBookingDtoList(List<Booking> bookings);

}