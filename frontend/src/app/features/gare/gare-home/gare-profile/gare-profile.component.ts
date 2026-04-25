import { Component, computed, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../../core/services/auth/auth.service';

@Component({
  selector: 'app-gare-profile',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './gare-profile.component.html',
  styleUrl: './gare-profile.component.scss',
})
export class GareProfileComponent {
  auth = inject(AuthService);

  user = computed(() => this.auth.currentUser());

  roleLabels = computed(() => {
    const roles = this.user()?.roles;
    if (!roles?.length) return [] as string[];
    return (roles as (string | { name?: string })[]).map((r) => {
      const v = typeof r === 'string' ? r : r?.name;
      return (v || '').replace(/^ROLE_/, '');
    });
  });
}
