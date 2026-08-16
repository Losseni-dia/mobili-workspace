export type PeriodPreset = 'today' | 'week' | 'month';

/**
 * Calcule une plage {from, to} (yyyy-MM-dd, bornes incluses) pour un préset — aligné sur
 * `PartnerPeriodSelector` (mobilipro) : semaine = lundi→dimanche de la semaine courante.
 */
export function computePeriodRange(preset: PeriodPreset): { from: string; to: string } {
  const now = new Date();
  const iso = (d: Date) => d.toISOString().slice(0, 10);

  if (preset === 'today') {
    return { from: iso(now), to: iso(now) };
  }
  if (preset === 'week') {
    const day = now.getDay() || 7; // dimanche = 0 -> 7
    const monday = new Date(now);
    monday.setDate(now.getDate() - day + 1);
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    return { from: iso(monday), to: iso(sunday) };
  }
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  const last = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  return { from: iso(first), to: iso(last) };
}
