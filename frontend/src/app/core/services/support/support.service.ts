import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

/** Aligné sur AdminComThreadDTO (backend). */
export interface SupportThread {
  id: number;
  subject: string;
  type: string | null;
  adminUserId: number | null;
  adminUserName: string | null;
  partnerUserId: number | null;
  partnerUserName: string | null;
  companyName: string | null;
  displayLabel: string;
  lastActivityAt: string;
  lastActivityAtFormatted: string;
}

/** Aligné sur AdminComMessageDTO (backend). */
export interface SupportMessage {
  id: number;
  authorId: number;
  authorName: string;
  body: string;
  createdAt: string;
  createdAtFormatted: string;
  attachmentPath: string | null;
  attachmentOriginalName: string | null;
  attachmentContentType: string | null;
}

/**
 * Fil de discussion support Mobili — API `/admin-com`, accessible à tout utilisateur
 * authentifié (voyageur, partenaire, gare), pas seulement l'admin malgré le nom du module côté
 * backend. `partnerUserId` est exigé par la validation même s'il est ignoré côté service pour un
 * appelant non-admin (le thread est de toute façon ouvert avec l'appelant courant) — toujours
 * envoyer son propre ID.
 */
@Injectable({ providedIn: 'root' })
export class SupportService {
  private http = inject(HttpClient);

  listThreads(): Observable<SupportThread[]> {
    return this.http.get<SupportThread[]>('/admin-com/threads');
  }

  createThread(
    currentUserId: number,
    subject: string,
    firstMessage: string,
    type?: string,
  ): Observable<SupportThread> {
    return this.http.post<SupportThread>('/admin-com/threads', {
      subject,
      partnerUserId: currentUserId,
      type,
      firstMessage,
    });
  }

  getMessages(threadId: number): Observable<SupportMessage[]> {
    return this.http.get<SupportMessage[]>(`/admin-com/threads/${threadId}/messages`);
  }

  postMessage(threadId: number, body: string): Observable<SupportMessage> {
    return this.http.post<SupportMessage>(`/admin-com/threads/${threadId}/messages`, { body });
  }

  /** Preuve jointe (image ou PDF) — texte optionnel, endpoint multipart dédié côté backend. */
  postMessageWithAttachment(
    threadId: number,
    body: string | null,
    file: File,
  ): Observable<SupportMessage> {
    const form = new FormData();
    if (body) {
      form.append('body', body);
    }
    form.append('file', file);
    return this.http.post<SupportMessage>(`/admin-com/threads/${threadId}/messages/attachment`, form);
  }
}
