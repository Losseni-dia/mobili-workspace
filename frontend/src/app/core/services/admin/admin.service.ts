import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { Partner } from '../partners/partenaire.service';

export interface AdminStats {
  totalUsers: number;
  totalPartners: number;
  totalTrips: number;
  /** Trajets dont le départ tombe dans l'année civile en cours, tout statut confondu —
   *  comparable à "Trajets avec ventes" de Stats métier (même filtre de date). */
  totalTripsThisYear: number;
  /** = totalTripsThisYear - trajets distincts avec ≥1 ticket vendu sur l'année. */
  tripsWithoutSalesThisYear: number;
  totalTickets: number;
  activeBookings: number;
  totalRevenue: number;
  /** Répartition all-time du CA par canal (CONFIRMED = en ligne, OFFLINE_SALE = guichet). */
  revenueOnline: number;
  revenueOffline: number;
}

/** Un jour civil + un compteur — même forme pour inscriptions users et partenaires. */
export interface DayCountEntry {
  date: string;
  count: number;
}

export interface DailyRegistrationStats {
  todayRegistrations: number;
  totalUsers: number;
  history: DayCountEntry[];
}

export interface DailyPartnerRegistrationStats {
  todayRegistrations: number;
  totalPartners: number;
  history: DayCountEntry[];
}

export interface DayLoginEntry {
  date: string;
  totalLogins: number;
  uniqueUsers: number;
}

export interface DailyLoginStats {
  todayTotalLogins: number;
  todayUniqueUsers: number;
  history: DayLoginEntry[];
}

export interface AnalyticsCountByType {
  type: string;
  count: number;
}

export interface AnalyticsSummary {
  from: string;
  days: number;
  byType: AnalyticsCountByType[];
  /** Mêmes types sur la période précédente de même durée — pour un delta en %. */
  previousByType: AnalyticsCountByType[];
}

export interface AnalyticsRecentEvent {
  id: number;
  occurredAt: string;
  eventType: string;
  detail: string;
}

/** Classement des exceptions serveur par fréquence (page Analyse app). */
export interface TopErrorEntry {
  exceptionClass: string;
  count: number;
  lastOccurredAt: string | null;
}

export type TripStatsPeriod = 'DAY' | 'WEEK' | 'MONTH' | 'YEAR' | 'CUSTOM';

/** ticketCount compte des TICKETS (unité = un siège), jamais des réservations. */
export interface TripStatEntry {
  rank: number;
  tripId: number;
  route: string;
  partnerName: string;
  stationName: string;
  ticketCount: number;
  revenueFcfa: number;
}

export interface RevenueDonutSlice {
  label: string;
  revenueFcfa: number;
  percentOfTotal: number;
}

export interface VolumeDonutSlice {
  label: string;
  ticketCount: number;
  percentOfTotal: number;
}

/** Un point de la courbe de croissance — un jour civil. */
export interface TripStatsDayEntry {
  date: string;
  ticketCount: number;
  revenueFcfa: number;
}

/** Option de filtre gare (Stats métier) — toutes compagnies confondues. */
export interface AdminStationOption {
  id: number;
  name: string;
  partnerName: string;
}

/** Aligné sur le record Java AdminTripStatsResponse (sérialisation JSON). */
export interface AdminTripStats {
  period: TripStatsPeriod;
  fromInclusive: string;
  toExclusive: string;
  /** Billets vendus (tickets actifs, unité = un siège) — jamais des réservations. */
  totalTickets: number;
  totalRevenueFcfa: number;
  activeTripCount: number;
  avgRevenuePerTicket: number;
  /** Répartition du CA par canal — même principe que les dashboards partenaire/gare/admin. */
  revenueOnlineFcfa: number;
  revenueOfflineFcfa: number;
  /** Ce que la plateforme retient : forfait client + commission. netCompanyFcfa = ce qui
   *  revient réellement aux compagnies = totalRevenueFcfa - totalServiceFeeFcfa - totalCommissionFcfa. */
  totalServiceFeeFcfa: number;
  totalCommissionFcfa: number;
  netCompanyFcfa: number;
  /** Période précédente de même durée — null si aucune donnée (pas de variation affichable). */
  previousTotalTickets: number | null;
  previousTotalRevenueFcfa: number | null;
  ticketsDeltaPercent: number | null;
  revenueDeltaPercent: number | null;
  top10ByTickets: TripStatEntry[];
  top10ByRevenue: TripStatEntry[];
  revenueByTripDonut: RevenueDonutSlice[];
  volumeByTripDonut: VolumeDonutSlice[];
  timeline: TripStatsDayEntry[];
}

