/**
 * Libellé "en cours de trajet" — parité avec mobile_app (trip_card.dart, _InProgressBadge) :
 * une fois le chauffeur parti et la ville de départ quittée, le trajet passe en statut
 * EN_COURS et le backend renseigne `nextStopCity` (TripRunService#nextStopCityOrNull) avec la
 * prochaine ville non encore quittée. Simple badge texte, pas de carte/position GPS.
 */
export function tripInProgressLabel(nextStopCity?: string | null): string {
  return nextStopCity ? `En route vers ${nextStopCity}` : 'En cours';
}

export function isTripInProgress(status: string | undefined | null): boolean {
  return status === 'EN_COURS';
}
