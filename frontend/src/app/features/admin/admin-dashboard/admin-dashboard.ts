import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AdminService, AdminStats } from '../../../core/services/admin/admin.service';

@Component({
  selector: 'app-admin-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './admin-dashboard.html',
  styleUrl: './admin-dashboard.scss',
})
export class AdminDashboard implements OnInit {
  private adminService = inject(AdminService);

  stats = signal<AdminStats | null>(null);
  isLoading = signal(true);
  loadError = signal<string | null>(null);

  ngOnInit() {
    this.loadStats();
  }

  // AUDIT-MOBILI.md §2.2 : échec de getAdminStats() auparavant totalement silencieux
  // (error: () => this.isLoading.set(false)) — aucun message affiché, l'admin voyait juste
  // un écran vide sans savoir si c'est "pas de données" ou "erreur réseau". Même pattern
  // (loadError signal + bouton réessayer) que admin-coupons.ts.
  loadStats() {
    this.isLoading.set(true);
    this.loadError.set(null);
    this.adminService.getAdminStats().subscribe({
      next: (data) => {
        this.stats.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement statistiques admin', err);
        this.loadError.set('Impossible de charger les statistiques. Réessaie.');
        this.isLoading.set(false);
      },
    });
  }
}
