import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export type PgcScope = 'ALL' | 'TARGETED';

export interface PartnerGareComThread {
  id: number;
  scope: PgcScope;
  title: string;
  lastActivityAt: string;
  stationIds: number[];
  stationLabels: string[];
}

export interface PartnerGareComMessage {
  id: number;
  body: string;
  createdAt: string;
  authorId: number;
  authorFirstname: string;
  authorLastname: string;
  authorLogin: string;
}

export interface CreateThreadPayload {
  scope: PgcScope;
  title: string;
  stationIds?: number[] | null;
  firstMessage: string;
}

@Injectable({ providedIn: 'root' })
export class PartnerGareComService {
  private http = inject(HttpClient);

  listThreads(): Observable<PartnerGareComThread[]> {
    return this.http.get<PartnerGareComThread[]>(`/partner-gare-com/threads`);
  }

  createThread(body: CreateThreadPayload): Observable<PartnerGareComThread> {
    return this.http.post<PartnerGareComThread>(`/partner-gare-com/threads`, body);
  }

  listMessages(threadId: number): Observable<PartnerGareComMessage[]> {
    return this.http.get<PartnerGareComMessage[]>(`/partner-gare-com/threads/${threadId}/messages`);
  }

  postMessage(threadId: number, body: string): Observable<PartnerGareComMessage> {
    return this.http.post<PartnerGareComMessage>(`/partner-gare-com/threads/${threadId}/messages`, { body });
  }
}
