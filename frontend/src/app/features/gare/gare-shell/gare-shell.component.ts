import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';

interface GareNavItem {
  label: string;
  icon: string;
  path: string;
  exact?: boolean;
}

@Component({
  selector: 'app-gare-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './gare-shell.component.html',
  styleUrl: './gare-shell.component.scss',
})
export class GareShellComponent implements OnInit {
  private router = inject(Router);
  authService = inject(AuthService);

  private currentUrl = signal<string>(this.router.url);
  collapsed = signal(false);

  navItems: GareNavItem[] = [
    { label: 'Accueil', icon: '🏠', path: '/gare/accueil', exact: true },
    { label: 'Messages compagnie', icon: '💬', path: '/gare/company-messages' },
    { label: 'Notifications', icon: '🔔', path: '/gare/notifications' },
    { label: 'Scanner billets', icon: '📷', path: '/gare/scan' },
    { label: 'Profil gare', icon: '👤', path: '/gare/profil' },
  ];

  /** Mêmes accès compagnie que l’espace partenaire (rôle GARE lié à une compagnie). */
  companyNavItems: GareNavItem[] = [
    { label: 'Tableau de bord', icon: '📊', path: '/partenaire/dashboard' },
    { label: 'Chauffeurs', icon: '🧑‍✈️', path: '/partenaire/chauffeurs' },
    { label: 'Communication', icon: '💬', path: '/partenaire/company-messages' },
    { label: 'Notifications (compagnie)', icon: '🔔', path: '/partenaire/notifications' },
    { label: 'Mes voyages', icon: '🚌', path: '/partenaire/trips' },
    { label: 'Publier un trajet', icon: '＋', path: '/partenaire/add-trip' },
    { label: 'Réservations', icon: '🎫', path: '/partenaire/bookings' },
    { label: 'Profil compagnie', icon: '🏢', path: '/partenaire/settings' },
  ];

  pageInfo = computed(() => {
    const url = this.currentUrl();
    if (url.includes('/gare/company-messages')) {
      return {
        title: 'Messages compagnie',
        desc: 'Échanges avec le dirigeant et les autres gares (collectif ou ciblé).',
        crumb: 'Messages',
      };
    }
    if (url.includes('/gare/scan')) {
      return {
        title: 'Scanner embarquement',
        desc: 'Valide les titres de transport (QR code) à l’embarquement.',
        crumb: 'Scanner',
      };
    }
    if (url.includes('/gare/compte')) {
      return {
        title: 'Modifier le compte',
        desc: 'Nom, e-mail, avatar et mot de passe.',
        crumb: 'Compte',
      };
    }
    if (url.includes('/gare/profil')) {
      return {
        title: 'Profil gare',
        desc: 'Votre compte, la gare et le rôle sur la plateforme.',
        crumb: 'Profil',
      };
    }
    if (url.includes('/gare/notifications')) {
      return {
        title: 'Notifications',
        desc: 'Billets, annonces de voyage et messages compagnie.',
        crumb: 'Alertes',
      };
    }
    if (url.includes('/gare/trip-channel')) {
      return { title: 'Fil du voyage', desc: 'Publiez un retard ou une consigne à vos passagers.', crumb: 'Canal' };
    }
    return {
      title: 'Espace responsable gare',
      desc: 'Accueil et raccourcis vers le scan et votre profil.',
      crumb: 'Accueil',
    };
  });

  stationLine = computed(() => {
    const u = this.authService.currentUser();
    if (!u?.stationName) return 'Gare affectée';
    return u.stationName;
  });

  /** Aucune action gare / compagnie tant que le dirigeant n’a pas validé la gare. */
  gareActionsLocked = computed(() => {
    if (!this.authService.hasRole('GARE')) {
      return false;
    }
    return this.authService.currentUser()?.gareOperationsEnabled === false;
  });

  userInitials = computed(() => {
    const u = this.authService.currentUser();
    if (!u) return 'G';
    const f = (u.firstname || '').trim();
    const l = (u.lastname || '').trim();
    if (f && l) return (f[0] + l[0]).toUpperCase();
    if (f) return f[0].toUpperCase();
    return (u.login || 'G')[0].toUpperCase();
  });

  constructor() {
    this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        this.currentUrl.set(event.urlAfterRedirects || event.url);
      }
    });
  }

  ngOnInit(): void {
    this.authService.fetchUserProfile().subscribe({
      error: (e) => console.error('Rafraîchissement profil gare', e),
    });
  }

  /**
   * En attente de validation gare : messagerie + gestion des chauffeurs (inscription / affectation) restent accessibles.
   */
  isGareCompanyNavEntryAlwaysAllowed(item: GareNavItem): boolean {
    return item.path === '/partenaire/company-messages' || item.path === '/partenaire/chauffeurs';
  }

  toggleSidebar() {
    this.collapsed.update((v) => !v);
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/'], { replaceUrl: true });
  }
}
