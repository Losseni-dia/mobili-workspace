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
