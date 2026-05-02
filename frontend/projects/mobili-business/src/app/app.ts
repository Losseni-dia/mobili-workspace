import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

/** Shell minimal : pas de header public (les shells partenaire / gare embarquent leur layout). */
@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {}
