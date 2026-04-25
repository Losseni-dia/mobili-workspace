import type { Trip, TripLegFareResponse } from '../services/trip/trip.service';

/**
 * Prix par place sur [boarding, alighting] — même règles que le backend
 * {@code TripPricingService.resolvePricePerSeat} (aperçu avant paiement).
 */
export function getPricePerSeatForSegment(
  trip: Trip,
  legFares: TripLegFareResponse[] | undefined,
  boarding: number,
  alighting: number,
  lastStopIndex: number,
): number {
  if (alighting <= boarding) {
    return 0;
  }

  if (lastStopIndex <= 0) {
    return trip.price != null && trip.price > 0 ? trip.price : 0;
  }

  if (
    boarding === 0 &&
    alighting === lastStopIndex &&
    trip.originDestinationPrice != null &&
    trip.originDestinationPrice > 0
  ) {
    return trip.originDestinationPrice;
  }

  const fares = legFares ?? [];
  if (fares.length > 0) {
    let sum = 0;
    for (let i = boarding; i < alighting; i++) {
      const row = fares.find((f) => f.fromStopIndex === i && f.toStopIndex === i + 1);
      if (row == null) {
        sum = Number.NaN;
        break;
      }
      sum += row.price;
    }
    if (!Number.isNaN(sum)) {
      return sum;
    }
  }

  if (lastStopIndex > 0) {
    const base = trip.price != null && trip.price > 0 ? trip.price : 0;
    return (base * (alighting - boarding)) / lastStopIndex;
  }

  return trip.price ?? 0;
}
