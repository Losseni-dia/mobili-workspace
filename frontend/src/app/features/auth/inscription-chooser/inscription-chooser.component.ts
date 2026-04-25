import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';

@Component({
  selector: 'app-inscription-chooser',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './inscription-chooser.component.html',
  styleUrls: ['./inscription-chooser.component.scss'],
})
export class InscriptionChooserComponent {
  private router = inject(Router);

  goVoyageur() {
    this.router.navigate(['/auth/register']);
  }

  goSociete() {
    this.router.navigate(['/auth/register'], {
      queryParams: { returnUrl: '/partenaire/register' },
    });
  }

  goGare() {
    this.router.navigate(['/auth/register-gare']);
  }

  goCovoiturage() {
    this.router.navigate(['/auth/register-carpool-chauffeur']);
  }
}
