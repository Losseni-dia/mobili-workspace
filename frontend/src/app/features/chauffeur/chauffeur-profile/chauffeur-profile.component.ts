import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { ConfigurationService } from '../../../configurations/services/configuration.service';

/**
 * Profil self-service du chauffeur (compagnie) — même contrat que le profil voyageur
 * (`PUT /users/{id}` multipart, part `user` JSON + `avatar` optionnel). Pas de contrôleur
 * dédié côté backend : `AuthService.updateProfile()` est réutilisé tel quel.
 */
@Component({
  selector: 'app-chauffeur-profile',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './chauffeur-profile.component.html',
  styleUrl: './chauffeur-profile.component.scss',
})
export class ChauffeurProfileComponent implements OnInit {
  private fb = inject(FormBuilder);
  authService = inject(AuthService);
  private router = inject(Router);
  private notification = inject(NotificationService);
  private configuration = inject(ConfigurationService);

  isLoading = signal(false);
  avatarPreview = signal<string | null>(null);
  selectedFile: File | null = null;
  user = this.authService.currentUser();

  /** Traduction alignée sur `_roleLabel()` (mobile, `profile_page.dart`). */
  private static readonly ROLE_LABELS: Record<string, string> = {
    ADMIN: 'SUPER ADMIN',
    PARTNER: 'PARTENAIRE',
    GARE: 'GARE',
    STATION: 'GARE',
    CHAUFFEUR: 'CHAUFFEUR',
    COVOITURAGE: 'CONDUCTEUR',
  };

  /** Rôle "principal" affiché en badge — même règle de priorité que le mobile. */
  primaryRoleLabel(): string {
    const roles = (this.user?.roles || []).map((r) => String(r).replace(/^ROLE_/, '').toUpperCase());
    for (const key of ['ADMIN', 'PARTNER', 'GARE', 'STATION', 'CHAUFFEUR', 'COVOITURAGE']) {
      if (roles.includes(key)) return ChauffeurProfileComponent.ROLE_LABELS[key];
    }
    return 'UTILISATEUR';
  }

  /** Liste brute des rôles, seule transformation : STATION -> GARE (comme mobile). */
  roleChips(): string[] {
    return (this.user?.roles || []).map((r) => {
      const clean = String(r).replace(/^ROLE_/, '').toUpperCase();
      return clean === 'STATION' ? 'GARE' : clean;
    });
  }

  profileForm = this.fb.group({
    firstname: ['', [Validators.required]],
    lastname: ['', [Validators.required]],
    email: ['', [Validators.required, Validators.email]],
    login: ['', [Validators.required]],
    phone: [''],
    password: [''],
  });

  ngOnInit() {
    if (this.user) {
      this.profileForm.patchValue({
        firstname: this.user.firstname,
        lastname: this.user.lastname,
        email: this.user.email,
        login: this.user.login,
        phone: this.user.phone,
      });
      if (this.user.avatarUrl) {
        const url = this.configuration.resolveUploadMediaUrl(this.user.avatarUrl);
        if (url) this.avatarPreview.set(url);
      }
    }
  }

  /** Aligné sur mobile (`ProfilePage`) : confirmation puis déconnexion. */
  logout() {
    if (!confirm('Se déconnecter ?')) return;
    this.authService.logout();
    this.router.navigate(['/']);
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      this.selectedFile = file;
      const reader = new FileReader();
      reader.onload = () => this.avatarPreview.set(reader.result as string);
      reader.readAsDataURL(file);
    }
  }

  onSubmit() {
    if (this.profileForm.invalid || !this.user) return;
    this.isLoading.set(true);

    const oldLogin = this.user.login;
    const raw = this.profileForm.value;
    const updatePayload = {
      firstname: raw.firstname,
      lastname: raw.lastname,
      email: raw.email,
      login: raw.login,
      phone: raw.phone,
      password: raw.password && raw.password.trim() !== '' ? raw.password : null,
    };

    const formData = new FormData();
    formData.append('user', new Blob([JSON.stringify(updatePayload)], { type: 'application/json' }));
    if (this.selectedFile) formData.append('avatar', this.selectedFile);

    this.authService.updateProfile(this.user.id, formData).subscribe({
      next: () => {
        this.isLoading.set(false);
        if (oldLogin !== raw.login) {
          this.notification.show('Votre login a changé. Veuillez vous reconnecter.', 'info');
          this.authService.logout();
          this.router.navigate(['/auth/login']);
        } else {
          this.notification.show('Profil mis à jour.', 'success');
          this.router.navigate(['/chauffeur/profile']);
        }
      },
      error: () => {
        this.notification.show('Erreur lors de la mise à jour du profil.', 'error');
        this.isLoading.set(false);
      },
    });
  }
}
