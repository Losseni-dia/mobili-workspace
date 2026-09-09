package com.mobili.backend.module.admin.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Envoyé par l'écran admin Pays & Villes après relecture de l'aperçu — seules les lignes que
 * l'admin a explicitement cochées (jamais tout l'aperçu automatiquement), même discipline que
 * GeocodingApplyRequest (écran admin de géocodage des arrêts).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class AdminCityApplyRequest {

    @NotEmpty
    @Valid
    private List<Item> items;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Item {
        @NotNull
        private Long id;
        /** Renommage optionnel — si renseigné et différent du nom actuel, corrige City.name en
         *  plus d'appliquer la coordonnée/le pays. */
        private String name;
        private Long countryId;
        private double latitude;
        private double longitude;
    }
}
