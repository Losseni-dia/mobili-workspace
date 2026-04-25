import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TripChannelService, TripChannelMessage } from '../../../core/services/inbox/trip-channel.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

@Component({
  selector: 'app-trip-channel-page',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './trip-channel-page.component.html',
  styleUrl: './trip-channel-page.component.scss',
})
export class TripChannelPageComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private channel = inject(TripChannelService);
  private auth = inject(AuthService);
  private toast = inject(NotificationService);

  tripId = signal<number | null>(null);
  messages = signal<TripChannelMessage[]>([]);
  loading = signal(true);
  draft = '';
  sending = false;

  canPost = computed(() => {
    const a = this.auth;
    return a.hasRole('PARTNER') || a.hasRole('GARE') || a.hasRole('ADMIN');
  });

  ngOnInit() {
    const id = this.route.snapshot.paramMap.get('tripId');
    const n = id ? parseInt(id, 10) : NaN;
    if (Number.isNaN(n)) {
      this.loading.set(false);
      this.toast.show('Trajet invalide', 'error');
      return;
    }
    this.tripId.set(n);
    this.load();
  }

  load() {
    const tid = this.tripId();
    if (tid == null) {
      return;
    }
    this.loading.set(true);
    this.channel.list(tid).subscribe({
      next: (m) => {
        this.messages.set(m);
        this.loading.set(false);
      },
      error: () => {
        this.toast.show('Accès refusé ou trajet introuvable.', 'error');
        this.loading.set(false);
      },
    });
  }

  send() {
    const tid = this.tripId();
    if (tid == null || !this.draft.trim() || this.sending) {
      return;
    }
    this.sending = true;
    this.channel.post(tid, this.draft.trim()).subscribe({
      next: (m) => {
        this.messages.update((list) => [...list, m]);
        this.draft = '';
        this.sending = false;
        this.toast.show('Message publié. Les passagers en seront avisés.', 'success');
      },
      error: (err) => {
        this.sending = false;
        const msg =
          err?.status === 403
            ? "Vous ne pouvez pas publier sur ce voyage."
            : 'Envoi impossible pour le moment.';
        this.toast.show(msg, 'error');
      },
    });
  }

  backLink(): string {
    const u = this.router.url;
    if (u.includes('/partenaire/')) {
      return '/partenaire/trips';
    }
    if (u.includes('/gare/')) {
      return '/gare/accueil';
    }
    return '/my-account/my-tickets';
  }
}
