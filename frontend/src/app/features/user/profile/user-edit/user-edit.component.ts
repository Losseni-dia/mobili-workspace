import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../../core/services/auth/auth.service';
import { NotificationService } from '../../../../core/services/notification/notification.service';

@Component({
  selector: 'app-user-edit',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './user-edit.component.html',
  styleUrls: ['./user-edit.component.scss'],
})
export class UserEditComponent implements OnInit {
  private fb = inject(FormBuilder);
  public authService = inject(AuthService);
  private router = inject(Router);
  private location = inject(Location);
  private notificationService = inject(NotificationService);

  isLoading = signal(false);
  avatarPreview = signal<string | null>(null);
  selectedFile: File | null = null;
  user = this.authService.currentUser();

  userForm = this.fb.group({
    firstname: ['', [Validators.required]],
    lastname: ['', [Validators.required]],
    email: ['', [Validators.required, Validators.email]],
    login: ['', [Validators.required]],
    password: [''],
  });

  ngOnInit() {
    if (this.user) {
      this.userForm.patchValue({
        firstname: this.user.firstname,
        lastname: this.user.lastname,
        email: this.user.email,
        login: this.user.login,
      });

      if (this.user.avatarUrl) {
        // 💡 CORRECTION : On n'ajoute plus "users/" manuellement car il est déjà
        // dans la chaîne retournée par ton API (vu dans ta console)
        const url = `${this.authService.IMAGE_BASE_URL}${this.user.avatarUrl}`;
        this.avatarPreview.set(url);
      }
    }
  }

  onCancel() {
    this.location.back();
  }

  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.selectedFile = file;
      const reader = new FileReader();
      reader.onload = () => this.avatarPreview.set(reader.result as string);
      reader.readAsDataURL(file);
    }
  }

  onSubmit() {
    if (this.userForm.invalid || !this.user) return;
    this.isLoading.set(true);

    const oldLogin = this.user.login; // On mémorise l'ancien login
    const newLogin = this.userForm.value.login;

    const formData = new FormData();
    const rawValues = this.userForm.value;

    // Préparation du payload sans password vide pour éviter l'erreur 400
    const updatePayload = {
      firstname: rawValues.firstname,
      lastname: rawValues.lastname,
      email: rawValues.email,
      login: rawValues.login,
      password: rawValues.password && rawValues.password.trim() !== '' ? rawValues.password : null,
    };

    const userBlob = new Blob([JSON.stringify(updatePayload)], { type: 'application/json' });
    formData.append('user', userBlob);

    if (this.selectedFile) {
      formData.append('avatar', this.selectedFile);
    }

    this.authService.updateProfile(this.user.id, formData).subscribe({
      next: () => {
        this.isLoading.set(false);

        if (oldLogin !== newLogin) {
          this.notificationService.show('Votre login a changé. Veuillez vous reconnecter.', 'info');
          this.authService.logout();
          this.router.navigate(['/auth/login']);
        } else {
          const inGare = this.router.url.includes('/gare/');
          this.router.navigate([inGare ? '/gare/profil' : '/my-account/profile']);
        }
      },
      error: () => {
        this.notificationService.show('Erreur lors de la mise à jour du profil.', 'error');
        this.isLoading.set(false);
      },
    });
  }
}
