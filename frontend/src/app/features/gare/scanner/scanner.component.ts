import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { ZXingScannerModule } from '@zxing/ngx-scanner';
import { BarcodeFormat } from '@zxing/library';
import { TicketService } from '../../../core/services/ticket/ticket.service';
import { AuthService } from '../../../core/services/auth/auth.service';

@Component({
  selector: 'app-ticket-scanner',
  standalone: true,
  imports: [CommonModule, ZXingScannerModule, RouterModule],
  templateUrl: './scanner.component.html',
  styleUrl: './scanner.component.scss',
})
export class TicketScannerComponent implements OnInit {
  private ticketService = inject(TicketService);
  private router = inject(Router);
  protected auth = inject(AuthService);

  /** Accueil adapté (gare vs covoiturage) — le même composant sert les deux routes. */
  backToAccueil = signal('/gare/accueil');

  // ✅ On définit le format attendu pour éviter l'erreur TS2322
  allowedFormats = [BarcodeFormat.QR_CODE];

  scanResult = signal<any>(null);
  isScanning = signal(true);
  errorMessage = signal('');

  ngOnInit(): void {
    const p = this.router.url.split('?')[0];
    if (p.startsWith('/covoiturage')) {
      this.backToAccueil.set('/covoiturage/accueil');
    } else if (p.startsWith('/chauffeur')) {
      this.backToAccueil.set('/chauffeur');
    } else {
      this.backToAccueil.set('/gare/accueil');
    }
  }

  onCodeResult(resultString: string) {
    this.isScanning.set(false);
    this.validateTicket(resultString);
  }

  validateTicket(ticketNumber: string) {
    this.ticketService.verifyTicket(ticketNumber).subscribe({
      next: (ticket) => {
        this.scanResult.set(ticket);
        this.errorMessage.set('');
      },
      error: (err) => {
        this.errorMessage.set(err.error?.message || 'Ticket invalide ou déjà utilisé');
        this.scanResult.set(null);
      },
    });
  }

  resetScanner() {
    this.scanResult.set(null);
    this.errorMessage.set('');
    this.isScanning.set(true);
  }
}
