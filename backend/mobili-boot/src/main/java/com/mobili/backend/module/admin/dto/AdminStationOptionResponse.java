package com.mobili.backend.module.admin.dto;

/** Option de filtre gare (Stats métier) — toutes compagnies confondues. */
public record AdminStationOptionResponse(
        Long id,
        String name,
        String partnerName) {
}
