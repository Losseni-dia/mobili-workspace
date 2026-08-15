import { Component, OnInit, computed, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { TicketService } from '../../../core/services/ticket/ticket.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import html2canvas from 'html2canvas'; // ✅ Importation indispensable

@Component({
  selector: 'app-my-tickets',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './my-tickets.component.html',
  styleUrl: './my-tickets.component.scss',
})
export class MyTicketsComponent implements OnInit {
  private ticketService = inject(TicketService);
  private authService = inject(AuthService);

  private static readonly HIDDEN_KEY = 'mobili.tickets.hidden';

  allTickets = signal<any[]>([]);
  /** Numéros masqués localement (aucune suppression serveur — un billet émis reste émis). */
  hiddenNumbers = signal<Set<string>>(this.readHidden());
  isLoading = signal(true);

  /** Ticket en attente de confirmation de masquage (modale, pas de confirm() natif). */
  pendingHide = signal<any | null>(null);

  tickets = computed(() =>
    this.allTickets().filter((t) => !this.hiddenNumbers().has(t.ticketNumber)),
  );

  ngOnInit() {
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
  async downloadTicket(ticket: any) {
    const ticketId = `ticket-${ticket.ticketNumber}`;
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
