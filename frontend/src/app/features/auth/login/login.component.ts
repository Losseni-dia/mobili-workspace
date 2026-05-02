import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, ActivatedRoute, RouterLink } from '@angular/router';
import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { postLoginNavigateUrl } from '../../../core/auth/post-login-redirect.util';
import { MOBILI_APP_KIND, type MobiliAppKind } from '../../../core/config/mobili-app-kind.token';
import { AuthService } from '../../../core/services/auth/auth.service';
import { HttpErrorResponse } from '@angular/common/http';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss'],
})
export class LoginComponent implements OnInit {
  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private configuration = inject(ConfigurationService);
  private readonly appKind = inject<MobiliAppKind>(MOBILI_APP_KIND);

  credentials = { login: '', password: '' };
  errorMessage = signal<string | null>(null);
  isLoading = signal(false);
  /** Après inscription chauffeur covoiturage (query `registered=carpool`). */
  postRegisterHint = signal<string | null>(null);

  ngOnInit(): void {
    const reg = this.route.snapshot.queryParamMap.get('registered');
    if (reg === 'carpool') {
      this.postRegisterHint.set(
        'Inscription enregistrée. Votre compte est inactif tant qu’un administrateur n’a pas validé votre accès. Vous pourrez vous connecter une fois le compte activé.',
      );
    }
  }

  onSubmit() {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.postRegisterHint.set(null);

    this.authService.login(this.credentials).subscribe({
      next: () => {
        const target = postLoginNavigateUrl({
          kind: this.appKind,
          auth: this.authService,
          configuration: this.configuration,
          returnUrlRaw: this.route.snapshot.queryParams['returnUrl'],
        });
        if (target.startsWith('http://') || target.startsWith('https://')) {
          window.location.assign(target);
        } else {
          void this.router.navigateByUrl(target);
        }
      },
      error: (err: HttpErrorResponse) => {
        this.isLoading.set(false);
        const raw = err.error;
        const fromApi =
          typeof raw === 'string'
            ? raw
            : raw && typeof raw === 'object' && 'message' in raw
              ? String((raw as { message: unknown }).message)
              : '';
        this.errorMessage.set(
          fromApi.trim() ||
            'Identifiants incorrects ou compte inactif. Vérifiez vos saisies ou l’état de votre compte.',
        );
      },
    });
  }
}