// Interface pour les utilisateurs (si tu ne l'as pas déjà exportée ailleurs)
export interface UserAdmin {
  id: number;
  firstname: string;
  lastname: string;
  email: string;
  roles: string[];
  enabled: boolean;
  /** Dirigeant : nom partenaire (propriétaire). */
  partnerName?: string;
  /** Chauffeur covoiturage particulier. */
  covoiturageSoloProfile?: boolean;
  /** Compagnie (gare : partenaire de la gare ; sinon fiche partenaire liée). */
  linkedCompanyName?: string | null;
  /** Libellé gare si rôle gare. */
  stationName?: string | null;
  /** ID fiche compagnie employeuse (chauffeur salarié). */
  employerPartnerId?: number | null;
}

export type PartnerBroadcastTarget = 'BROADCAST' | 'PICK';

export type PartnerBroadcastSegment = 'ALL' | 'COMPANIES' | 'COVOITURAGE_POOL';

export interface AdminPartnerCommunicationPayload {
  title: string;
  body: string;
  target: PartnerBroadcastTarget;
  segment: PartnerBroadcastSegment;
  includeDisabled: boolean;
  partnerIds?: number[];
}

export interface AdminPartnerCommunicationResult {
  recipientCount: number;
}

/** Comptes inscription chauffeur covoiturage particulier (admin / partenaires). */
export interface CovoiturageSoloDriverAdminItem {
  id: number;
  firstname: string;
  lastname: string;
  email: string;
  covoiturageKycStatus: string | null;
  enabled: boolean;
  covoiturageDriverPhotoUrl: string | null;
}

/** Aligné sur AdminTripListItemResponse (backend) — catalogue publié uniquement (jamais les brouillons). */
export interface AdminTripListItem {
  id: number;
  route: string;
  partnerName: string;
  stationName: string;
  departureDateTime: string;
  totalSeats: number;
  availableSeats: number;
  price: number;
  status: string;
}

/** Aligné sur AdminTicketListItemResponse (backend). */
export interface AdminTicketListItem {
  id: number;
  ticketNumber: string;
  passengerName: string;
  route: string;
  partnerName: string;
  stationName: string;
  bookingDate: string;
  /** Date de départ du voyage — distincte de bookingDate (date d'achat), voir TicketService.PartnerTicket. */
  departureDateTime: string | null;
  amountPaid: number;
  status: string;
  seatNumber: string;
  scanned: boolean;
  /** Statut de la réservation d'origine — distingue vente en ligne (CONFIRMED) / guichet (OFFLINE_SALE). */
  bookingStatus: string | null;
}

/** Aligné sur AdminBookingListItemResponse (backend). */
export interface AdminBookingListItem {
  id: number;
  reference: string;
  customerName: string;
  route: string;
  partnerName: string;
  stationName: string;
  bookingDate: string;
  /** Date de départ du voyage — distincte de bookingDate (date de réservation). */
  departureDateTime: string | null;
  numberOfSeats: number;
  /** Vente initiale, figée — n'exclut PAS les tickets annulés depuis. Préférer `amount`. */
  totalPrice: number;
  /** Montant réellement dû aujourd'hui (se réduit après annulation partielle) — à afficher. */
  amount: number;
  status: string;
  /** Forfait de service client — 0 pour une vente guichet (OFFLINE_SALE). À masquer côté
   *  affichage pour OFFLINE_SALE plutôt que de se fier uniquement à cette valeur (couvre aussi
   *  les ventes guichet historiques créées avant ce correctif, voir BookingService.createOfflineSale). */
  serviceFee: number | null;
  /** Tous les numéros de sièges réservés à l'origine — voir BookingResponse.seatNumbers (même
   *  convention côté partenaire, booking-list.component). */
  seatNumbers: string[];
  /** Sous-ensemble de seatNumbers dont le ticket a été annulé individuellement — reste affiché
   *  (barré/grisé), jamais retiré de la liste. */
  cancelledSeatNumbers?: string[];
}

/**
 * Une ligne = une réservation payée (CONFIRMED/OFFLINE_SALE) — aligné sur
 * AdminTransactionResponse (backend). serviceFee/commissionTotal valent 0 sur les
 * réservations antérieures au forfait/à la commission (pas de recalcul rétroactif).
 */
export interface AdminTransaction {
  bookingId: number;
  reference: string;
  date: string;
  /** Date de départ du voyage — distincte de date (date de réservation). */
  departureDateTime: string | null;
  customerName: string;
  route: string;
  companyId: number | null;
  companyName: string;
  /** Gare de départ du trajet (null si covoiturage/aucune gare associée). */
  stationId: number | null;
  stationName: string;
  ticketsAmount: number;
  serviceFee: number;
  luggageFee: number;
  commissionTotal: number;
  companyNet: number;
  totalPrice: number;
  status: string;
}

@Injectable({ providedIn: 'root' })
export class AdminService {
  private http = inject(HttpClient);

