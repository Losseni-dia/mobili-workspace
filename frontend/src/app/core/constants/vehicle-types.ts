/**
 * Types de véhicule alignés sur {@code com.mobili.backend.module.trip.entity.VehicleType} :
 * - `name` : nom d’enum (JSON covoiturage / API).
 * - `label` : libellé accepté par le backend (JsonCreator / fromString), identique à {@code getLabel()}.
 * - `defaultSeats` : suggestion de places (formulaires partenaire).
 */
export const VEHICLE_TYPE_ENUM_OPTIONS = [
  { name: 'MASSA_NORMAL', label: 'Massa normal', defaultSeats: 18 },
  { name: 'MASSA_6_ROUES', label: 'Massa 6 roues', defaultSeats: 22 },
  { name: 'VAN', label: 'Van', defaultSeats: 8 },
  { name: 'MINIBUS', label: 'Minibus', defaultSeats: 24 },
  { name: 'BUS_CLIMATISE', label: 'Bus Climatisé', defaultSeats: 50 },
  { name: 'BUS_CLASSIQUE', label: 'Bus Classique', defaultSeats: 50 },
  { name: 'CAR_70_PLACES', label: 'Car 70 places', defaultSeats: 70 },
  { name: 'SUV', label: 'SUV', defaultSeats: 5 },
  { name: 'BERLINE', label: 'Berline', defaultSeats: 4 },
  { name: 'CITADINE', label: 'Citadine', defaultSeats: 4 },
  { name: 'MONOSPACE', label: 'Monospace', defaultSeats: 7 },
  { name: 'PICKUP', label: 'Pick-up', defaultSeats: 3 },
] as const;

export type VehicleTypeName = (typeof VEHICLE_TYPE_ENUM_OPTIONS)[number]['name'];

/** Sélecteur covoiturage (valeur = nom d’enum en majuscules). */
export const VEHICLE_TYPE_COVOITURAGE_SELECT: { value: VehicleTypeName; label: string }[] =
  VEHICLE_TYPE_ENUM_OPTIONS.map((o) => ({ value: o.name, label: o.label }));

/** Affichage (cartes, listes) : gère nom d’enum, libellé API ou chaîne inconnue. */
export function formatVehicleTypeLabel(type: string | undefined | null): string {
  if (!type) {
    return '';
  }
  const t = type.trim();
  const byName = VEHICLE_TYPE_ENUM_OPTIONS.find((o) => o.name === t);
  if (byName) {
    return byName.label;
  }
  const byLabel = VEHICLE_TYPE_ENUM_OPTIONS.find((o) => o.label === t);
  if (byLabel) {
    return byLabel.label;
  }
  return t
    .replace(/_/g, ' ')
    .toLowerCase()
    .split(' ')
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}
