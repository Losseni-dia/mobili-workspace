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
    @Mapping(target = "approvalStatus", expression = "java(partner.getApprovalStatus() != null ? partner.getApprovalStatus().name() : \"APPROVED\")")
    PartnerAdminResponse toAdminDto(Partner partner);

    // APRÈS
    @Mapping(target = "customerName", expression = "java(booking.getCustomer().getFirstname() + \" \" + booking.getCustomer().getLastname())")
    @Mapping(target = "tripRoute", expression = "java(com.mobili.backend.module.booking.booking.util.BookingSegmentUtil.resolveRouteLabel(booking))")
    @Mapping(target = "date", source = "createdAt")
    // JAMAIS totalPrice directement : inclut le forfait client, jamais reversé à la
    // compagnie. Booking.getGrossAmount() est la seule implémentation de ce calcul dans
    // tout le backend (voir son Javadoc) — ne pas le recalculer ici.
    @Mapping(target = "amount", expression = "java(booking.getGrossAmount())")
    @Mapping(target = "status", expression = "java(booking.getStatus().name())")
    @Mapping(target = "passengerNames", expression = "java(booking.getPassengerNames() != null ? new java.util.ArrayList<>(booking.getPassengerNames()) : java.util.Collections.emptyList())")
    @Mapping(target = "seatNumbers", expression = "java(booking.getSeatNumbers() != null ? new java.util.ArrayList<>(booking.getSeatNumbers()) : java.util.Collections.emptyList())")
    RecentBookingDTO toRecentBookingDto(Booking booking);

    List<RecentBookingDTO> toRecentBookingDtoList(List<Booking> bookings);

}