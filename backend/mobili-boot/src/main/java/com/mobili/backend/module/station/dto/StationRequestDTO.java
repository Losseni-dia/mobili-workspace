package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class StationRequestDTO {

    @NotBlank(message = "Le nom de la gare est obligatoire")
    private String name;

    /** Ville choisie dans la liste (autocomplétion filtrée sur le pays de la société) — préférée
     *  quand renseignée. */
    private Long cityId;

    /** Fallback "ville introuvable" : nom tapé par le partenaire quand aucune ville de la liste
     *  ne correspond. Résolu/créé via CityLookupService (verified=false), rattachée au pays de la
     *  société. Au moins un de cityId/cityName doit être renseigné (validé dans le service, pas
     *  via annotation — dépend du choix fait côté écran). */
    private String cityName;

    private Boolean active;

    @Size(min = 6, message = "Le mot de passe doit faire au moins 6 caractères")
    private String password;
}
