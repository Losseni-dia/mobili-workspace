import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';

interface NavItem {
  label: string;
  icon: string;
  path: string;
}

interface NavSection {
  title: string;
  items: NavItem[];
}

@Component({
  selector: 'app-admin-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './admin-shell.component.html',
  styleUrl: './admin-shell.component.scss',
})
export class AdminShellComponent {
  private router = inject(Router);
  authService = inject(AuthService);

  private currentUrl = signal<string>(this.router.url);
  collapsed = signal<boolean>(false);
  /** Tiroir mobile (< 768px) : logo + avatar seuls dans la barre, l'avatar révèle ce menu. */
  mobileMenuOpen = signal(false);

  /**
   * Regroupé par intention plutôt qu'une liste plate de 9 liens sans hiérarchie : Analytics
   * (reporting), Comptes (gestion d'identités), Ventes (données transactionnelles, même famille
   * de filtres date/recherche/statut), Communication à part (action, pas de la consultation).
   */
  navSections: NavSection[] = [
    { title: '', items: [{ label: 'Vue d’ensemble', icon: '📊', path: '/admin/dashboard' }] },
    {
      title: 'Analytics',
      items: [
        { label: 'Analyse app & journal', icon: '🔍', path: '/admin/analyse-app' },
        { label: 'Statistiques métier', icon: '📈', path: '/admin/metier' },
      ],
    },
    {
      title: 'Comptes',
      items: [
        { label: 'Utilisateurs', icon: '👥', path: '/admin/users' },
        { label: 'Partenaires', icon: '🏢', path: '/admin/partners' },
      ],
    },
    {
      title: 'Ventes',
      items: [
        { label: 'Tickets', icon: '🎫', path: '/admin/tickets' },
        { label: 'Réservations', icon: '📋', path: '/admin/bookings' },
        { label: 'Transactions', icon: '💳', path: '/admin/transactions' },
      ],
    },
    {
      title: 'Support',
      items: [{ label: 'Réclamations', icon: '📮', path: '/admin/claims' }],
    },
    {
      title: 'Marketing',
      items: [{ label: 'Coupons', icon: '🎟️', path: '/admin/coupons' }],
    },
    { title: 'Communication', items: [{ label: 'Annonces', icon: '📣', path: '/admin/communication' }] },
  ];

  pageTitle = computed(() => {
    const url = this.currentUrl();
    if (url.includes('analyse-app')) return 'Analyse app';
    if (url.includes('/admin/metier')) return 'Stats métier';
    if (url.includes('communication')) return 'Annonces partenaires';
    if (url.includes('users')) return 'Utilisateurs';
    if (url.includes('partners')) return 'Partenaires';
    if (url.includes('tickets')) return 'Tickets';
    if (url.includes('bookings')) return 'Réservations';
    if (url.includes('transactions')) return 'Transactions';
    if (url.includes('claims')) return 'Réclamations';
    if (url.includes('coupons')) return 'Coupons';
    return 'Vue d’ensemble';
  });

  userInitials = computed(() => {
    const u = this.authService.currentUser();
    if (!u) return 'A';
    const f = (u.firstname || '').trim();
    const l = (u.lastname || '').trim();
    if (f && l) return (f[0] + l[0]).toUpperCase();
    if (f) return f[0].toUpperCase();
    return (u.login || 'A')[0].toUpperCase();
  });

  constructor() {
    this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        this.currentUrl.set(event.urlAfterRedirects || event.url);
      }
    });
  }

  toggleSidebar() {
    this.collapsed.update((v) => !v);
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/'], { replaceUrl: true });
  }
}
