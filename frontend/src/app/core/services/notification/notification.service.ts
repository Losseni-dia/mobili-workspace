import { Injectable, signal } from '@angular/core';

export type NotificationLevel = 'success' | 'error' | 'info';

export interface NotificationState {
  message: string;
  level: NotificationLevel;
}

@Injectable({ providedIn: 'root' })
export class NotificationService {
  readonly notification = signal<NotificationState | null>(null);

  show(message: string, level: NotificationLevel = 'info'): void {
    this.notification.set({ message, level });
  }

  clear(): void {
    this.notification.set(null);
  }
}
