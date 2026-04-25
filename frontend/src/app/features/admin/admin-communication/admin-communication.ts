import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, PartnerBroadcastSegment, PartnerBroadcastTarget } from '../../../core/services/admin/admin.service';
import { Partner } from '../../../core/services/partners/partenaire.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

@Component({
  selector: 'app-admin-communication',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-communication.html',
  styleUrl: './admin-communication.scss',
})
export class AdminCommunication implements OnInit {
  private admin = inject(AdminService);
  private toast = inject(NotificationService);

  partners = signal<Partner[]>([]);
  loading = signal(true);
  sending = signal(false);

  title = '';
  body = '';
  target: PartnerBroadcastTarget = 'BROADCAST';
  segment: PartnerBroadcastSegment = 'ALL';
  includeDisabled = false;
  /** En mode PICK : IDs partenaires cochés */
  pickIds = signal<number[]>([]);

  publicPartners = computed(() => this.partners().filter((p) => !p.covoiturageSoloPool));
  poolPartners = computed(() => this.partners().filter((p) => !!p.covoiturageSoloPool));

  ngOnInit() {
    this.admin.getAllPartnersForAdmin().subscribe({
      next: (list) => {
        this.partners.set(list);
        this.loading.set(false);
      },
      error: () => {
        this.toast.show('Impossible de charger la liste des partenaires.', 'error');
        this.loading.set(false);
      },
    });
  }

  togglePick(id: number) {
    this.pickIds.update((arr) => {
      if (arr.includes(id)) {
        return arr.filter((x) => x !== id);
      }
      return [...arr, id];
    });
  }

  isPicked(id: number): boolean {
    return this.pickIds().includes(id);
  }

  selectPublicOnly() {
    const extra = this.publicPartners().map((p) => p.id);
    this.pickIds.update((arr) => Array.from(new Set([...arr, ...extra])));
  }

  selectPoolOnly() {
    const extra = this.poolPartners().map((p) => p.id);
    this.pickIds.update((arr) => Array.from(new Set([...arr, ...extra])));
  }

  clearPick() {
    this.pickIds.set([]);
  }

  send() {
    const t = this.title.trim();
    const b = this.body.trim();
    if (!t || !b) {
      this.toast.show('Renseignez le titre et le message.', 'error');
      return;
    }
    if (this.target === 'PICK' && this.pickIds().length === 0) {
      this.toast.show('Cochez au moins un partenaire, ou repassez en envoi groupé.', 'error');
      return;
    }
    this.sending.set(true);
    this.admin
      .sendPartnerCommunication({
        title: t,
        body: b,
        target: this.target,
        segment: this.segment,
        includeDisabled: this.includeDisabled,
        partnerIds: this.target === 'PICK' ? this.pickIds() : undefined,
      })
      .subscribe({
        next: (res) => {
          this.sending.set(false);
          this.toast.show(
            res.recipientCount === 0
              ? 'Aucun compte dirigeant ciblé (vérifiez les filtres).'
              : `Message envoyé à ${res.recipientCount} compte(s) dirigeant(s).`,
            res.recipientCount === 0 ? 'info' : 'success',
          );
          this.title = '';
          this.body = '';
          this.clearPick();
        },
        error: (e) => {
          this.sending.set(false);
          const msg = e?.error?.message || 'Envoi impossible.';
          this.toast.show(msg, 'error');
        },
      });
  }
}
