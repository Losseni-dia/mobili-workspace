import { Component, inject, OnInit, signal, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';

import { AuthService } from '../../../core/services/auth/auth.service';
import { ImagePanDirective } from '../../../shared/directives/image-pan.directive';
import { extractApiErrorMessage } from '../../../core/utils/api-error.util';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, ImagePanDirective],
  templateUrl: './register.component.html',
  styleUrls: ['./register.component.scss'],
})
export class RegisterComponent implements OnInit {
  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  /** Renseigné via ?returnUrl= (ex. flux société → partenaire). */
  returnUrl: string | null = null;

  user = {
    login: '',
    email: '',
    phone: '',
    password: '',
    confirmPassword: '',
    firstname: '',
    lastname: '',
    role: 'ROLE_USER',
  };

  isLoading = signal(false);
  errorMessage = signal<string | null>(null);
  showPassword = signal(false);
  showConfirmPassword = signal(false);
  imagePreview = signal<string | null>(null);

  selectedFile: File | undefined;
  isConfirmTouched = false;
  imgPos = signal({ x: 50, y: 50 });
  imageZoom = signal(1);

  ngOnInit(): void {
    this.returnUrl = this.route.snapshot.queryParamMap.get('returnUrl');
  }

  // Calcule les initiales pour l'avatar par défaut
  getInitials(): string {
    const first = this.user.firstname?.charAt(0).toUpperCase() || '';
    const last = this.user.lastname?.charAt(0).toUpperCase() || '';
    return first && last ? `${first}${last}` : first || last || 'M';
  }

  updatePosition(pos: { x: number; y: number }) {
    untracked(() => {
      this.imgPos.set(pos);
    });
  }

  /** Email optionnel côté backend (`RegisterDTO` : @Email seul, pas @NotBlank) — vide accepté. */
  isEmailValid(): boolean {
    if (!this.user.email.trim()) return true;
    const emailPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
    return emailPattern.test(this.user.email);
  }

  /** Miroir de la contrainte backend `RegisterDTO.phone` : 8 à 15 caractères. */
  isPhoneValid(): boolean {
    const len = this.user.phone.trim().length;
    return len >= 8 && len <= 15;
  }

  passwordsMatch(): boolean {
    return this.user.password.length >= 6 && this.user.password === this.user.confirmPassword;
  }

  onZoomChange(event: Event) {
    const input = event.target as HTMLInputElement;
    this.imageZoom.set(parseFloat(input.value));
  }

  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.selectedFile = file;
      const reader = new FileReader();
      reader.onload = () => {
        this.imagePreview.set(reader.result as string);
        this.imageZoom.set(1);
        this.imgPos.set({ x: 50, y: 50 });
      };
      reader.readAsDataURL(file);
    }
  }

  togglePassword() {
    this.showPassword.update((v) => !v);
  }
  toggleConfirmPassword() {
    this.showConfirmPassword.update((v) => !v);
  }

  onRegister() {
    if (
      !this.passwordsMatch() ||
      !this.isEmailValid() ||
      !this.isPhoneValid() ||
      this.user.login.length < 3
    )
      return;

    this.isLoading.set(true);
    this.errorMessage.set(null);

    this.authService.register(this.user, this.selectedFile).subscribe({
      next: () => {
        this.router.navigate(['/auth/login'], {
          queryParams: {
            registered: 'true',
            ...(this.returnUrl ? { returnUrl: this.returnUrl } : {}),
          },
        });
      },
      error: (err: HttpErrorResponse) => {
        this.isLoading.set(false);
        const fallback =
          err.status === 409 || err.status === 400
            ? 'Erreur : Ce login ou cet email est déjà utilisé.'
            : `Erreur (${err.status}). Réessayez ou contactez le support.`;
        this.errorMessage.set(extractApiErrorMessage(err, fallback));
      },
    });
  }
}
