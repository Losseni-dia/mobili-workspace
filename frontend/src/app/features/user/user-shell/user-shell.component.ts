import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';

interface NavItem {
  label: string;
  icon: string;
  path: string;
}

@Component({
  selector: 'app-user-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './user-shell.component.html',
  styleUrl: './user-shell.component.scss',
})
export class UserShellComponent {
  private router = inject(Router);
  authService = inject(AuthService);

  private currentUrl = signal<string>(this.router.url);
  collapsed = signal<boolean>(false);

  navItems: NavItem[] = [
    { label: 'Vue d\'ensemble', icon: '🏠', path: '/my-account/profile' },
    { label: 'Notifications', icon: '🔔', path: '/my-account/notifications' },
    { label: 'Mes billets', icon: '🎫', path: '/my-account/my-tickets' },
    { label: 'Mes réservations', icon: '🧾', path: '/my-account/bookings' },
    { label: 'Modifier mon profil', icon: '✎', path: '/my-account/profile-edit' },
  ];

  pageInfo = computed(() => {
    const url = this.currentUrl();
    if (url.includes('/notifications')) return { title: 'Notifications', desc: 'Billets, annonces de voyage et messages compagnie.', crumb: 'Alertes' };
    if (url.includes('/trip-channel')) return { title: 'Fil du voyage', desc: 'Annonces et retards partagés par la gare ou le partenaire.', crumb: 'Canal' };
    if (url.includes('/my-tickets')) return { title: 'Mes billets', desc: 'Tous tes titres de transport prêts à présenter à l\'embarquement.', crumb: 'Billets' };
    if (url.includes('/bookings')) return { title: 'Mes réservations', desc: 'Suis l\'état de tes réservations et leurs paiements.', crumb: 'Réservations' };
    if (url.includes('/profile-edit')) return { title: 'Modifier mon profil', desc: 'Mets à jour tes informations personnelles et ton avatar.', crumb: 'Édition' };
    return { title: 'Mon espace voyageur', desc: 'Réservations, billets et activité récente.', crumb: 'Vue d\'ensemble' };
  });

  userInitials = computed(() => {
    const u = this.authService.currentUser();
    if (!u) return 'M';
    const f = (u.firstname || '').trim();
    const l = (u.lastname || '').trim();
    if (f && l) return (f[0] + l[0]).toUpperCase();
    if (f) return f[0].toUpperCase();
    return (u.login || 'M')[0].toUpperCase();
  });

  avatarUrl = computed(() => {
    const u = this.authService.currentUser();
    const path = u?.avatarUrl;
    if (!path || path === '' || path.includes('null')) return null;
    if (path.startsWith('http')) return path;
    return `${this.authService.IMAGE_BASE_URL}${path}`;
  });

  constructor() {
    this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        this.currentUrl.set(event.urlAfterRedirects || event.url);
      }
    });
  }

  toggleSidebar() { this.collapsed.update((v) => !v); }

  logout() {
    this.authService.logout();
    this.router.navigate(['/'], { replaceUrl: true });
  }
}
