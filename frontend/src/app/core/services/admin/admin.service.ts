import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { Partner } from '../partners/partenaire.service';

export interface AdminStats {
  totalUsers: number;
  totalPartners: number;
  totalTrips: number;
  activeBookings: number;
  totalRevenue: number;
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
}

export interface AnalyticsRecentEvent {
  id: number;
  occurredAt: string;
  eventType: string;
  detail: string;
}

export type TripStatsPeriod = 'DAY' | 'WEEK' | 'MONTH';

export interface TripStatEntry {
  rank: number;
  tripId: number;
  route: string;
  partnerName: string;
  bookingCount: number;
  revenueFcfa: number;
}

export interface RevenueDonutSlice {
  label: string;
  revenueFcfa: number;
  percentOfTotal: number;
}

export interface VolumeDonutSlice {
  label: string;
  bookingCount: number;
  percentOfTotal: number;
}

/** Aligné sur le record Java AdminTripStatsResponse (sérialisation JSON). */
export interface AdminTripStats {
  period: TripStatsPeriod;
  fromInclusive: string;
  toExclusive: string;
  totalBookings: number;
  totalRevenueFcfa: number;
  activeTripCount: number;
  avgRevenuePerBooking: number;
  top10ByBookings: TripStatEntry[];
  top10ByRevenue: TripStatEntry[];
  revenueByTripDonut: RevenueDonutSlice[];
  volumeByTripDonut: VolumeDonutSlice[];
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

  getAnalyticsSummary(days = 7): Observable<AnalyticsSummary> {
    return this.http.get<AnalyticsSummary>(`/admin/analytics/summary?days=${days}`);
  }

  getRecentAnalyticsEvents(limit = 50): Observable<AnalyticsRecentEvent[]> {
    return this.http.get<AnalyticsRecentEvent[]>(`/admin/analytics/recent-events?limit=${limit}`);
  }

  getTripAnalytics(period: TripStatsPeriod): Observable<AdminTripStats> {
    return this.http.get<AdminTripStats>(`/admin/stats/trip-analytics?period=${period}`);
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
   * Active ou désactive un partenaire (Droit de publication)
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

  /**
   * Envoie une annonce vers la boîte de réception des comptes dirigeants (propriétaire partenaire).
   */
  sendPartnerCommunication(
    payload: AdminPartnerCommunicationPayload,
  ): Observable<AdminPartnerCommunicationResult> {
    return this.http.post<AdminPartnerCommunicationResult>('/admin/partner-communications', payload);
  }
}
