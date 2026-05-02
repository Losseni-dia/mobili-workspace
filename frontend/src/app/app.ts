import { Component, computed, inject, signal } from '@angular/core';
import { NavigationEnd, Router, RouterOutlet } from '@angular/router';
import { HeaderComponent } from '../app/layout/header/header.component';
import { FooterComponent } from '../app/layout/footer/footer.component';
import { NotificationBannerComponent } from './layout/notification-banner/notification-banner.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, HeaderComponent, FooterComponent, NotificationBannerComponent],
  templateUrl: './app.html',
  styleUrl: 'app.scss',
})
export class App {
  private router = inject(Router);
  private currentUrl = signal<string>(this.router.url);

  /** Le header (navbar) est toujours affiché ; le pied de page public est masqué sur les espaces “shell”. */
  showGlobalFooter = computed(() => {
    const url = this.currentUrl();
    return (
      !url.startsWith('/admin') &&
      !url.startsWith('/covoiturage') &&
      !url.startsWith('/chauffeur') &&
      !url.startsWith('/my-account')
    );
  });

  constructor() {
    this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        this.currentUrl.set(event.urlAfterRedirects || event.url);
      }
    });
  }
}
