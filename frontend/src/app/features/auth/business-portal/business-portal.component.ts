import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

import { ConfigurationService } from '../../../configurations/services/configuration.service';

@Component({
  selector: 'app-business-portal',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './business-portal.component.html',
  styleUrls: ['./business-portal.component.scss'],
})
export class BusinessPortalComponent {
  private configuration = inject(ConfigurationService);

  readonly travelerSiteUrl = `${this.configuration.getTravelerWebBaseUrl()}`;

  /** Inscription responsable gare (code compagnie) : uniquement sur l’appli voyageurs, route `/auth/register-gare`. */
  readonly travelerRegisterGareUrl = `${this.configuration.getTravelerWebBaseUrl()}/auth/register-gare`;
}
