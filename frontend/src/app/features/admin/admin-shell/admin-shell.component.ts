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

  navItems: NavItem[] = [
    { label: 'Vue d’ensemble', icon: '📊', path: '/admin/dashboard' },
    { label: 'Analyse app & journal', icon: '🔍', path: '/admin/analyse-app' },
    { label: 'Statistiques métier', icon: '📈', path: '/admin/metier' },
    { label: 'Annonces', icon: '📣', path: '/admin/communication' },
    { label: 'Utilisateurs', icon: '👥', path: '/admin/users' },
    { label: 'Partenaires', icon: '🏢', path: '/admin/partners' },
  ];

  pageTitle = computed(() => {
    const url = this.currentUrl();
    if (url.includes('analyse-app')) return 'Analyse app';
    if (url.includes('/admin/metier')) return 'Stats métier';
    if (url.includes('communication')) return 'Annonces partenaires';
    if (url.includes('users')) return 'Utilisateurs';
    if (url.includes('partners')) return 'Partenaires';
    return 'Vue d’ensemble';
  });

  pageDescription = computed(() => {
    const url = this.currentUrl();
    if (url.includes('analyse-app')) {
      return 'Journal d’événements et usage de l’app.';
    }
    if (url.includes('/admin/metier')) {
      return 'Lignes, volumes et revenus sur la période choisie.';
    }
    if (url.includes('communication')) {
      return '';
    }
    if (url.includes('users')) return 'Activer ou suspendre des comptes.';
    if (url.includes('partners')) return 'Fiches compagnies et comptes chauffeurs covoiturage (particuliers).';
    return 'Chiffres clés et raccourcis vers les vues détaillées.';
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
