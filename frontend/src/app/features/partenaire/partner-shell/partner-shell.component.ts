import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import {
  isStationReadyForTrips,
  PartenaireService,
  Partner,
  Station,
} from '../../../core/services/partners/partenaire.service';

export interface NavItem {
  label: string;
  icon: string;
  path: string;
  exact?: boolean;
}

@Component({
  selector: 'app-partner-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './partner-shell.component.html',
  styleUrl: './partner-shell.component.scss',
})
export class PartnerShellComponent implements OnInit {
  private router = inject(Router);
  authService = inject(AuthService);
  private partenaireService = inject(PartenaireService);
  private configuration = inject(ConfigurationService);

  private currentUrl = signal<string>(this.router.url);
  collapsed = signal<boolean>(false);

  private companyInfo = signal<Partner | null>(null);
  private stations = signal<Station[] | null>(null);
  companyName = computed(() => this.companyInfo()?.name || '');
  /** Même clé qu’en profil compagnie (API génère le code s’il manque). */
  companyRegistrationCode = computed(() => {
    const c = this.companyInfo()?.registrationCode;
    return c?.trim() ? c.trim() : null;
  });
  companyLogoUrl = computed(() => {
    const path = this.companyInfo()?.logoUrl;
    return this.configuration.resolveUploadMediaUrl(path ?? null);
  });

  /** Inscription société : le compte existe mais l’admin doit activer la compagnie. */
  companyPendingAdmin = computed(() => {
    const c = this.companyInfo();
    return c != null && c.enabled === false;
  });

  /** Court retour après copie du code gare (sidebar). */
  codeCopyFeedback = signal(false);

  navItems = computed((): NavItem[] => {
    const base: NavItem[] = [];
    if (this.authService.hasRole('GARE')) {
      base.push({ label: 'Espace gare (scan)', icon: '🚉', path: '/gare/accueil', exact: true });
    }
    base.push({ label: 'Vue d\'ensemble', icon: '📊', path: '/partenaire/dashboard' });
    /** Toujours proche du haut : la capture utilisateur montrait un bundle sans ce lien. */
    base.push({ label: 'Communication', icon: '💬', path: '/partenaire/company-messages' });
    if (this.authService.hasRole('PARTNER') && !this.authService.hasRole('GARE')) {
      base.push({ label: 'Gares', icon: '🏤', path: '/partenaire/gares' });
    }
    base.push({ label: 'Chauffeurs', icon: '🧑‍✈️', path: '/partenaire/chauffeurs' });
    base.push(
      { label: 'Notifications', icon: '🔔', path: '/partenaire/notifications' },
      { label: 'Mes voyages', icon: '🚌', path: '/partenaire/trips' },
      { label: 'Réservations', icon: '🎫', path: '/partenaire/bookings' },
      { label: 'Profil compagnie', icon: '🏢', path: '/partenaire/settings' },
    );
    return base;
  });

  ctaPath = '/partenaire/add-trip';

  /** Tant qu’aucune gare n’est prête, ou gare (rôle) non validée. */
  partnerTripsLocked = computed(() => {
    if (this.companyPendingAdmin()) {
      return true;
    }
    if (this.authService.hasRole('GARE') && this.authService.currentUser()?.gareOperationsEnabled === false) {
      return true;
    }
    if (this.authService.hasRole('PARTNER') && !this.authService.hasRole('GARE')) {
      const list = this.stations();
      if (list == null) {
        return false;
      }
      if (list.length === 0) {
        return true;
      }
      return !list.some((s) => isStationReadyForTrips(s));
    }
    return false;
  });

  pageInfo = computed(() => {
    const url = this.currentUrl();
    if (url.includes('/company-messages')) {
      return {
        title: 'Communication',
        desc: 'Canal collectif ou messages ciblés par gare, avec l’équipe terrain.',
        crumb: 'Communication',
      };
    }
    if (url.includes('/notifications')) {
      return {
        title: 'Notifications',
        desc: 'Nouvelles réservations, annonces publiées et fil des voyages.',
        crumb: 'Alertes',
      };
    }
    if (url.includes('/trip-channel')) {
      return { title: 'Fil du voyage', desc: 'Annonces partagées avec les passagers du trajet.', crumb: 'Canal' };
    }
    if (url.includes('/gares')) {
      return {
        title: 'Gares',
        desc: 'Réseau par ville, segmentation des statistiques et des équipes.',
        crumb: 'Gares',
      };
    }
    if (url.includes('/trips')) return { title: 'Mes voyages', desc: 'Gère tous les trajets publiés par votre compagnie.', crumb: 'Voyages' };
    if (url.includes('/add-trip')) return { title: 'Publier un trajet', desc: 'Définis les détails du trajet et les prix par étape.', crumb: 'Publier' };
    if (url.includes('/edit-trip')) return { title: 'Modifier le trajet', desc: 'Mets à jour les informations du voyage.', crumb: 'Modifier' };
    if (url.includes('/bookings')) return { title: 'Réservations', desc: 'Suivez les réservations de vos clients.', crumb: 'Réservations' };
    if (url.includes('/settings')) return { title: 'Profil compagnie', desc: 'Modifie les informations de votre entreprise.', crumb: 'Profil' };
    return { title: 'Vue d\'ensemble', desc: 'Statistiques et dernière activité de votre compagnie.', crumb: 'Dashboard' };
  });

  userInitials = computed(() => {
    const u = this.authService.currentUser();
    if (!u) return 'P';
    const f = (u.firstname || '').trim();
    const l = (u.lastname || '').trim();
    if (f && l) return (f[0] + l[0]).toUpperCase();
    if (f) return f[0].toUpperCase();
    return (u.login || 'P')[0].toUpperCase();
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
      error: (e) => console.error('Rafraîchissement profil (shell partenaire)', e),
    });
    this.partenaireService.getMyPartnerInfo().subscribe({
      next: (data) => this.companyInfo.set(data),
      error: (err) => console.error('Erreur chargement info partenaire', err),
    });
    this.partenaireService.listStations().subscribe({
      next: (list) => this.stations.set(list),
      error: (err) => {
        console.error('Stations (shell partenaire)', err);
        this.stations.set([]);
      },
    });
  }

  /** Blocage accès outils compagnie tant que le réseau n’a aucune gare prête, ou gare (rôle) en attente. */
  isPartnerNavItemDisabled(item: NavItem): boolean {
    if (this.companyPendingAdmin()) {
      return item.path !== '/partenaire/settings';
    }
    if (!this.partnerTripsLocked()) {
      return false;
    }
    if (item.path === '/gare/accueil' || item.path === '/partenaire/gares' || item.path === '/partenaire/company-messages') {
      return false;
    }
    return item.path.startsWith('/partenaire');
  }

  copyCompanyCode() {
    const c = this.companyRegistrationCode();
    if (!c) return;
    void navigator.clipboard.writeText(c).then(() => {
      this.codeCopyFeedback.set(true);
      setTimeout(() => this.codeCopyFeedback.set(false), 2000);
    });
  }

  toggleSidebar() { this.collapsed.update((v) => !v); }

  logout() {
    this.authService.logout();
    this.router.navigate(['/'], { replaceUrl: true });
  }
}
