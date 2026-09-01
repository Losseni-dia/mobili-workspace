import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import { ConfigurationService } from '../../../configurations/services/configuration.service';

export interface Partner {
  // 💡 N'oublie pas le "export" ici !
  id: number;
  name: string;
  email: string;
  phone: string;
  businessNumber: string;
  logoUrl: string;
  enabled: boolean;
  /** Code unique pour l’auto-inscription des responsables gare (API / partenaire). */
  registrationCode?: string | null;
  /**
   * Partenaire technique Mobili (pool covoiturage particulier), distinct d’une compagnie transport.
   * Renseigné sur les réponses admin.
   */
  covoiturageSoloPool?: boolean;
  /** PENDING / APPROVED / REJECTED — renseigné sur les réponses admin (GET /admin/partners). */
  approvalStatus?: string;
  /** Motif de rejet le plus récent, renseigné uniquement si approvalStatus = REJECTED. */
  rejectionReason?: string | null;
}

export interface PartnerDashboard {
  activeTripsCount: number;
  totalBookingsCount: number;
  totalRevenue: number;
  /** Revenu réalisé via paiement en ligne (CONFIRMED) — champ backend déjà renvoyé, jamais mappé côté web avant ce chantier. */
  revenueOnline?: number;
  /** Revenu réalisé au guichet (OFFLINE_SALE) — idem. */
  revenueOffline?: number;
  /** Tickets vendus (actifs, hors ANNULÉ) depuis toujours, par canal. */
  ticketsSoldOnline?: number;
  ticketsSoldOffline?: number;
  recentBookings: {
    id: number;
    customerName: string;
    tripRoute: string;
    date: string;
    amount: number;
    status: string;
  }[];
}

export interface PartnerChauffeurItem {
  id: number;
  firstname: string | null;
  lastname: string | null;
  email: string | null;
  phone: string | null;
  enabled: boolean;
  affiliationStationId: number | null;
  affiliationStationName: string | null;
}

/** Compte utilisateur rattaché à une gare (GareUserController). */
export interface GareUserItem {
  id: number;
  firstname: string | null;
  lastname: string | null;
  email: string | null;
  phone: string | null;
  login: string;
  enabled: boolean;
  stationId: number;
  stationName: string | null;
}

export interface StationChauffeurSummary {
  id: number;
  firstname: string | null;
  lastname: string | null;
}

export interface Station {
  id: number;
  name: string;
  city: string;
  code?: string | null;
  active: boolean;
  partnerId: number;
  /** PENDING | APPROVED (absent = rétrocompat, traité comme APPROVED) */
  approvalStatus?: string | null;
  /**
   * Faux à la création, vrai seulement après validation par le dirigeant.
   * Si absent, se fier à {@link approvalStatus} + {@link active}.
   */
  validated?: boolean | null;
  /** Premier compte gare (nom affichage) */
  responsibleName?: string | null;
  /** Chauffeurs société affectés à cette gare */
  assignedChauffeurs?: StationChauffeurSummary[];
}

/** Gare autorisée pour trajets, scanner, etc. (aligné sur le backend) */
export function isStationReadyForTrips(s: Station): boolean {
  if (s.validated === false) {
    return false;
  }
  if (s.validated === true) {
    return s.active;
  }
  if (s.approvalStatus === 'PENDING') {
    return false;
  }
  return s.active;
}

@Injectable({ providedIn: 'root' })
export class PartenaireService {
  private http = inject(HttpClient);
  private readonly config = inject(ConfigurationService);

  public get IMAGE_BASE_URL(): string {
    return this.config.getUploadBaseUrl();
  }

  // Inscription du partenaire (Utilise /partners car l'intercepteur gère le /v1)
  registerPartner(formData: FormData): Observable<any> {
    return this.http.post('/partners', formData);
  }

  // Récupérer les infos de sa propre société
  getPartners(id: number): Observable<any> {
    return this.http.get(`/partners/${id}`);
  }

  getPartner(id: number): Observable<Partner> {
    return this.http.get<Partner>(`/partners/${id}`);
  }

  // partenaire.service.ts
  getMyPartnerInfo(): Observable<Partner> {
    return this.http.get<Partner>(`/partners/my-company`);
  }

  // On utilise l'ID pour le PUT, et FormData pour le logo
  updatePartner(id: number, formData: FormData): Observable<Partner> {
    return this.http.put<Partner>(`/partners/${id}`, formData);
  }

  getDashboardStats(stationId?: number | null): Observable<PartnerDashboard> {
    let params = new HttpParams();
    if (stationId != null && stationId > 0) {
      params = params.set('stationId', String(stationId));
    }
    return this.http.get<PartnerDashboard>('/partenaire/dashboard/stats', { params });
  }

  listStations(): Observable<Station[]> {
    return this.http.get<Station[]>('/partenaire/stations');
  }

