export type PeriodPreset = 'today' | 'week' | 'month';

/**
 * Formate une date en 'yyyy-MM-dd' d'après ses composantes LOCALES (année/mois/jour du
 * fuseau horaire de l'appareil) — jamais `toISOString().slice(0, 10)`, qui convertit en UTC
 * avant de tronquer et peut donc décaler la date d'un jour selon le fuseau horaire du
 * navigateur (ex: minuit local en UTC+1 devient 23h la veille en UTC → date décalée).
 * C'est ce décalage qui causait un écart entre web et mobilipro (mobilipro/Dart formate déjà
 * en heure locale, sans conversion UTC) sur les mêmes filtres de période "Mois".
 */
export function toLocalDateString(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * Calcule une plage {from, to} (yyyy-MM-dd, bornes incluses) pour un préset — aligné sur
 * `PartnerPeriodSelector` (mobilipro) : semaine = lundi→dimanche de la semaine courante.
 */
export function computePeriodRange(preset: PeriodPreset): { from: string; to: string } {
  const now = new Date();

  if (preset === 'today') {
    return { from: toLocalDateString(now), to: toLocalDateString(now) };
  }
  if (preset === 'week') {
    const day = now.getDay() || 7; // dimanche = 0 -> 7
    const monday = new Date(now);
    monday.setDate(now.getDate() - day + 1);
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    return { from: toLocalDateString(monday), to: toLocalDateString(sunday) };
  }
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  const last = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  return { from: toLocalDateString(first), to: toLocalDateString(last) };
}
