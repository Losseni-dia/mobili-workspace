import { CommonModule } from '@angular/common';
import { Component, DestroyRef, inject, input, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import { catchError, map, of, switchMap } from 'rxjs';

import { ConfigurationService } from '../../configurations/services/configuration.service';

type DisplayKind = 'none' | 'image' | 'pdf';

interface ResolvedMedia {
  readonly url: string | null;
  readonly kind: DisplayKind;
}

/**
 * Affiche un fichier sous {@code uploads/} : URLs publiques (avatars, logos…) ou blob pour chemins sensibles (KYC, PDF…)
 * via {@code GET /v1/media/private} avec l’intercepteur JWT.
 */
@Component({
  selector: 'mobili-secure-upload-img',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (displayKind() === 'pdf' && src(); as u) {
      <a
        [href]="u"
        target="_blank"
        rel="noopener noreferrer"
        [attr.class]="hostClass() || null"
        >{{ pdfLinkLabel() }}</a
      >
    } @else if (displayKind() === 'image' && src(); as u) {
      <img
        [src]="u"
        [alt]="alt()"
        [attr.loading]="loading()"
        [attr.width]="width() ?? null"
        [attr.height]="height() ?? null"
        [attr.class]="hostClass() || null"
      />
    }
  `,
})
export class MobiliSecureUploadImgComponent {
  private readonly http = inject(HttpClient);
  private readonly config = inject(ConfigurationService);
  private readonly destroyRef = inject(DestroyRef);

  readonly relativePath = input<string | null | undefined>(undefined);
  readonly alt = input('');
  readonly hostClass = input<string>('', { alias: 'hostClass' });
  readonly loading = input<'lazy' | 'eager'>('lazy');
  readonly width = input<number | undefined>(undefined);
  readonly height = input<number | undefined>(undefined);
  readonly pdfLinkLabel = input('Ouvrir le PDF');

  readonly src = signal<string | null>(null);
  readonly displayKind = signal<DisplayKind>('none');
  private previous: string | null = null;

  constructor() {
    this.destroyRef.onDestroy(() => this.revokePreviousBlob());

    toObservable(this.relativePath)
      .pipe(
        switchMap((rel) => {
          const trimmed = rel?.trim();
          if (!trimmed) {
            return of<ResolvedMedia>({ url: null, kind: 'none' });
          }
          if (!this.config.isSensitiveUploadRelativePath(trimmed)) {
            return of<ResolvedMedia>({
              url: this.config.resolveUploadMediaUrl(trimmed),
              kind: 'image',
            });
          }
          return this.http
            .get('/media/private', {
              params: { rel: trimmed },
              responseType: 'blob',
            })
            .pipe(
              map((blob): ResolvedMedia => {
                const url = URL.createObjectURL(blob);
                const pdf =
                  blob.type === 'application/pdf' || trimmed.toLowerCase().endsWith('.pdf');
                return { url, kind: pdf ? 'pdf' : 'image' };
              }),
              catchError(() => of<ResolvedMedia>({ url: null, kind: 'none' })),
            );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((res) => this.applyResolved(res));
  }

  private revokePreviousBlob(): void {
    if (this.previous?.startsWith('blob:')) {
      URL.revokeObjectURL(this.previous);
    }
    this.previous = null;
  }

  private applyResolved(res: ResolvedMedia): void {
    if (this.previous?.startsWith('blob:')) {
      URL.revokeObjectURL(this.previous);
    }
    this.previous = res.url;
    this.src.set(res.url);
    this.displayKind.set(res.kind);
  }
}