  private readonly config = inject(ConfigurationService);

  public get IMAGE_BASE_URL(): string {
    return this.config.getUploadBaseUrl();
  }

  /**
   * Récupère les compteurs globaux pour le Dashboard
   * L'intercepteur ajoutera /v1/admin/stats
   */
  getAdminStats(): Observable<AdminStats> {
    return this.http.get<AdminStats>('/admin/stats');
  }

  getDailyLoginStats(days = 30): Observable<DailyLoginStats> {
    return this.http.get<DailyLoginStats>(`/admin/stats/daily-logins?days=${days}`);
  }

  /** Inscriptions utilisateurs sur [fromDate, toDate] (bornes civiles, YYYY-MM-DD) — somme de
   *  history[].count pour obtenir un total période, même principe que getTripList/getTicketList. */
  getRegistrationStats(fromDate: string, toDate: string): Observable<DailyRegistrationStats> {
    return this.http.get<DailyRegistrationStats>('/admin/stats/registrations', {
      params: this.dateRangeParams(fromDate, toDate),
    });
  }

  /** Inscriptions partenaires sur [fromDate, toDate] — voir getRegistrationStats. */
  getPartnerRegistrationStats(fromDate: string, toDate: string): Observable<DailyPartnerRegistrationStats> {
    return this.http.get<DailyPartnerRegistrationStats>('/admin/stats/partners', {
      params: this.dateRangeParams(fromDate, toDate),
    });
  }

  /** Trajets distincts avec ≥1 ticket vendu sur [fromDate, toDate] — même définition que "Trajets
   *  avec ventes" de Stats métier, réutilisée pour Vue d'ensemble (sections année/mois). */
  getTripsWithSalesCount(fromDate: string, toDate: string): Observable<{ count: number }> {
    return this.http.get<{ count: number }>('/admin/stats/trips-with-sales-count', {
      params: this.dateRangeParams(fromDate, toDate),
    });
  }

  getAnalyticsSummary(days = 7): Observable<AnalyticsSummary> {
    return this.http.get<AnalyticsSummary>(`/admin/analytics/summary?days=${days}`);
  }

  getRecentAnalyticsEvents(limit = 50, days?: number | null): Observable<AnalyticsRecentEvent[]> {
    let params = new HttpParams().set('limit', String(limit));
    if (days != null) {
      params = params.set('days', String(days));
    }
    return this.http.get<AnalyticsRecentEvent[]>('/admin/analytics/recent-events', { params });
  }

  getTopErrors(days = 7, limit = 10): Observable<TopErrorEntry[]> {
    return this.http.get<TopErrorEntry[]>(`/admin/analytics/top-errors?days=${days}&limit=${limit}`);
  }

  getTripAnalytics(
    period: TripStatsPeriod,
    opts?: { fromDate?: string; toDate?: string; stationId?: number | null; partnerId?: number | null },
  ): Observable<AdminTripStats> {
    let params = new HttpParams().set('period', period);
    if (opts?.fromDate) {
      params = params.set('fromDate', opts.fromDate);
    }
    if (opts?.toDate) {
      params = params.set('toDate', opts.toDate);
    }
    if (opts?.stationId != null) {
      params = params.set('stationId', String(opts.stationId));
    }
    if (opts?.partnerId != null) {
      params = params.set('partnerId', String(opts.partnerId));
    }
    return this.http.get<AdminTripStats>('/admin/stats/trip-analytics', { params });
  }

  getStationOptions(): Observable<AdminStationOption[]> {
    return this.http.get<AdminStationOption[]>('/admin/stats/stations');
  }

  /**
   * Récupère la liste complète des utilisateurs
   */
  getAllUsers(): Observable<UserAdmin[]> {
    return this.http.get<UserAdmin[]>('/admin/users');
  }

  /**
   * Active ou désactive un compte utilisateur (Bannissement)
   */
  toggleUserStatus(id: number, enabled: boolean): Observable<void> {
    return this.http.patch<void>(`/admin/users/${id}/status?enabled=${enabled}`, {});
  }

  /**
   * Rattache un chauffeur / salarié à une compagnie (hors pool covo.). {@code null} = retirer.
   */
  setUserEmployerPartner(userId: number, partnerId: number | null): Observable<UserAdmin> {
    let params = new HttpParams();
    if (partnerId != null) {
      params = params.set('partnerId', String(partnerId));
    }
    return this.http.patch<UserAdmin>(`/admin/users/${userId}/employer-partner`, {}, { params });
  }

