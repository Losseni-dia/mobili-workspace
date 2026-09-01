/** Libellés français des types d'événements analytics (backend). */
export function eventTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    FAILED_LOGIN: 'Échec de connexion',
    SEARCH_NO_RESULT: 'Recherche sans résultat',
    BOOKING_CREATED: 'Réservation créée',
    BOOKING_PAID: 'Paiement confirmé',
    TRIP_PUBLISHED: 'Trajet publié',
    SERVER_ERROR: 'Erreur serveur (non gérée)',
  };
  return labels[type] ?? type;
}

export type EventSeverity = 'danger' | 'warning' | 'success' | 'neutral';

/**
 * Sévérité par type — pour la coloration du journal/agrégats (page Analyse app). Réutilise le
 * vocabulaire déjà présent ailleurs côté admin (rouge = incident sécurité/fiabilité, orange =
 * friction produit à surveiller, vert = signal business positif).
 */
export function eventTypeSeverity(type: string): EventSeverity {
  const severities: Record<string, EventSeverity> = {
    FAILED_LOGIN: 'danger',
    SERVER_ERROR: 'danger',
    SEARCH_NO_RESULT: 'warning',
    BOOKING_CREATED: 'neutral',
    BOOKING_PAID: 'success',
    TRIP_PUBLISHED: 'success',
  };
  return severities[type] ?? 'neutral';
}
