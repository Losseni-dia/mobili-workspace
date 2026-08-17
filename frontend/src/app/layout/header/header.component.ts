import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { ConfigurationService } from '../../configurations/services/configuration.service';
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
  private configuration = inject(ConfigurationService);

  /** Tiroir mobile (< 768px) : logo + avatar seuls dans la barre, l'avatar révèle ce menu. */
  mobileMenuOpen = signal(false);

  /** Même 5 pages que `UserShellComponent.navItems` (sidebar « Mon compte ») — dupliqué ici
   *  volontairement : petite liste statique, pas de service partagé entre les deux composants.
   *  "Support" retiré côté client (feedback testeurs), voir UserShellComponent.navItems. */
  readonly myAccountItems = [
    { label: "Vue d'ensemble", icon: '🏠', path: '/my-account/profile' },
    { label: 'Mes billets', icon: '🎫', path: '/my-account/my-tickets' },
    { label: 'Mes réservations', icon: '🧾', path: '/my-account/bookings' },
    { label: 'Réclamations', icon: '📮', path: '/my-account/claims' },
  ];

  getAvatarUrl(avatarPath: string | undefined): string | null {
    return this.configuration.resolveUploadMediaUrl(avatarPath ?? null);
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

  /**
   * Toujours l'inbox voyageur : ce header n'est rendu que dans l'app voyageur (jamais dans
   * Mobili Business, voir app.html). `/partenaire`, `/gare` et `/covoiturage` n'existent ici
   * que comme redirections automatiques (RedirectToBusinessComponent, window.location.replace)
   * vers le site Mobili Business — un compte "mixte" (aussi PARTNER/GARE/chauffeur covoiturage)
   * cliquant la cloche depuis le site voyageur se faisait donc éjecter vers Mobili Business
   * (feedback testeurs), au lieu de voir ses notifications voyageur.
   */
  notificationsPath(): string {
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
