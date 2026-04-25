/**
 * Prix affiché en catalogue (carte) pour l’offre « tout le trajet » : on montre
 * le tarif complet {@link originDestinationPrice} s’il a été saisi, sinon le prix
 * principal du voyage ({@link price}).
 */
export function getTripPublicListPrice(trip: {
  price: number;
  originDestinationPrice?: number | null;
}): number {
  if (trip.originDestinationPrice != null && trip.originDestinationPrice > 0) {
    return trip.originDestinationPrice;
  }
  return trip.price;
}
