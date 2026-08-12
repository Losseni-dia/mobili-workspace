import { HttpErrorResponse } from '@angular/common/http';

/**
 * Extrait un message affichable d'une erreur HTTP backend — le backend renvoie deux formes
 * distinctes (`GlobalExceptionHandler`) qu'il faut gérer toutes les deux :
 * - `ErrorDetails` complet (`MobiliException`, doublons, 404, 500…) : `{ message, path, errors? }`.
 * - Erreurs de validation `@Valid` (`handleValidation`) : `{ timestamp, status, errorCode, errors }`,
 *   **sans** `message` — seul `errors` (map champ → message) porte l'information utile.
 *
 * Sans cette fonction, un composant qui ne lit que `err.error.message` affiche silencieusement
 * le message générique de secours pour toute erreur de validation de champ (ex. téléphone trop
 * court, date non future), au lieu du message précis du champ en cause.
 */
export function extractApiErrorMessage(err: HttpErrorResponse, fallback: string): string {
  const body: unknown = err?.error;

  if (typeof body === 'string' && body.trim()) {
    return body.trim();
  }

  if (body && typeof body === 'object') {
    const asRecord = body as Record<string, unknown>;

    const message = asRecord['message'];
    if (typeof message === 'string' && message.trim()) {
      return message.trim();
    }

    const errors = asRecord['errors'];
    if (errors && typeof errors === 'object') {
      const messages = Object.values(errors as Record<string, unknown>).filter(
        (v): v is string => typeof v === 'string' && v.trim().length > 0,
      );
      if (messages.length) {
        return messages.join(' ');
      }
    }

    const errorField = asRecord['error'];
    if (typeof errorField === 'string' && errorField.trim()) {
      return errorField.trim();
    }
  }

  return fallback;
}
