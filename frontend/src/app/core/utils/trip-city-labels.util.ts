/** Aligné sur TripStopSyncService.buildCityLabels (libellés d’arrêts pour l’UI). */

function trimCity(raw: string | null | undefined): string {
  if (raw == null) return '';
  const t = raw.trim();
  if (t === '') return '';
  return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase();
}

export function buildTripCityLabels(
  departureCity: string,
  arrivalCity: string,
  moreInfoCsv: string | null | undefined,
): string[] {
  const labels: string[] = [];
  labels.push(trimCity(departureCity));
  if (moreInfoCsv != null && moreInfoCsv.trim() !== '') {
    for (const part of moreInfoCsv.split(',')) {
      const t = trimCity(part);
      if (t !== '' && labels[labels.length - 1].toLowerCase() !== t.toLowerCase()) {
        labels.push(t);
      }
    }
  }
  const arr = trimCity(arrivalCity);
  if (labels.length === 0 || labels[labels.length - 1].toLowerCase() !== arr.toLowerCase()) {
    labels.push(arr);
  }
  return labels;
}

export function lastStopIndexFromLabels(labels: string[]): number {
  return Math.max(0, labels.length - 1);
}
