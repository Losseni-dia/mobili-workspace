import { Signal, computed, signal } from '@angular/core';

const DEFAULT_STEP = 20;

/**
 * Pagination client "Voir plus" pour les listes/tableaux web (évite le scroll infini sur les
 * grosses listes — admin/tickets/trajets/réservations, trip-management, partner/gare-tickets).
 * Découpe un signal de liste déjà filtrée par paliers de {step} ; appeler reset() dans les
 * setters de filtre/recherche/période pour revenir au premier palier. Aligné sur le pattern
 * "LoadMoreButton" déjà utilisé côté mobilipro (trips_list_page/partner_trips_list_page).
 */
export class ListPager<T> {
  private pageSize;

  constructor(
    private source: Signal<T[]>,
    private step = DEFAULT_STEP,
  ) {
    this.pageSize = signal(step);
  }

  visible: Signal<T[]> = computed(() => this.source().slice(0, this.pageSize()));
  hasMore: Signal<boolean> = computed(() => this.source().length > this.pageSize());
  remaining: Signal<number> = computed(() => Math.max(0, this.source().length - this.pageSize()));

  showMore(): void {
    this.pageSize.update((v) => v + this.step);
  }

  reset(): void {
    this.pageSize.set(this.step);
  }
}
