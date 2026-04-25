import { Component, OnInit, signal, inject, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { AdminService, UserAdmin } from '../../../core/services/admin/admin.service';
import { Partner } from '../../../core/services/partners/partenaire.service';

@Component({
  selector: 'app-admin-users',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-users.html',
  styleUrl: './admin-users.scss',
})
export class AdminUsers implements OnInit {
  // ✅ Injection du nouveau service dédié à l'admin
  private adminService = inject(AdminService);

  users = signal<UserAdmin[]>([]);
  /** Partenaires « compagnies » (hors piscine covo. technique) pour le sélecteur employeur. */
  private partners = signal<Partner[]>([]);
  transportPartners = computed(() => this.partners().filter((p) => !p.covoiturageSoloPool));
  isLoading = signal(true);

  ngOnInit() {
    this.loadUsers();
  }

  loadUsers() {
    forkJoin({
      users: this.adminService.getAllUsers(),
      partners: this.adminService.getAllPartnersForAdmin(),
    }).subscribe({
      next: ({ users, partners }) => {
        this.users.set(users);
        this.partners.set(partners);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement users / partenaires', err);
        this.isLoading.set(false);
      },
    });
  }

  updateStatus(user: UserAdmin) {
    const newStatus = !user.enabled;
    // Utilisation de la méthode du AdminService
    this.adminService.toggleUserStatus(user.id, newStatus).subscribe({
      next: () => {
        // Mise à jour optimiste du signal
        this.users.update((list) =>
          list.map((u) => (u.id === user.id ? { ...u, enabled: newStatus } : u)),
        );
      },
    });
  }

  /** Rôle affiché : « covo » à la place de CHAUFFEUR pour l’inscription covo particulier. */
  displayRole(role: string, user: UserAdmin): string {
    const r = (role || '').replace(/^ROLE_/, '');
    if (r === 'CHAUFFEUR' && user.covoiturageSoloProfile) {
      return 'covo';
    }
    return r;
  }

  /**
   * Chauffeur d’une compagnie (pas covo. solo, pas rattaché gare) : on peut lier l’employeur.
   */
  canAssignEmployerCompany(user: UserAdmin): boolean {
    const isChf = (user.roles || []).some((r) => r.replace(/^ROLE_/, '') === 'CHAUFFEUR');
    if (!isChf || user.covoiturageSoloProfile) {
      return false;
    }
    if (user.stationName) {
      return false;
    }
    return true;
  }

  onEmployerPartnerPicked(user: UserAdmin, partnerId: number | null) {
    this.adminService.setUserEmployerPartner(user.id, partnerId).subscribe({
      next: (row) => {
        this.users.update((list) => list.map((u) => (u.id === user.id ? { ...u, ...row } : u)));
      },
      error: (e) => console.error('Rattachement compagnie', e),
    });
  }
}