  listChauffeurs(): Observable<PartnerChauffeurItem[]> {
    return this.http.get<PartnerChauffeurItem[]>('/partenaire/chauffeurs');
  }

  /**
   * Le backend attend un `multipart/form-data` avec une part JSON nommée "chauffeur" (+ "avatar"
   * optionnelle) — @RequestPart, pas un simple body JSON (PartnerChauffeurController.create).
   */
  /**
   * idFront/idBack/licenseFront/licenseBack obligatoires côté backend (@RequestPart sans
   * required=false) — CNI + permis, aucun document n'était collecté avant.
   */
  createChauffeur(
    body: {
      firstname: string;
      lastname: string;
      email: string;
      phone: string;
      login: string;
      password: string;
      stationId: number | null;
    },
    idFront: File,
    idBack: File,
    licenseFront: File,
    licenseBack: File,
    avatar?: File | null,
  ): Observable<PartnerChauffeurItem> {
    const form = new FormData();
    form.append('chauffeur', new Blob([JSON.stringify(body)], { type: 'application/json' }));
    form.append('idFront', idFront);
    form.append('idBack', idBack);
    form.append('licenseFront', licenseFront);
    form.append('licenseBack', licenseBack);
    if (avatar) {
      form.append('avatar', avatar);
    }
    return this.http.post<PartnerChauffeurItem>('/partenaire/chauffeurs', form);
  }

  /** Même contrat multipart que la création (PartnerChauffeurController.update). */
  updateChauffeur(
    userId: number,
    body: { firstname: string; lastname: string; phone?: string; email?: string; password?: string },
    avatar?: File | null,
  ): Observable<PartnerChauffeurItem> {
    const form = new FormData();
    form.append('chauffeur', new Blob([JSON.stringify(body)], { type: 'application/json' }));
    if (avatar) {
      form.append('avatar', avatar);
    }
    return this.http.put<PartnerChauffeurItem>(`/partenaire/chauffeurs/${userId}`, form);
  }

  reactivateChauffeur(userId: number): Observable<PartnerChauffeurItem> {
    return this.http.patch<PartnerChauffeurItem>(`/partenaire/chauffeurs/${userId}/reactivate`, {});
  }

  deleteChauffeur(userId: number): Observable<void> {
    return this.http.delete<void>(`/partenaire/chauffeurs/${userId}`);
  }

  patchChauffeurAffiliation(
    userId: number,
    body: { stationId: number | null },
  ): Observable<PartnerChauffeurItem> {
    return this.http.patch<PartnerChauffeurItem>(`/partenaire/chauffeurs/${userId}/affiliation`, body);
  }

  /** `password` optionnel (min. 6) — aligné sur `_StationFormSheet` (mobile) : compte connexion "gare legacy". */
  createStation(body: { name: string; city: string; active?: boolean; password?: string }): Observable<Station> {
    return this.http.post<Station>('/partenaire/stations', body);
  }

  updateStation(
    id: number,
    body: { name: string; city: string; active?: boolean; password?: string },
  ): Observable<Station> {
    return this.http.put<Station>(`/partenaire/stations/${id}`, body);
  }

  approveStation(id: number): Observable<Station> {
    return this.http.post<Station>(`/partenaire/stations/${id}/approve`, {});
  }

  deleteStation(id: number): Observable<void> {
    return this.http.delete<void>(`/partenaire/stations/${id}`);
  }

  /**
   * `phone` obligatoire côté backend (GareUserCreateRequest @NotBlank) — absent des versions
   * précédentes de cette méthode, jamais consommée par aucune page (même bug de contrat que la
   * création de chauffeur avant correction).
   */
  createGareAccount(body: {
    stationId: number;
    login: string;
    phone: string;
    email?: string;
    password: string;
    firstname: string;
    lastname: string;
  }): Observable<void> {
    return this.http.post<void>('/partenaire/stations/gare-accounts', body);
  }

  listGareUsers(): Observable<GareUserItem[]> {
    return this.http.get<GareUserItem[]>('/partenaire/gare-users');
  }

  updateGareUser(
    id: number,
    body: { firstname: string; lastname: string; email?: string; phone?: string; password?: string },
  ): Observable<GareUserItem> {
    return this.http.put<GareUserItem>(`/partenaire/gare-users/${id}`, body);
  }

  updateGareUserAffiliation(id: number, stationId: number): Observable<GareUserItem> {
    return this.http.patch<GareUserItem>(`/partenaire/gare-users/${id}/affiliation`, { stationId });
  }

  reactivateGareUser(id: number): Observable<GareUserItem> {
    return this.http.patch<GareUserItem>(`/partenaire/gare-users/${id}/reactivate`, {});
  }

  /** Archivage logique (204, pas de suppression réelle). */
  archiveGareUser(id: number): Observable<void> {
    return this.http.delete<void>(`/partenaire/gare-users/${id}`);
  }
}
