/**
 * Entrées HTTP « application » (hors admin / hors shell compagnie). Sous-paquets :
 * <ul>
 * <li>{@code auth} — connexion, inscription, refresh JWT</li>
 * <li>{@code user} — profil {@code /v1/users}, lecture {@code /v1/auth}</li>
 * <li>{@code trip} — catalogue, chauffeur, covoiturage, canal trajet</li>
 * <li>{@code booking} — réservations</li>
 * <li>{@code ticket} — billets</li>
 * <li>{@code payment} — FedaPay / webhooks</li>
 * <li>{@code gare} — préinscription responsable de gare</li>
 * <li>{@code inbox} — notifications, SSE</li>
 * </ul>
 */
package com.mobili.backend.api.passenger;
