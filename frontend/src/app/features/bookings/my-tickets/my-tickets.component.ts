import { Component, OnInit, computed, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { TicketResponse, TicketService } from '../../../core/services/ticket/ticket.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import html2canvas from 'html2canvas'; // ✅ Importation indispensable

/** VALIDÉ, UTILISÉ, ARRIVÉ, ANNULÉ (backend TicketStatus) + ALL. */
type TicketStatusFilter = 'ALL' | 'VALIDÉ' | 'UTILISÉ' | 'ARRIVÉ' | 'ANNULÉ';
type TicketSort = 'DEPARTURE_ASC' | 'DEPARTURE_DESC' | 'BOOKED_DESC';

@Component({
  selector: 'app-my-tickets',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './my-tickets.component.html',
  styleUrl: './my-tickets.component.scss',
})
export class MyTicketsComponent implements OnInit {
  private ticketService = inject(TicketService);
  private authService = inject(AuthService);
  private route = inject(ActivatedRoute);

  private static readonly HIDDEN_KEY = 'mobili.tickets.hidden';

  allTickets = signal<TicketResponse[]>([]);
  /** Numéros masqués localement (aucune suppression serveur — un billet émis reste émis). */
  hiddenNumbers = signal<Set<string>>(this.readHidden());
  isLoading = signal(true);

  /** Ticket en attente de confirmation de masquage (modale, pas de confirm() natif). */
  pendingHide = signal<TicketResponse | null>(null);

  // ====== Recherche / filtre / tri ======
  search = signal('');
  statusFilter = signal<TicketStatusFilter>('ALL');
  /** Par défaut : réservé le plus récemment en premier (comme "Activité récente", profil). */
  sort = signal<TicketSort>('BOOKED_DESC');

  /** Filtre reçu via `?bookingId=` (lien « Voir le billet » depuis Mes réservations) — aligné
   *  sur mobile (`context.go('/tickets?tripId=...')`, my_bookings_page.dart), ici par réservation
   *  plutôt que par trajet (un `TicketResponse` porte `bookingId`, pas directement filtrable par
   *  trajet côté web sans appel réseau supplémentaire). */
  filterBookingId = signal<number | null>(null);

  clearBookingFilter(): void {
    this.filterBookingId.set(null);
  }

  onSearch(value: string): void {
    this.search.set(value);
  }

  setStatusFilter(f: TicketStatusFilter): void {
    this.statusFilter.set(f);
  }

  setSort(s: TicketSort): void {
    this.sort.set(s);
  }

  resetFilters(): void {
    this.search.set('');
    this.statusFilter.set('ALL');
    this.filterBookingId.set(null);
  }

  /** Compte par statut sur les billets visibles (non masqués) — alimente les badges des chips. */
  countByStatus = computed(() => {
    const list = this.tickets();
    // Clés ASCII (pas d'accent) : le parser de template Angular n'accepte pas les caractères
    // accentués dans un accès de propriété ({{ countByStatus().validé }} casse le build).
    return {
      all: list.length,
      valide: list.filter((t) => t.status === 'VALIDÉ').length,
      utilise: list.filter((t) => t.status === 'UTILISÉ').length,
      arrive: list.filter((t) => t.status === 'ARRIVÉ').length,
      annule: list.filter((t) => t.status === 'ANNULÉ').length,
    };
  });

  filteredTickets = computed(() => {
    const list = this.tickets();
    const f = this.statusFilter();
    const q = this.search().trim().toLowerCase();
    const s = this.sort();

    const bookingId = this.filterBookingId();
    return list
      .filter((t) => bookingId == null || t.bookingId === bookingId)
      .filter((t) => f === 'ALL' || t.status === f)
      .filter((t) => {
        if (!q) return true;
        return (
          (t.ticketNumber || '').toLowerCase().includes(q) ||
          (t.passengerFullName || '').toLowerCase().includes(q) ||
          (t.boardingCity || t.departureCity || '').toLowerCase().includes(q) ||
          (t.alightingCity || t.arrivalCity || '').toLowerCase().includes(q) ||
          (t.partnerName || '').toLowerCase().includes(q)
        );
      })
      .sort((a, b) => {
        if (s === 'BOOKED_DESC') {
          const ta = a.bookingDate ? Date.parse(a.bookingDate) : 0;
          const tb = b.bookingDate ? Date.parse(b.bookingDate) : 0;
          return tb - ta;
        }
        const ta = a.departureDateTime ? Date.parse(a.departureDateTime) : 0;
        const tb = b.departureDateTime ? Date.parse(b.departureDateTime) : 0;
        return s === 'DEPARTURE_DESC' ? tb - ta : ta - tb;
      });
  });

  /** Voyage déjà passé ou billet déjà utilisé — n'a plus sa place dans "À venir". */
  private isHistorical(t: TicketResponse): boolean {
    if (t.status === 'UTILISÉ' || t.status === 'ANNULÉ') return true;
    const dep = t.departureDateTime ? Date.parse(t.departureDateTime) : NaN;
    return !Number.isNaN(dep) && dep < Date.now();
  }

  /** Billets à venir — mis en avant, tri appliqué (voir `sort`). */
  upcomingTickets = computed(() => this.filteredTickets().filter((t) => !this.isHistorical(t)));

  /** Voyages passés / annulés / déjà utilisés — relégués en bas, hors du flux principal. */
  historicalTickets = computed(() => this.filteredTickets().filter((t) => this.isHistorical(t)));

  /**
   * QR replié par défaut sur mobile (bouton "Afficher le code QR", aligné sur
   * `_TicketCardState._qrExpanded`, mobile_app) — sans effet sur desktop, où le
   * bouton toggle reste caché en CSS et le QR toujours visible.
   */
  qrOpenNumbers = signal<Set<string>>(new Set());

  isQrOpen(ticketNumber: string): boolean {
    return this.qrOpenNumbers().has(ticketNumber);
  }

  toggleQr(ticketNumber: string): void {
    this.qrOpenNumbers.update((set) => {
      const next = new Set(set);
      if (next.has(ticketNumber)) next.delete(ticketNumber);
      else next.add(ticketNumber);
      return next;
    });
  }

  tickets = computed(() =>
    this.allTickets().filter((t) => !this.hiddenNumbers().has(t.ticketNumber)),
  );

  ngOnInit() {
    const bookingIdParam = this.route.snapshot.queryParamMap.get('bookingId');
    if (bookingIdParam) {
      const id = Number(bookingIdParam);
      if (!Number.isNaN(id)) this.filterBookingId.set(id);
    }
    this.loadUserTickets();
  }

  askHide(ticket: any) {
    this.pendingHide.set(ticket);
  }

  cancelHide() {
    this.pendingHide.set(null);
  }

  confirmHide() {
    const ticket = this.pendingHide();
    if (!ticket) return;
    this.hiddenNumbers.update((set) => {
      const next = new Set(set);
      next.add(ticket.ticketNumber);
      this.persistHidden(next);
      return next;
    });
    this.pendingHide.set(null);
  }

  private readHidden(): Set<string> {
    if (typeof window === 'undefined') return new Set();
    try {
      const raw = window.localStorage.getItem(MyTicketsComponent.HIDDEN_KEY);
      return raw ? new Set(JSON.parse(raw)) : new Set();
    } catch {
      return new Set();
    }
  }

  private persistHidden(set: Set<string>) {
    if (typeof window === 'undefined') return;
    try {
      window.localStorage.setItem(MyTicketsComponent.HIDDEN_KEY, JSON.stringify([...set]));
    } catch {
      /* noop */
    }
  }

  // ✅ Nouvelle fonction de téléchargement direct
  // `elementId` : deux cartes coexistent dans le DOM (desktop masquée en CSS sur mobile et
  // inversement) — html2canvas ne capture rien d'un élément display:none, donc chaque bouton
  // (desktop / mobile) doit passer l'id de SA carte, effectivement visible au moment du clic.
  async downloadTicket(ticket: any, elementId?: string) {
    const ticketId = elementId ?? `ticket-${ticket.ticketNumber}`;
    const element = document.getElementById(ticketId);

    if (!element) {
      console.error('Élément ticket introuvable');
      return;
    }

    try {
      // Capture l'élément spécifique du ticket
      const canvas = await html2canvas(element, {
        scale: 2, // Améliore la netteté pour le QR Code
        backgroundColor: '#ffffff', // Force le fond blanc
        logging: false,
        useCORS: true, // Important si les images (QR) viennent d'une API externe
      });

      // Conversion en URL d'image et téléchargement automatique
      const imgData = canvas.toDataURL('image/png');
      const link = document.createElement('a');
      link.href = imgData;
      link.download = `Mobili-Ticket-${ticket.ticketNumber}.png`;
      link.click();
    } catch (err) {
      console.error("Erreur lors de la génération de l'image :", err);
    }
  }

  loadUserTickets() {
    const userId = this.authService.currentUser()?.id;
    if (userId) {
      this.ticketService.getTicketsByUserId(userId).subscribe({
        next: (data) => {
          this.allTickets.set(data);
          this.isLoading.set(false);
        },
        error: (err) => {
          console.error('Erreur lors du chargement des tickets', err);
          this.isLoading.set(false);
        },
      });
    }
  }
}
