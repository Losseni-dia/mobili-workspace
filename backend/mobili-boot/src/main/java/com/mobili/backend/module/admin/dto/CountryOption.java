package com.mobili.backend.module.admin.dto;

/** Une entrée de la liste des pays — pour les `<select>` des écrans admin Pays & Villes et,
 *  à terme, les formulaires société/gare. */
public record CountryOption(Long id, String name, String isoCode, String continent) {
}
