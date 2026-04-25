import { CommonModule } from '@angular/common';
import { Component, computed, DestroyRef, inject, input, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import { catchError, debounceTime, finalize, map, of, switchMap } from 'rxjs';

import {
  TripPricePreviewDraft,
  TripPricePreviewResponse,
  TripService,
} from '../../../../core/services/trip/trip.service';

type PreviewOutcome =
  | { ok: true; data: TripPricePreviewResponse | null }
  | { ok: false; msg: string };

@Component({
  selector: 'app-trip-segment-price-preview',
  standalone: true,
  imports: [CommonModule],
  template: `
    <section class="preview-card">
      <h3>Aperçu tarif (calcul serveur)</h3>
      <p class="hint">
        Données renvoyées par <code>POST /v1/trips/price-preview</code> : mêmes arrêts et prorata qu’à la réservation.
      </p>

      @if (loading()) {
        <p class="muted">Calcul en cours…</p>
      } @else if (errorMsg()) {
        <p class="err">{{ errorMsg() }}</p>
      } @else if (preview()) {
        <ol class="stop-list">
          @for (s of preview()!.stops; track s.stopIndex) {
            <li>
              <span class="idx">{{ s.stopIndex }}</span>
              {{ s.cityLabel || '—' }}
              @if (s.plannedDepartureAt) {
                <span class="time">({{ s.plannedDepartureAt | date: 'short' }})</span>
              }
            </li>
          }
        </ol>
        <div class="row">
          <label for="pv-boarding">Embarquement</label>
          <select id="pv-boarding" class="sel" [value]="boarding()" (change)="onBoardingSelect($event)">
            @for (s of preview()!.stops; track s.stopIndex) {
              <option [value]="s.stopIndex">{{ s.stopIndex }} — {{ s.cityLabel }}</option>
            }
          </select>
        </div>
        <div class="row">
          <label for="pv-alighting">Descente</label>
          <select id="pv-alighting" class="sel" [value]="alighting()" (change)="onAlightingSelect($event)">
            @for (s of preview()!.stops; track s.stopIndex) {
              <option [value]="s.stopIndex">{{ s.stopIndex }} — {{ s.cityLabel }}</option>
            }
          </select>
        </div>
        <p class="result">
          <strong>Prix par place :</strong>
          {{ preview()!.pricePerSeat | number: '1.0-2' }} FCFA
        </p>
      } @else if (draft()) {
        <p class="muted">Indiquez départ, arrivée et un prix valide pour afficher l’aperçu.</p>
      }
    </section>
  `,
  styles: `
    .preview-card {
      margin-top: 1rem;
      padding: 1rem 1.25rem;
      border: 1px solid #c5cae9;
      border-radius: 8px;
      background: #f8f9ff;
    }
    h3 {
      margin: 0 0 0.35rem;
      font-size: 1.05rem;
    }
    .hint {
      font-size: 0.85rem;
      color: #555;
      margin: 0 0 0.75rem;
    }
    code {
      font-size: 0.8rem;
    }
    .stop-list {
      margin: 0 0 1rem;
      padding-left: 1.25rem;
    }
    .idx {
      font-weight: 700;
      margin-right: 0.35rem;
    }
    .time {
      font-size: 0.82rem;
      color: #666;
      margin-left: 0.35rem;
    }
    .row {
      margin-bottom: 0.65rem;
    }
    .row label {
      display: block;
      font-size: 0.88rem;
      margin-bottom: 0.2rem;
      font-weight: 600;
    }
    .sel {
      max-width: 100%;
      width: min(100%, 360px);
      padding: 0.4rem 0.5rem;
    }
    .result {
      margin: 0.85rem 0 0;
      font-size: 1.02rem;
    }
    .err {
      color: #b71c1c;
      font-size: 0.92rem;
    }
    .muted {
      color: #666;
      font-size: 0.92rem;
      margin: 0;
    }
  `,
})
export class TripSegmentPricePreviewComponent {
  draft = input<TripPricePreviewDraft | null>(null);

  private readonly tripService = inject(TripService);
  private readonly destroyRef = inject(DestroyRef);

  boarding = signal(0);
  alighting = signal(1);

  loading = signal(false);
  preview = signal<TripPricePreviewResponse | null>(null);
  errorMsg = signal<string | null>(null);

  private readonly comb = computed(() => ({
    draft: this.draft(),
    boarding: this.boarding(),
    alighting: this.alighting(),
  }));

  constructor() {
    toObservable(this.comb)
      .pipe(
        debounceTime(300),
        switchMap(({ draft, boarding, alighting }) => {
          if (
            !draft ||
            draft.price == null ||
            draft.price < 0 ||
            !draft.departureCity?.trim() ||
            !draft.arrivalCity?.trim()
          ) {
            return of<PreviewOutcome>({ ok: true, data: null }).pipe(finalize(() => this.loading.set(false)));
          }
          this.loading.set(true);
          return this.tripService
            .previewSegmentPrice({
              departureCity: draft.departureCity,
              arrivalCity: draft.arrivalCity,
              moreInfo: draft.moreInfo ?? '',
              price: draft.price,
              boardingStopIndex: boarding,
              alightingStopIndex: alighting,
              departureDateTime: draft.departureDateTime,
              legFares: draft.legFares,
              originDestinationPrice: draft.originDestinationPrice,
            })
            .pipe(
              map((data): PreviewOutcome => ({ ok: true, data })),
              catchError((err) =>
                of<PreviewOutcome>({
                  ok: false,
                  msg:
                    err?.error?.message ||
                    err?.error?.error ||
                    err?.message ||
                    'Aperçu indisponible',
                }),
              ),
              finalize(() => this.loading.set(false)),
            );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((res) => {
        if (res.ok) {
          this.errorMsg.set(null);
          this.preview.set(res.data);
          if (res.data) {
            this.clampBoardingAlighting(res.data.lastStopIndex);
          }
        } else {
          this.preview.set(null);
          this.errorMsg.set(res.msg);
        }
      });
  }

  private clampBoardingAlighting(last: number) {
    let b = this.boarding();
    let a = this.alighting();
    const L = Math.max(0, last);
    if (L <= 0) {
      this.boarding.set(0);
      this.alighting.set(0);
      return;
    }
    if (b > L) b = 0;
    if (b < 0) b = 0;
    if (a > L) a = L;
    if (a <= b) a = Math.min(L, b + 1);
    if (b !== this.boarding()) this.boarding.set(b);
    if (a !== this.alighting()) this.alighting.set(a);
  }

  onBoardingSelect(ev: Event) {
    const v = Number((ev.target as HTMLSelectElement).value);
    if (Number.isNaN(v)) return;
    this.boarding.set(v);
    const p = this.preview();
    if (!p) return;
    const last = p.lastStopIndex;
    if (last > 0 && this.alighting() <= v) {
      this.alighting.set(Math.min(last, v + 1));
    }
  }

  onAlightingSelect(ev: Event) {
    const v = Number((ev.target as HTMLSelectElement).value);
    if (Number.isNaN(v)) return;
    this.alighting.set(v);
  }
}
