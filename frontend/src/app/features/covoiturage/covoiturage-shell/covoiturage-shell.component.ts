import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { filter } from 'rxjs';

@Component({
  selector: 'app-covoiturage-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './covoiturage-shell.component.html',
  styleUrl: './covoiturage-shell.component.scss',
})
export class CovoiturageShellComponent implements OnInit {
  private router = inject(Router);
  authService = inject(AuthService);

  private currentUrl = signal(this.router.url);
  collapsed = signal(false);

  pageTitle = computed((): { t: string; d: string; hideTop: boolean } => {
    const u = this.currentUrl();
    if (u.includes('/publier')) {
      return { t: '', d: '', hideTop: true };
    }
    if (u.includes('/piloter')) {
      return { t: 'Piloter', d: 'Console trajet (étapes, billets, descentes).', hideTop: false };
    }
    if (u.includes('/scan')) {
      return { t: '', d: '', hideTop: true };
    }
    if (u.includes('/notifications')) {
      return { t: 'Notifications', d: 'Alertes CNI, messages Mobili.', hideTop: false };
    }
    return {
      t: 'Covoiturage',
      d: 'Votre espace conducteur, hors réseau compagnie (type BlaBlaCar).',
      hideTop: false,
    };
  });

  constructor() {
    this.router.events.pipe(filter((e) => e instanceof NavigationEnd)).subscribe((e) => {
      this.currentUrl.set((e as NavigationEnd).urlAfterRedirects || (e as NavigationEnd).url);
    });
  }

  ngOnInit(): void {
    this.authService.fetchUserProfile().subscribe({
      error: (e) => console.error('Profil covoiturage', e),
    });
  }

  toggle() {
    this.collapsed.update((c) => !c);
  }

  logout() {
    this.authService.logout();
    void this.router.navigate(['/'], { replaceUrl: true });
  }
}
