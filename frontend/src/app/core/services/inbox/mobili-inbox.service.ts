import { inject, Injectable, signal, computed, effect } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { fetchEventSource } from '@microsoft/fetch-event-source';
import { Observable, of, tap, catchError } from 'rxjs';
import { Page } from './page.model';
import { AuthService } from '../auth/auth.service';
import { ConfigurationService } from '../../../configurations/services/configuration.service';

export type MobiliInboxType =
  | 'TICKET_ISSUED'
  | 'TRIP_CHANNEL_MESSAGE'
  | 'PARTNER_NEW_BOOKING'
  | 'GARE_STATION_NEW_BOOKING'
  | 'PARTNER_GARE_COM_MESSAGE'
  | 'COV_KYC_EXPIRING_SOON'
  | 'COV_KYC_EXPIRED'
  | 'MOBILI_ADMIN_INFO_PARTNER';

export interface InboxItem {
  id: number;
  type: MobiliInboxType;
  title: string;
  body: string;
  read: boolean;
  createdAt: string;
  tripId: number | null;
  tripRoute: string | null;
  channelMessageId: number | null;
  /** Fils messagerie partenaire / gares → `/…/company-messages?thread=…` */
  partnerGareComThreadId?: number | null;
}

@Injectable({ providedIn: 'root' })
export class MobiliInboxService {
  private http = inject(HttpClient);
  private auth = inject(AuthService);
  private config = inject(ConfigurationService);

  private readonly base = '/inbox';

  private authToken = computed(() => this.auth.currentUser()?.token ?? null);
  private abortSse: AbortController | null = null;

  unreadCount = signal(0);
  hasUnread = computed(() => this.unreadCount() > 0);

  constructor() {
    effect((onCleanup) => {
      const t = this.authToken();
      if (!t) {
        this.stopSse();
        onCleanup(() => undefined);
        return;
      }
      this.openSse();
      onCleanup(() => {
        this.stopSse();
      });
    });
  }

  private openSse() {
    this.stopSse();
    const apiUrl = this.config.getEnvironmentVariable('apiUrl');
    if (!apiUrl) {
      return;
    }
    const token = this.authToken();
    if (!token) {
      return;
    }
    const controller = new AbortController();
    this.abortSse = controller;
    const url = `${apiUrl}/inbox/sse`;
    const stopOn401 = (status: number) => status === 401 || status === 403;
    void fetchEventSource(url, {
      signal: controller.signal,
      headers: { Authorization: `Bearer ${token}` },
      onopen: async (response) => {
        if (stopOn401(response.status)) {
          this.stopSse();
          throw new Error('SSE: session invalide');
        }
        if (!response.ok) {
          throw new Error(`SSE: ${response.status}`);
        }
      },
      onmessage: (ev) => {
        if (ev.event === 'unread' && ev.data) {
          try {
            const j = JSON.parse(ev.data) as { unread: number };
            this.unreadCount.set(j.unread ?? 0);
          } catch {
            this.refreshUnreadCount(!!this.authToken());
          }
        } else if (ev.event === 'refresh') {
          this.refreshUnreadCount(!!this.authToken());
        }
      },
      onerror: (err) => {
        if (err instanceof Error && err.name === 'AbortError') {
          return;
        }
        return 5000;
      },
    }).catch(() => undefined);
  }

  stopSse() {
    if (this.abortSse) {
      this.abortSse.abort();
      this.abortSse = null;
    }
  }

  refreshUnreadCount(isLoggedIn: boolean) {
    if (!isLoggedIn) {
      this.unreadCount.set(0);
      return;
    }
    this.http
      .get<{ count: number }>(`${this.base}/notifications/unread-count`)
      .pipe(catchError(() => of({ count: 0 })))
      .subscribe((r) => this.unreadCount.set(r.count ?? 0));
  }

  list(page = 0, size = 20): Observable<Page<InboxItem>> {
    const params = new HttpParams()
      .set('page', String(page))
      .set('size', String(size));
    return this.http.get<Page<InboxItem>>(`${this.base}/notifications`, { params });
  }

  markRead(id: number): Observable<void> {
    return this.http.patch<void>(`${this.base}/notifications/${id}/read`, {});
  }

  markAllRead(): Observable<{ updated: number }> {
    return this.http.patch<{ updated: number }>(`${this.base}/notifications/read-all`, {}).pipe(
      tap(() => {
        this.unreadCount.set(0);
      }),
    );
  }
}
