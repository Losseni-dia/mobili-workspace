import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NotificationService } from '../../core/services/notification/notification.service';

@Component({
  selector: 'app-notification-banner',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './notification-banner.component.html',
  styleUrl: './notification-banner.component.scss',
})
export class NotificationBannerComponent {
  readonly notificationService = inject(NotificationService);
}
