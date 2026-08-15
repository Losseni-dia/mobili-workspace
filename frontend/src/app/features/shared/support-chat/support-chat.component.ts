import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SupportMessage, SupportService, SupportThread } from '../../../core/services/support/support.service';
import { AuthService } from '../../../core/services/auth/auth.service';

/**
 * Support Mobili — un seul composant réutilisé côté voyageur (`/my-account/support`) et
 * côté business/gare (`/partenaire/support`, `/gare/support`) : même API `/admin-com`, seul le
 * contexte de navigation change (shell parent différent), pas le contenu.
 */
@Component({
  selector: 'app-support-chat',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './support-chat.component.html',
  styleUrl: './support-chat.component.scss',
})
export class SupportChatComponent implements OnInit {
  private supportService = inject(SupportService);
  private authService = inject(AuthService);

  threads = signal<SupportThread[]>([]);
  isLoadingThreads = signal(false);
  threadsError = signal<string | null>(null);

  selectedThreadId = signal<number | null>(null);
  messages = signal<SupportMessage[]>([]);
  isLoadingMessages = signal(false);
  messagesError = signal<string | null>(null);

  showNewThreadForm = signal(false);
  newSubject = signal('');
  newMessage = signal('');
  creating = signal(false);
  createError = signal<string | null>(null);

  replyBody = signal('');
  sending = signal(false);
  sendError = signal<string | null>(null);

  selectedThread = computed(() => this.threads().find((t) => t.id === this.selectedThreadId()) ?? null);
  currentUserId = computed(() => this.authService.currentUser()?.id ?? null);

  ngOnInit(): void {
    this.loadThreads();
  }

  loadThreads(): void {
    this.isLoadingThreads.set(true);
    this.threadsError.set(null);
    this.supportService.listThreads().subscribe({
      next: (rows) => {
        this.threads.set(rows);
        this.isLoadingThreads.set(false);
        if (rows.length === 0) {
          this.showNewThreadForm.set(true);
        }
      },
      error: (e) => {
        this.threadsError.set(e?.error?.message || 'Impossible de charger vos échanges avec le support.');
        this.isLoadingThreads.set(false);
      },
    });
  }

  openThread(thread: SupportThread): void {
    this.selectedThreadId.set(thread.id);
    this.showNewThreadForm.set(false);
    this.loadMessages(thread.id);
  }

  private loadMessages(threadId: number): void {
    this.isLoadingMessages.set(true);
    this.messagesError.set(null);
    this.supportService.getMessages(threadId).subscribe({
      next: (rows) => {
        this.messages.set(rows);
        this.isLoadingMessages.set(false);
      },
      error: (e) => {
        this.messagesError.set(e?.error?.message || 'Impossible de charger cette conversation.');
        this.isLoadingMessages.set(false);
      },
    });
  }

  openNewThreadForm(): void {
    this.selectedThreadId.set(null);
    this.createError.set(null);
    this.showNewThreadForm.set(true);
  }

  cancelNewThread(): void {
    this.showNewThreadForm.set(false);
  }

  submitNewThread(): void {
    const subject = this.newSubject().trim();
    const message = this.newMessage().trim();
    const userId = this.currentUserId();
    if (!subject || !message || !userId || this.creating()) return;

    this.creating.set(true);
    this.createError.set(null);
    this.supportService.createThread(userId, subject, message).subscribe({
      next: (thread) => {
        this.creating.set(false);
        this.newSubject.set('');
        this.newMessage.set('');
        this.showNewThreadForm.set(false);
        this.threads.update((list) => [thread, ...list]);
        this.openThread(thread);
      },
      error: (e) => {
        this.createError.set(e?.error?.message || "Impossible d'ouvrir ce fil de discussion.");
        this.creating.set(false);
      },
    });
  }

  submitReply(): void {
    const threadId = this.selectedThreadId();
    const body = this.replyBody().trim();
    if (!threadId || !body || this.sending()) return;

    this.sending.set(true);
    this.sendError.set(null);
    this.supportService.postMessage(threadId, body).subscribe({
      next: (msg) => {
        this.messages.update((list) => [...list, msg]);
        this.replyBody.set('');
        this.sending.set(false);
      },
      error: (e) => {
        this.sendError.set(e?.error?.message || "Impossible d'envoyer ce message.");
        this.sending.set(false);
      },
    });
  }
}
