import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

/** Espace chauffeur : console trajet + scanner billets (sans mélange avec l’espace gare). */
@Component({
  selector: 'app-chauffeur-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './chauffeur-shell.component.html',
  styleUrl: './chauffeur-shell.component.scss',
})
export class ChauffeurShellComponent {}
