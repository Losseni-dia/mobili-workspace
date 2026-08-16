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
  /** Tiroir mobile (< 768px) : logo + avatar seuls dans la barre, l'avatar révèle ce menu. */
  mobileMenuOpen = signal(false);

  /**
   * Aligné sur `shell_gare.dart` (mobilipro) : Dashboard, Trajets, Tickets, Chauffeurs,
   * Communications, Notifications, Profil — 7 entrées plates, même ordre. Pas de scanner côté
   * gare (action CHAUFFEUR uniquement, voir `/chauffeur/scan`) ; Transactions n'est pas un onglet
   * sur mobile (carte du dashboard) mais reste une entrée dédiée ici (contenu identique, juste
   * plus visible côté web — pas une fonctionnalité web-only puisque l'écran mobile existe aussi).
   */
  navItems: GareNavItem[] = [
    { label: 'Accueil', icon: '🏠', path: '/gare/accueil', exact: true },
    { label: 'Mes voyages', icon: '🚌', path: '/partenaire/trips' },
    { label: 'Tickets', icon: '🎫', path: '/gare/tickets' },
    { label: 'Chauffeurs', icon: '🧑‍✈️', path: '/partenaire/chauffeurs' },
    { label: 'Communications', icon: '💬', path: '/gare/communications' },
    { label: 'Transactions', icon: '💳', path: '/gare/transactions' },
    { label: 'Notifications', icon: '🔔', path: '/gare/notifications' },
    { label: 'Profil gare', icon: '👤', path: '/gare/profil' },
  ];

  /** Publier un trajet reste une action compagnie séparée (FAB sur mobile, entrée dédiée ici). */
  companyNavItems: GareNavItem[] = [{ label: 'Publier un trajet', icon: '＋', path: '/partenaire/add-trip' }];

  pageInfo = computed(() => {
    const url = this.currentUrl();
    if (url.includes('/gare/communications')) {
      return {
        title: 'Communications',
        desc: 'Canal société (dirigeant et gares) et canal support Mobili.',
        crumb: 'Communications',
      };
    }
    if (url.includes('/gare/tickets')) {
      return {
        title: 'Tickets',
        desc: 'Billets vendus sur vos voyages, avec leur statut d’embarquement.',
        crumb: 'Tickets',
      };
    }
    if (url.includes('/gare/transactions')) {
      return {
        title: 'Transactions',
        desc: 'Frais Mobili, commission et net compagnie, par réservation payée.',
        crumb: 'Transactions',
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
   * En attente de validation gare : accueil, messagerie (communications) et gestion des chauffeurs
   * (inscription / affectation) restent accessibles.
   */
  isGareNavEntryAlwaysAllowed(item: GareNavItem): boolean {
    return (
      item.path === '/gare/accueil' ||
      item.path === '/gare/communications' ||
      item.path === '/partenaire/chauffeurs'
    );
  }

  toggleSidebar() {
    this.collapsed.update((v) => !v);
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/'], { replaceUrl: true });
  }
}
