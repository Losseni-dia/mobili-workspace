package com.mobili.backend.module.booking.ticket.util;

import java.util.ArrayList;
import java.util.List;

import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.trip.entity.Trip;

/**
 * Résout le tronçon réellement embarqué/débarqué d'un ticket (boardingStopIndex/
 * alightingStopIndex), par opposition au trajet complet du voyage (trip.departureCity →
 * trip.arrivalCity). Même logique que TicketMapper.fillSegmentCities (DTO passager), extraite
 * ici pour être réutilisable par les listes web partenaire/admin qui affichaient jusqu'ici
 * toujours le trajet complet au lieu du tronçon du passager.
 */
public final class TicketSegmentUtil {

    private TicketSegmentUtil() {
    }

    /** "Ville embarquement → Ville débarquement" pour CE ticket (tronçon réel, pas le trajet complet). */
    public static String resolveRouteLabel(Ticket ticket) {
        Trip trip = ticket.getTrip();
        if (trip == null) {
            return "—";
        }

        List<String> labels = new ArrayList<>();
        String dep = trip.getDepartureCity();
        if (dep != null && !dep.isBlank()) {
            labels.add(dep.trim());
        }
        if (trip.getMoreInfo() != null && !trip.getMoreInfo().isBlank()) {
            for (String part : trip.getMoreInfo().split(",")) {
                String t = part.trim();
                if (!t.isEmpty()) {
                    labels.add(Character.toUpperCase(t.charAt(0)) + t.substring(1).toLowerCase());
                }
            }
        }
        String arr = trip.getArrivalCity();
        if (arr != null && !arr.isBlank()) {
            String a = arr.trim();
            if (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(a)) {
                labels.add(a);
            }
        }

        if (labels.isEmpty()) {
            return "—";
        }

        int last = Math.max(0, labels.size() - 1);
        int boarding = ticket.getBoardingStopIndex() != null ? ticket.getBoardingStopIndex() : 0;
        int alighting = ticket.getAlightingStopIndex() != null ? ticket.getAlightingStopIndex() : last;

        String boardingCity = (boarding >= 0 && boarding < labels.size()) ? labels.get(boarding) : labels.get(0);
        String alightingCity = (alighting >= 0 && alighting < labels.size()) ? labels.get(alighting)
                : labels.get(last);

        return boardingCity + " → " + alightingCity;
    }
}
