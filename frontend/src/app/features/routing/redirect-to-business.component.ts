import { Component, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ConfigurationService } from '../../configurations/services/configuration.service';

/**
 * Remplace la navigation (app voyageur) par le site Mobili Business (ex. 4201 en local),
 * en conservant chemin + query (profondeur, favoris, liens partagés).
 */
@Component({
  selector: 'app-redirect-to-business',
  standalone: true,
  template: `
    <p class="r2b">Redirection vers Mobili Business…</p>
    <p class="r2b r2b--hint">
      En local (deux ports), la session n’est pas partagée : reconnectez-vous sur Mobili Business si besoin.
    </p>
  `,
  styles: [
    `
      :host {
        display: block;
        padding: 1.5rem;
        font-family: system-ui, sans-serif;
        color: #333;
      }
      .r2b--hint {
        margin-top: 0.75rem;
        font-size: 0.9rem;
        color: #666;
        max-width: 28rem;
      }
    `,
  ],
})
export class RedirectToBusinessComponent implements OnInit {
  private readonly router = inject(Router);
  private readonly config = inject(ConfigurationService);

  ngOnInit(): void {
    const base = this.config.getBusinessWebBaseUrl();
    const path = this.router.url.split('?')[0] || '/';
    const search = typeof window !== 'undefined' ? window.location.search : '';
    const target = `${base.replace(/\/$/, '')}${path === '/' ? '' : path}${search}`;
    window.location.replace(target);
  }
}
