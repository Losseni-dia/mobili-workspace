import { Component, DestroyRef, computed, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
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

export interface NavSection {
  title: string;
  items: NavItem[];
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
  private destroyRef = inject(DestroyRef);
  authService = inject(AuthService);
  private partenaireService = inject(PartenaireService);
  private configuration = inject(ConfigurationService);

  /**
   * Lien "Retour site" — ce shell est partagé entre l'app voyageur et Mobili Business
   * (`@mobili-app/*`) : un simple `routerLink="/"` était résolu dans le routeur business
   * (accueil connexion pro) au lieu du site public voyageur (feedback testeurs).
   */
  travelerSiteUrl = this.configuration.getTravelerWebBaseUrl();

  private currentUrl = signal<string>(this.router.url);
  collapsed = signal<boolean>(false);
  /** Tiroir mobile (< 768px) : logo + avatar seuls dans la barre, l'avatar révèle ce menu. */
  mobileMenuOpen = signal(false);

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

  /**
   * Regroupé par intention (Activité / Réseau / Compte) plutôt qu'une liste plate historique
   * (l'ordre précédent plaçait Communication en 2e position pour une raison ponctuelle, pas une
   * hiérarchie pensée). « Espace gare » reste une section à part : c'est un changement de
   * contexte, pas une simple page de plus.
   */
  navSections = computed((): NavSection[] => {
    const sections: NavSection[] = [];
    if (this.authService.hasRole('GARE')) {
      sections.push({
        title: 'Espace gare',
        items: [{ label: 'Accueil gare (scan)', icon: '🚉', path: '/gare/accueil', exact: true }],
      });
    }

    const activite: NavItem[] = [
      { label: 'Vue d\'ensemble', icon: '📊', path: '/partenaire/dashboard' },
      { label: 'Mes voyages', icon: '🚌', path: '/partenaire/trips' },
      // "Réservations" masquée de la navigation à la demande explicite du dirigeant (redondante
      // avec "Tickets" côté partenaire) — route/composant volontairement conservés tels quels
      // (booking-list.component), au cas où ce serait utile de la remontrer plus tard.
      // { label: 'Réservations', icon: '🎫', path: '/partenaire/bookings' },
      { label: 'Tickets', icon: '🎟️', path: '/partenaire/tickets' },
      { label: 'Transactions', icon: '💳', path: '/partenaire/transactions' },
    ];
    sections.push({ title: 'Activité', items: activite });

    const reseau: NavItem[] = [];
    if (this.authService.hasRole('PARTNER') && !this.authService.hasRole('GARE')) {
      reseau.push({ label: 'Gares', icon: '🏤', path: '/partenaire/gares' });
    }
    reseau.push({ label: 'Chauffeurs', icon: '🧑‍✈️', path: '/partenaire/chauffeurs' });
    // GareUserController est réservé au rôle PARTNER (jamais GARE) côté backend.
    if (this.authService.hasRole('PARTNER') && !this.authService.hasRole('GARE')) {
      reseau.push({ label: 'Comptes gare', icon: '🔑', path: '/partenaire/comptes-gare' });
    }
    sections.push({ title: 'Réseau', items: reseau });

    sections.push({
      title: 'Compte',
      items: [
        { label: 'Communication', icon: '💬', path: '/partenaire/company-messages' },
        { label: 'Notifications', icon: '🔔', path: '/partenaire/notifications' },
        { label: 'Support Mobili', icon: '🆘', path: '/partenaire/support' },
        { label: 'Profil compagnie', icon: '🏢', path: '/partenaire/settings' },
      ],
    });

    return sections;
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
    if (url.includes('/comptes-gare')) {
      return {
        title: 'Comptes gare',
        desc: 'Identifiants de connexion des responsables gare de votre réseau.',
        crumb: 'Comptes gare',
      };
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
    if (url.includes('/tickets')) return { title: 'Tickets', desc: 'Billets vendus sur toutes les gares de votre compagnie.', crumb: 'Tickets' };
    if (url.includes('/transactions')) return { title: 'Transactions', desc: 'Frais Mobili, commission et net compagnie, par réservation payée.', crumb: 'Transactions' };
    if (url.includes('/support')) return { title: 'Support Mobili', desc: 'Échangez directement avec l\'équipe Mobili.', crumb: 'Support' };
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
    // AUDIT-MOBILI.md §2.4 : router.events vit pour toute la durée de l'app — sans
    // takeUntilDestroyed, chaque navigation hors/vers ce shell accumulait un abonnement
    // supplémentaire jamais nettoyé (fuite mémoire progressive).
    this.router.events.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((event) => {
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
    if (
      item.path === '/gare/accueil' ||
      item.path === '/partenaire/gares' ||
      item.path === '/partenaire/company-messages' ||
      item.path === '/partenaire/support'
    ) {
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
