import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { MobiliInboxService, InboxItem } from '../../../core/services/inbox/mobili-inbox.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

@Component({
  selector: 'app-inbox-page',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './inbox-page.component.html',
  styleUrl: './inbox-page.component.scss',
})
export class InboxPageComponent implements OnInit {
  private inbox = inject(MobiliInboxService);
  private toast = inject(NotificationService);
  private router = inject(Router);

  items = signal<InboxItem[]>([]);
  loading = signal(true);
  totalElements = signal(0);
  page = signal(0);
  pageSize = 20;

  ngOnInit() {
    this.load(0);
    this.inbox.refreshUnreadCount(true);
  }

  load(p: number) {
    this.loading.set(true);
    this.inbox.list(p, this.pageSize).subscribe({
      next: (pg) => {
        this.items.set(pg.content);
        this.totalElements.set(pg.totalElements);
        this.page.set(p);
        this.loading.set(false);
      },
      error: () => {
        this.toast.show('Impossible de charger les notifications.', 'error');
        this.loading.set(false);
      },
    });
  }

  markRead(n: InboxItem) {
    if (n.read) {
      return;
    }
    this.inbox.markRead(n.id).subscribe({
      next: () => {
        this.items.update((list) =>
          list.map((x) => (x.id === n.id ? { ...x, read: true } : x)),
        );
        this.inbox.refreshUnreadCount(true);
      },
      error: () => this.toast.show('Action impossible pour le moment.', 'error'),
    });
  }

  markAll() {
    this.inbox.markAllRead().subscribe({
      next: () => {
        this.items.update((list) => list.map((x) => ({ ...x, read: true })));
        this.toast.show('Toutes les notifications sont marquées comme lues.', 'success');
      },
      error: () => this.toast.show('Action impossible pour le moment.', 'error'),
    });
  }

  channelLink(tripId: number | null): any[] | null {
    if (tripId == null) {
      return null;
    }
    const u = this.router.url;
    if (u.includes('/partenaire/')) {
      return ['/partenaire/trip-channel', tripId];
    }
    if (u.includes('/gare/')) {
      return ['/gare/trip-channel', tripId];
    }
    return ['/my-account/trip-channel', tripId];
  }

  /**
   * Base URL messagerie partenaire/gares (dépend du contexte d’où l’inbox est ouvert).
   */
  companyComBasePath(): string | null {
    const u = this.router.url;
    if (u.includes('/partenaire/')) {
      return '/partenaire/company-messages';
    }
    if (u.includes('/gare/')) {
      return '/gare/company-messages';
    }
    return null;
  }

  typeLabel(t: InboxItem): string {
    switch (t.type) {
      case 'TICKET_ISSUED':
        return 'Billet';
      case 'TRIP_CHANNEL_MESSAGE':
        return 'Annonce voyage';
      case 'PARTNER_NEW_BOOKING':
        return 'Réservation';
      case 'GARE_STATION_NEW_BOOKING':
        return 'Gare / résa';
      case 'PARTNER_GARE_COM_MESSAGE':
        return 'Message gares';
      case 'MOBILI_ADMIN_INFO_PARTNER':
        return 'Mobili (info)';
      case 'COV_KYC_EXPIRING_SOON':
        return 'CNI (expiration)';
      case 'COV_KYC_EXPIRED':
        return 'CNI expirée';
      default:
        return 'Info';
    }
  }
}
