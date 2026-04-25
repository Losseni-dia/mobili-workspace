import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { AuthService } from '../../core/services/auth/auth.service';
import { MobiliInboxService } from '../../core/services/inbox/mobili-inbox.service';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive],
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss'],

})
export class HeaderComponent {
  public authService = inject(AuthService);
  mobiliInbox = inject(MobiliInboxService);
  private router = inject(Router);

  // URL pointant vers ton dossier .uploads via Spring Boot
  private readonly IMAGE_BASE_URL = 'http://localhost:8080/uploads/';

  getAvatarUrl(avatarPath: string | undefined): string | null {
    if (!avatarPath || avatarPath === '' || avatarPath.includes('null')) {
      return null;
    }
    if (avatarPath.startsWith('http')) return avatarPath;
    return `${this.IMAGE_BASE_URL}${avatarPath}`;
  }

  constructor() {
    this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        this.mobiliInbox.refreshUnreadCount(!!this.authService.currentUser());
      }
    });
    this.mobiliInbox.refreshUnreadCount(!!this.authService.currentUser());
  }

  /** Espace compagnie : dirigeant / rôle pro — pas l’inscription covoiturage « solo ». */
  showPartenaireEspaceLink(): boolean {
    return this.authService.hasRole('PARTNER') || this.authService.hasRole('ADMIN');
  }

  /** Gare : uniquement les comptes responsable gare (pas les seuls chauffeurs compagnie). */
  showGareEspaceLink(): boolean {
    if (this.showCovoiturageEspaceLink()) {
      return false;
    }
    return this.authService.hasRole('GARE');
  }

  /** Inscription covoiturage type BlaBlaCar (hors compagnie). */
  showCovoiturageEspaceLink(): boolean {
    return this.authService.currentUser()?.covoiturageSoloProfile === true;
  }

  /**
   * Console conducteur (codes trajet) pour équipes compagnies / gares. Les conducteurs
   * covoiturage solo passent par `/covoiturage/piloter`.
   */
  showChauffeurProLink(): boolean {
    if (this.authService.currentUser()?.covoiturageSoloProfile) {
      return false;
    }
    return (
      this.authService.hasRole('CHAUFFEUR') ||
      this.authService.hasRole('PARTNER') ||
      this.authService.hasRole('GARE') ||
      this.authService.hasRole('ADMIN')
    );
  }

  /** Page inbox : covoiturage solo, compagnie, gare, ou voyageur. */
  notificationsPath(): string {
    if (!this.authService.isLoggedIn()) {
      return '/my-account/notifications';
    }
    if (this.showCovoiturageEspaceLink()) {
      return '/covoiturage/notifications';
    }
    if (this.showPartenaireEspaceLink()) {
      return '/partenaire/notifications';
    }
    if (this.authService.hasRole('GARE')) {
      return '/gare/notifications';
    }
    return '/my-account/notifications';
  }

  getInitials(firstname: string | undefined, lastname: string | undefined): string {
    if (firstname && lastname) {
      return (firstname[0] + lastname[0]).toUpperCase();
    } else if (firstname) {
      return firstname[0].toUpperCase();
    }

    // Recours au login si les noms sont absents (ex: juste après le login)
    const login = this.authService.currentUser()?.login;
    return login ? login[0].toUpperCase() : 'M';
  }

  logout() {
    this.authService.logout(); // Suppression immédiate du token/signal
    this.router.navigate(['/'], {
      replaceUrl: true, // ✅ Empêche de revenir en arrière avec le bouton "Précédent"
      skipLocationChange: false,
    });
  }
}