  /**
   * Approuve un partenaire en attente : passe `approvalStatus` à APPROVED et active le
   * compte. Distinct de `togglePartnerStatus` (qui ne fait que basculer `enabled`, sans
   * jamais toucher `approvalStatus` — utiliser `toggle` uniquement pour suspendre/réactiver
   * un partenaire déjà approuvé).
   */
  approvePartner(id: number): Observable<void> {
    return this.http.patch<void>(`/admin/partners/${id}/approve`, {});
  }

  /** Rejette un partenaire en attente — motif obligatoire côté backend. */
  rejectPartner(id: number, reason: string): Observable<void> {
    return this.http.patch<void>(`/admin/partners/${id}/reject`, { reason });
  }

  /**
   * Active ou désactive un partenaire (Droit de publication) — suspendre/réactiver un
   * partenaire déjà approuvé. Ne touche jamais `approvalStatus` : pour approuver un
   * partenaire en attente, utiliser `approvePartner`.
   */
  togglePartnerStatus(id: number): Observable<void> {
    return this.http.patch<void>(`/admin/partners/${id}/toggle`, {});
  }

  getAllPartnersForAdmin(): Observable<Partner[]> {
    return this.http.get<Partner[]>('/admin/partners');
  }

  getCovoiturageSoloDrivers(): Observable<CovoiturageSoloDriverAdminItem[]> {
    return this.http.get<CovoiturageSoloDriverAdminItem[]>('/admin/covoiturage-solo-drivers');
  }

  // Pour l'admin : Activer/Désactiver
  toggleStatus(id: number): Observable<void> {
    return this.http.patch<void>(`/admin/partners/${id}/toggle`, {});
  }

  private dateRangeParams(fromDate?: string, toDate?: string, search?: string): HttpParams {
    let params = new HttpParams();
    if (fromDate) params = params.set('fromDate', fromDate);
    if (toDate) params = params.set('toDate', toDate);
    if (search) params = params.set('search', search);
    return params;
  }

  /** Sans fromDate/toDate, le backend retombe sur les 30 derniers jours. */
  getTripList(fromDate?: string, toDate?: string, search?: string): Observable<AdminTripListItem[]> {
    return this.http.get<AdminTripListItem[]>('/admin/stats/trips/list', {
      params: this.dateRangeParams(fromDate, toDate, search),
    });
  }

  getTicketList(fromDate?: string, toDate?: string, search?: string): Observable<AdminTicketListItem[]> {
    return this.http.get<AdminTicketListItem[]>('/admin/stats/tickets/list', {
      params: this.dateRangeParams(fromDate, toDate, search),
    });
  }

  getBookingList(fromDate?: string, toDate?: string, search?: string): Observable<AdminBookingListItem[]> {
    return this.http.get<AdminBookingListItem[]>('/admin/stats/bookings/list', {
      params: this.dateRangeParams(fromDate, toDate, search),
    });
  }

  /** Frais Mobili, commission prélevée et net compagnie, par réservation payée. */
  getTransactionList(fromDate?: string, toDate?: string, search?: string): Observable<AdminTransaction[]> {
    return this.http.get<AdminTransaction[]>('/admin/stats/transactions/list', {
      params: this.dateRangeParams(fromDate, toDate, search),
    });
  }

  /**
   * Envoie une annonce vers la boîte de réception des comptes dirigeants (propriétaire partenaire).
   */
  sendPartnerCommunication(
    payload: AdminPartnerCommunicationPayload,
  ): Observable<AdminPartnerCommunicationResult> {
    return this.http.post<AdminPartnerCommunicationResult>('/admin/partner-communications', payload);
  }

  /**
   * Rattrapage ponctuel : génère les tickets manquants pour toute vente guichet (OFFLINE_SALE)
   * enregistrée avant le correctif de BookingService.createOfflineSale() (aucun ticket n'était
   * généré). Idempotent — ne retraite jamais une réservation qui a déjà un ticket.
   */
  backfillOfflineSaleTickets(): Observable<{ bookingsFixed: number }> {
    return this.http.post<{ bookingsFixed: number }>('/admin/bookings/backfill-offline-sale-tickets', {});
  }

  /** Rattrapage ponctuel (incident 2026-09-02) : retire le forfait de service client des ventes
   *  guichet créées avant le correctif (BookingService.createOfflineSale). Idempotent. */
  backfillOfflineSaleServiceFee(): Observable<{ bookingsFixed: number }> {
    return this.http.post<{ bookingsFixed: number }>('/admin/bookings/backfill-offline-sale-service-fee', {});
  }

  /** Rattrapage ponctuel : calcule la commission des tickets créés avant l'introduction de
   *  CompanyCommissionService (ancien flux sans décomposition tarifaire). Idempotent. */
  backfillMissingTicketCommission(): Observable<{ ticketsFixed: number }> {
    return this.http.post<{ ticketsFixed: number }>('/admin/bookings/backfill-missing-ticket-commission', {});
  }
}
