import { Component, computed, inject, OnInit, signal } from '@angular/core';

import { CommonModule } from '@angular/common';

import { RouterLink } from '@angular/router';

import { AuthService } from '../../../core/services/auth/auth.service';

import { Trip, TripService } from '../../../core/services/trip/trip.service';

import { NotificationService } from '../../../core/services/notification/notification.service';

import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';



@Component({

  selector: 'app-covoiturage-home',

  standalone: true,

  imports: [CommonModule, RouterLink, MobiliSecureUploadImgComponent],

  templateUrl: './covoiturage-home.component.html',

  styleUrl: './covoiturage-home.component.scss',

})

export class CovoiturageHomeComponent implements OnInit {

  auth = inject(AuthService);

  private tripService = inject(TripService);

  private notify = inject(NotificationService);



  u = computed(() => this.auth.currentUser());

  myTrips = signal<Trip[] | null>(null);

  loadingTrips = signal(false);



  formatVehicleType = formatVehicleTypeLabel;



  kycStatusLabel(s: string | null | undefined): string {

    if (!s) return '—';

    const m: Record<string, string> = {

      NONE: 'Non transmis',

      PENDING: 'En attente de validation',

      APPROVED: 'Validé',

      REJECTED: 'Refusé',

      EXPIRED: 'CNI expirée',

    };

    return m[s] ?? s;

  }



  ngOnInit(): void {

    this.loadTrips();

    this.auth.fetchUserProfile().subscribe({ error: () => {} });

  }



  loadTrips() {

    this.loadingTrips.set(true);

    this.tripService.getCovoiturageSoloMyTrips().subscribe({

      next: (list) => {

        this.myTrips.set(list);

        this.loadingTrips.set(false);

      },

      error: () => {

        this.myTrips.set([]);

        this.loadingTrips.set(false);

      },

    });

  }



  removeTrip(id: number) {

    if (!confirm('Retirer ce voyage publié ?')) return;

    this.tripService.deleteCovoiturageSoloTrip(id).subscribe({

      next: () => {

        this.notify.show('Voyage supprimé.', 'success');

        this.loadTrips();

      },

      error: (e) => this.notify.show(e?.error?.message || 'Suppression impossible', 'error'),

    });

  }

}

