/**
 * Traduction des statuts bruts de réservation (backend `BookingStatus`, valeurs anglaises en
 * base) vers leur libellé français — aligné sur `BookingStatus.label` (backend, jamais exposé
 * tel quel dans le DTO). Le web affichait le nom brut de l'enum (feedback testeurs : "Pending",
 * "Confirmed", "Cancelled" au lieu du français).
 */
const BOOKING_STATUS_LABELS: Record<string, string> = {
  PENDING: 'En attente',
  CONFIRMED: 'Confirmé',
  CANCELLED: 'Annulé',
  COMPLETED: 'Terminé',
  OFFLINE_SALE: 'Achat physique',
  PENDING_DRIVER_APPROVAL: "En attente d'approbation",
  AWAITING_PAYMENT: 'En attente de paiement',
  REJECTED_BY_DRIVER: 'Rejeté par le chauffeur',
  EXPIRED: 'Expiré',
};

export function bookingStatusLabel(status: string | undefined | null): string {
  if (!status) return '—';
  return BOOKING_STATUS_LABELS[status] ?? status;
}
