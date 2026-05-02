import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

import { ConfigurationService } from '../../../configurations/services/configuration.service';

@Component({
  selector: 'app-business-registration-hub',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './business-registration-hub.component.html',
  styleUrls: ['./business-registration-hub.component.scss'],
})
export class BusinessRegistrationHubComponent {
  private configuration = inject(ConfigurationService);

  readonly travelerRegisterCarpoolUrl = `${this.configuration.getTravelerWebBaseUrl()}/auth/register-carpool-chauffeur`;

  /** Auto-inscription gare avec code — conservée sur l’appli voyageurs (parcours voyageur « code »). */
  readonly travelerSiteUrlAuthGare = `${this.configuration.getTravelerWebBaseUrl()}/auth/register-gare`;
}
