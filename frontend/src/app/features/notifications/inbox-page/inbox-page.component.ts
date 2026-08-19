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
    // "Vu" (vide le badge) dès l'ouverture de la page, quel que soit le point d'entrée
    // (cloche du header, lien direct, tiroir mobile...) — aligné sur le comportement mobile
    // (tap de l'onglet Notifications). Distinct de "lu" (markRead/markAll), qui ne change que
    // le style visuel de chaque ligne dans la liste.
    this.inbox.markAllSeen().subscribe({ error: () => this.inbox.refreshUnreadCount(true) });
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
      return '/gare/communications';
    }
    return null;
  }

  /**
   * Lien précis vers l'objet concerné par la notification (jamais une simple page d'accueil
   * vague) — même principe que côté mobile (`notifications_page.dart`, switch sur `notif.type`).
   * `null` : soit déjà couvert par `channelLink`/`companyComBasePath` (fil de voyage,
   * messagerie), soit aucune page cible n'existe côté web pour ce type (ex. types réservés à
   * l'admin, qui n'a pas d'inbox partagée).
   */
  itemLink(n: InboxItem): any[] | null {
    switch (n.type) {
      case 'TICKET_ISSUED':
        return ['/my-account/my-tickets'];
      case 'BOOKING_CANCELLED':
      case 'COVOITURAGE_BOOKING_ACCEPTED':
      case 'COVOITURAGE_BOOKING_REJECTED':
      case 'COVOITURAGE_BOOKING_NO_RESPONSE':
      case 'COVOITURAGE_BOOKING_PAYMENT_EXPIRED':
        // Résa concernée : passager, toujours dans "Mes réservations".
        return ['/my-account/bookings'];
      case 'COVOITURAGE_BOOKING_REQUEST':
        // Destiné au conducteur organisateur : ses demandes en attente.
        return ['/covoiturage/piloter'];
      case 'COV_KYC_EXPIRING_SOON':
      case 'COV_KYC_EXPIRED':
      case 'COV_KYC_APPROVED':
      case 'COV_KYC_REJECTED':
        return ['/covoiturage/profil'];
      case 'CLAIM_STATUS_UPDATED':
        return ['/my-account/claims'];
      case 'PARTNER_NEW_BOOKING':
        return ['/partenaire/bookings'];
      case 'GARE_STATION_NEW_BOOKING':
        // Pas de liste "réservations" dédiée côté gare — "Tickets" en tient lieu.
        return ['/gare/tickets'];
      case 'PARTNER_APPROVED':
      case 'PARTNER_REJECTED':
        return ['/partenaire/dashboard'];
      case 'MOBILI_ADMIN_INFO_PARTNER':
        return ['/partenaire/support'];
      default:
        return null;
    }
  }

  /**
   * Query params pour `itemLink` — seul `CLAIM_STATUS_UPDATED` en a besoin aujourd'hui
   * (`claimId`, lu par `ClaimsComponent` pour surligner/scroller vers la bonne réclamation,
   * même principe que `bookingId`/`reason` déjà gérés par ce composant).
   */
  itemQueryParams(n: InboxItem): Record<string, string> | undefined {
    if (n.type === 'CLAIM_STATUS_UPDATED' && n.claimId != null) {
      return { claimId: String(n.claimId) };
    }
    return undefined;
  }

  itemLinkLabel(n: InboxItem): string {
    switch (n.type) {
      case 'TICKET_ISSUED':
        return 'Voir mes billets';
      case 'BOOKING_CANCELLED':
      case 'COVOITURAGE_BOOKING_ACCEPTED':
      case 'COVOITURAGE_BOOKING_REJECTED':
      case 'COVOITURAGE_BOOKING_NO_RESPONSE':
      case 'COVOITURAGE_BOOKING_PAYMENT_EXPIRED':
        return 'Voir la réservation';
      case 'COVOITURAGE_BOOKING_REQUEST':
        return 'Voir la demande';
      case 'COV_KYC_EXPIRING_SOON':
      case 'COV_KYC_EXPIRED':
      case 'COV_KYC_APPROVED':
      case 'COV_KYC_REJECTED':
        return 'Voir mon profil covoiturage';
      case 'CLAIM_STATUS_UPDATED':
        return 'Voir la réclamation';
      case 'PARTNER_NEW_BOOKING':
      case 'GARE_STATION_NEW_BOOKING':
        return 'Voir la réservation';
      case 'PARTNER_APPROVED':
      case 'PARTNER_REJECTED':
        return 'Voir mon espace';
      case 'MOBILI_ADMIN_INFO_PARTNER':
        return 'Voir le message';
      default:
        return 'Voir';
    }
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
      case 'COV_KYC_APPROVED':
        return 'CNI validée';
      case 'COV_KYC_REJECTED':
        return 'CNI refusée';
      case 'BOOKING_CANCELLED':
        return 'Réservation annulée';
      case 'PARTNER_APPROVED':
        return 'Société approuvée';
      case 'PARTNER_REJECTED':
        return 'Société refusée';
      case 'COVOITURAGE_BOOKING_REQUEST':
        return 'Demande covoiturage';
      case 'COVOITURAGE_BOOKING_ACCEPTED':
        return 'Covoiturage accepté';
      case 'COVOITURAGE_BOOKING_REJECTED':
        return 'Covoiturage refusé';
      case 'COVOITURAGE_BOOKING_NO_RESPONSE':
        return 'Covoiturage expiré';
      case 'COVOITURAGE_BOOKING_PAYMENT_EXPIRED':
        return 'Paiement expiré';
      case 'CLAIM_SUBMITTED':
      case 'CLAIM_STATUS_UPDATED':
        return 'Réclamation';
      default:
        return 'Info';
    }
  }
}
