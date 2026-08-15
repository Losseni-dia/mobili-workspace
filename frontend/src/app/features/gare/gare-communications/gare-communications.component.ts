import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CompanyMessagesComponent } from '../../shared/company-messages/company-messages.component';
import { SupportChatComponent } from '../../shared/support-chat/support-chat.component';

/**
 * Point d'entrée unique "Communications" (aligné sur `partner_gare_com_page.dart`, mobile) à 2
 * sous-onglets : Canal société (fils gares↔compagnie, `CompanyMessagesComponent`) et Canal support
 * (messages Mobili, `SupportChatComponent`). N'implémente aucune logique métier propre — se
 * contente d'embarquer les 2 composants existants tels quels pour ne pas dupliquer leur état.
 */
@Component({
  selector: 'app-gare-communications',
  standalone: true,
  imports: [CommonModule, CompanyMessagesComponent, SupportChatComponent],
  templateUrl: './gare-communications.component.html',
  styleUrl: './gare-communications.component.scss',
})
export class GareCommunicationsComponent {
  activeTab = signal<'company' | 'support'>('company');

  setTab(tab: 'company' | 'support') {
    this.activeTab.set(tab);
  }
}
