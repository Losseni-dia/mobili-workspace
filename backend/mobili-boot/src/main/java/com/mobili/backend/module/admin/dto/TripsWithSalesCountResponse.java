package com.mobili.backend.module.admin.dto;

/** Nombre de trajets distincts avec ≥1 ticket vendu sur [fromDate, toDate] — même définition que
 *  "Trajets avec ventes" de Stats métier (TripStatisticsService), réutilisé pour la Vue
 *  d'ensemble (sections "Cette année" / "Ce mois-ci") afin de ne jamais dupliquer la logique de
 *  comptage entre les deux pages. */
public record TripsWithSalesCountResponse(long count) {
}
