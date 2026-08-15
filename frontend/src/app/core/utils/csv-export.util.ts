/**
 * Génère et télécharge un CSV côté client — aligné sur le bouton "Export CSV" présent côté
 * mobilipro (tickets_gare_page.dart, gare_transactions_page.dart). Pas d'équivalent PDF ici
 * (nécessiterait une librairie dédiée, hors périmètre).
 */
export function exportToCsv(filename: string, rows: Record<string, string | number | null | undefined>[]): void {
  if (!rows.length) return;

  const headers = Object.keys(rows[0]);
  const escape = (v: unknown) => {
    const s = v == null ? '' : String(v);
    return /[",;\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };

  const lines = [
    headers.join(';'),
    ...rows.map((row) => headers.map((h) => escape(row[h])).join(';')),
  ];
  // BOM UTF-8 pour un affichage correct des accents dans Excel.
  const blob = new Blob(['﻿' + lines.join('\n')], { type: 'text/csv;charset=utf-8;' });

  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename.endsWith('.csv') ? filename : `${filename}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
