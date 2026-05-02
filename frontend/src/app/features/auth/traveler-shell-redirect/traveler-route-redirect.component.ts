import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

import { ConfigurationService } from '../../../configurations/services/configuration.service';

/**
 * Redirection navigateur vers l’URL de l’appli voyageurs (`travelerWebBase` + chemin depuis `route.data`).
 * Ex. `{ data: { travelerPath: '/auth/register-gare' } }`
 */
@Component({
  selector: 'app-traveler-route-redirect',
  standalone: true,
  template:
    '<p style="margin:48px;text-align:center;font-family:system-ui;color:#445">Redirection…</p>',
})
export class TravelerRouteRedirectComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private configuration = inject(ConfigurationService);

  ngOnInit(): void {
    const raw = this.route.snapshot.data['travelerPath'] ?? '/';
    const path = typeof raw === 'string' ? raw : String(raw);
    const origin = this.configuration.getTravelerWebBaseUrl().replace(/\/$/, '');
    const suffix = path.startsWith('/') ? path : `/${path}`;
    window.location.replace(origin + suffix);
  }
}
