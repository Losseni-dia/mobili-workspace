package com.mobili.backend.module.trip.dto.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;
import com.mobili.backend.module.trip.dto.TripRequestDTO;
import com.mobili.backend.module.trip.dto.TripResponseDTO;
import org.mapstruct.Named;

import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TransportType;

@Mapper(componentModel = "spring", unmappedSourcePolicy = ReportingPolicy.IGNORE)
public interface TripMapper {

    // --- ÉCRITURE (Request -> Entity) ---
    @Mapping(source = "partnerId", target = "partner.id")
    @Mapping(target = "stops", ignore = true)
    @Mapping(target = "assignedChauffeur", ignore = true)
    // MapStruct fera le lien automatique pour boardingPoint et moreInfo
    // car les noms sont maintenant identiques dans le DTO et l'Entité.
    Trip toEntity(TripRequestDTO dto);

    // --- LECTURE (Entity -> ResponseDTO) ---
    @Mapping(source = "partner.name", target = "partnerName")
    @Mapping(source = "station.id", target = "stationId")
    @Mapping(source = "station.name", target = "stationName")
    @Mapping(source = "covoiturageOrganizer.id", target = "covoiturageOrganizerId")
    @Mapping(source = "assignedChauffeur.id", target = "assignedChauffeurId")
    @Mapping(source = "assignedChauffeur.firstname", target = "assignedChauffeurFirstname")
    @Mapping(source = "assignedChauffeur.lastname", target = "assignedChauffeurLastname")
    @Mapping(target = "transportType", source = "transportType", qualifiedByName = "transportTypeName")
    @Mapping(target = "legFares", ignore = true)
    TripResponseDTO toDto(Trip trip);

    @Named("transportTypeName")
    default String transportTypeName(TransportType t) {
        return t == null ? null : t.name();
    }
}