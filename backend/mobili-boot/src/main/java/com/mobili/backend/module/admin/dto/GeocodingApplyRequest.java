package com.mobili.backend.module.admin.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Envoyé par l'écran admin après relecture de la prévisualisation — seules les lignes que
 * l'admin a explicitement cochées (jamais tout l'aperçu automatiquement, en particulier jamais
 * les lignes ambiguës/en échec sans validation manuelle).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class GeocodingApplyRequest {

    @NotEmpty
    @Valid
    private List<Item> items;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Item {
        @NotBlank
        private String cityLabel;
        private double latitude;
        private double longitude;
    }
}
