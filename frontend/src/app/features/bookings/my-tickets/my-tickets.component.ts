import { Component, OnInit, signal, inject } from '@angular/core';
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

  tickets = signal<any[]>([]);
  isLoading = signal(true);

  ngOnInit() {
    this.loadUserTickets();
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
          this.tickets.set(data);
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
