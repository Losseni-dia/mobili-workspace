import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { NotificationBannerComponent } from '@mobili-app/layout/notification-banner/notification-banner.component';

/**
 * Shell minimal : pas de header public (les shells partenaire / gare embarquent leur layout).
 * NotificationBannerComponent manquait ici : tous les appels NotificationService.show() du
 * bundle business (ex. TripEditComponent/AddTripComponent) mettaient bien à jour le signal
 * partagé, mais rien ne le rendait jamais — aucun toast ne s'affichait, succès comme erreur.
 */
@Component({
  selector: 'app-root',
  imports: [RouterOutlet, NotificationBannerComponent],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {}
