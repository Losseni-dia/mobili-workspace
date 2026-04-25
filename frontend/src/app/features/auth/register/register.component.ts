import { Component, inject, OnInit, signal, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { AuthService } from '../../../core/services/auth/auth.service';
import { ImagePanDirective } from '../../../shared/directives/image-pan.directive';

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

  isEmailValid(): boolean {
    const emailPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
    return emailPattern.test(this.user.email);
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
    if (!this.passwordsMatch() || !this.isEmailValid() || this.user.login.length < 3) return;

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
      error: (err) => {
        this.isLoading.set(false);
        this.errorMessage.set('Erreur : Ce login ou cet email est déjà utilisé.');
      },
    });
  }
}
