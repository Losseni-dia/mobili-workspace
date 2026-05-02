import { inject, Injectable, signal, computed } from '@angular/core';
import { HttpClient, HttpContext } from '@angular/common/http';
import { Observable, tap, switchMap, map, of, throwError, catchError, finalize } from 'rxjs';

import { skipAuthRefreshRetry } from '../../http/auth-refresh.context';
import { ConfigurationService } from '../../../configurations/services/configuration.service';

export interface AuthResponse {
  token: string;
  login: string;
  id: number; // Aligné avec ProfileDTO Java
  firstname: string; // Aligné avec ProfileDTO Java
  lastname: string; // Aligné avec ProfileDTO Java
  email: string;
  avatarUrl: string; // Aligné avec ProfileDTO Java
  roles: string[];
  partnerId?: number;
  /** Compte responsable gare */
  stationId?: number;
  stationName?: string;
  /**
   * Rôle GARE : la gare est validée par le dirigeant (booléen côté API) et active.
   * Faux = aucune action trajet / scanner jusqu’à validation.
   */
  gareOperationsEnabled?: boolean | null;
  /** Chauffeur covoiturage : NONE | PENDING | APPROVED | REJECTED */
  covoiturageKycStatus?: string | null;
  /** Fin de validité CNI (yyyy-MM-dd) */
  covoiturageIdValidUntil?: string | null;
  covoiturageVehicleBrand?: string | null;
  covoiturageVehiclePlate?: string | null;
  covoiturageVehicleColor?: string | null;
  covoiturageGreyCardNumber?: string | null;
  covoiturageVehiclePhotoUrl?: string | null;
  covoiturageDriverPhotoUrl?: string | null;
  covoiturageKycDaysUntilExpiry?: number | null;
  covoiturageKycExpiringWithin30Days?: boolean | null;
  covoiturageKycIsDocumentExpired?: boolean | null;
  /** Compte inscrit comme chauffeur covoiturage « solo » (hors compagnie). */
  covoiturageSoloProfile?: boolean | null;
}

export interface UserAdmin {
  id: number;
  firstname: string;
  lastname: string;
  email: string;
  roles: any[]; // On peut mettre string[] ou any[] selon si le backend envoie des objets Role ou juste des noms
  enabled: boolean;
}

type RoleLike = string | { name?: string };

/** Corps `company` pour `POST /auth/register-company` (aligné sur le DTO Java). */
export interface RegisterCompanyPublicPayload {
  firstname: string;
  lastname: string;
  login: string;
  email: string;
  password: string;
  companyName: string;
  companyEmail: string;
  companyPhone: string;
  businessNumber?: string;
}

export interface GarePreviewStation {
  id: number;
  name: string;
  city: string;
}

export interface GarePreviewResponse {
  partnerName: string;
  partnerId: number;
  stations: GarePreviewStation[];
}

export interface GareSelfRegisterRequest {
  partnerCode: string;
  stationId?: number | null;
  newStationName?: string;
  newStationCity?: string;
  login: string;
  email: string;
  password: string;
  firstname: string;
  lastname: string;
}

/** Corps minimal renvoyé par l’API à l’inscription (aligné sur login). */
type BackendAuthResponse = { token: string; login: string; userId: number; id?: number };

/** Résultat d’inscription gare (compte actif connecté, ou inactif en attente du partenaire). */
export type GareRegisterOutcome =
  | { status: 'activated'; user: AuthResponse }
  | { status: 'awaiting_approval'; login: string; userId: number };

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private config = inject(ConfigurationService);

  /** URL pour les images (ne passe pas par l’intercepteur) — alignée sur `apiUrl`. */
  public get IMAGE_BASE_URL(): string {
    return this.config.getUploadBaseUrl();
  }

  currentUser = signal<AuthResponse | null>(this.getUserFromStorage());
  isLoggedIn = computed(() => !!this.currentUser());

  /**
   * Après un login sur l’appli « voyageurs », l’ouverture de « business » (autre port)
   * n’a pas de JWT en localStorage — on déduit la session via le cookie httpOnly sur l’API.
   */
  /**
   * Appelé par l’intercepteur quand l’API répond 401 (JWT expiré) : renouvelle l’accès
   * via le cookie httpOnly, sans se ré-enfiler dans la logique de retry.
   */
  refreshAccessTokenFromCookie(): Observable<boolean> {
    return this.http
      .post<BackendAuthResponse>('/auth/refresh', {}, { context: new HttpContext().set(skipAuthRefreshRetry, true) })
      .pipe(
        tap((r) => {
          const cur = this.getUserFromStorage() || ({} as Partial<AuthResponse>);
          this.saveUser({
            ...cur,
            token: r.token,
            login: r.login,
            id: r.userId,
          } as AuthResponse);
        }),
        map(() => true),
        catchError(() => of(false)),
      );
  }

  hydrateFromRefresh(): Observable<void> {
    if (this.getUserFromStorage()) {
      this.currentUser.set(this.getUserFromStorage());
      return of(void 0);
    }
    return this.http.post<BackendAuthResponse>('/auth/refresh', {}).pipe(
      switchMap((r) => {
        this.saveUser({
          token: r.token,
          login: r.login,
          id: r.userId,
          firstname: '',
          lastname: '',
          email: '',
          avatarUrl: '',
          roles: [],
        } as AuthResponse);
        return this.fetchUserProfile().pipe(map(() => void 0));
      }),
      catchError(() => of(void 0)),
    );
  }

  /**
   * Récupère les détails complets de l'utilisateur.
   * L'intercepteur ajoutera le préfixe /v1 automatique.
   */
  fetchUserProfile(): Observable<AuthResponse> {
    // 💡 Plus besoin de passer le login en paramètre !
    return this.http.get<AuthResponse>(`/auth/me`).pipe(
      tap((fullProfile) => {
        const currentData = this.getUserFromStorage();
        // Crucial : On garde le token du login original car le /me ne le renvoie pas
        const updatedUser = { ...fullProfile, token: currentData?.token || '' };

        this.saveUser(updatedUser);
      }),
    );
  }

  login(credentials: any): Observable<AuthResponse> {
    return this.http.post<BackendAuthResponse>('/auth/login', credentials).pipe(
      switchMap((authData) => {
        this.saveUser(this.mapLoginBodyToAuthResponse(authData));
        return this.fetchUserProfile();
      }),
    );
  }

  logout() {
    this.http.post('/auth/logout', {}).pipe(
      finalize(() => {
        localStorage.removeItem('mobili_user');
        this.currentUser.set(null);
      }),
    ).subscribe();
  }

  private mapLoginBodyToAuthResponse(r: BackendAuthResponse): AuthResponse {
    return {
      token: r.token,
      login: r.login,
      id: r.userId,
      firstname: '',
      lastname: '',
      email: '',
      avatarUrl: '',
      roles: [],
    } as AuthResponse;
  }

  private saveUser(user: AuthResponse) {
    localStorage.setItem('mobili_user', JSON.stringify(user));
    this.currentUser.set(user);
  }

  private getUserFromStorage(): AuthResponse | null {
    const data = localStorage.getItem('mobili_user');
    if (!data) return null;
    try {
      return JSON.parse(data) as AuthResponse;
    } catch {
      localStorage.removeItem('mobili_user');
      return null;
    }
  }

  register(user: any, avatar?: File): Observable<any> {
    const formData = new FormData();
    const userBlob = new Blob([JSON.stringify(user)], { type: 'application/json' });
    formData.append('user', userBlob);
    if (avatar) formData.append('avatar', avatar);

    return this.http.post('/auth/register', formData);
  }

  /**
   * Inscription compagnie (dirigeant) + fiche société, session ouverte comme après login.
   */
  registerCompany(payload: RegisterCompanyPublicPayload, logo?: File | null): Observable<AuthResponse> {
    const formData = new FormData();
    formData.append('company', new Blob([JSON.stringify(payload)], { type: 'application/json' }));
    if (logo) {
      formData.append('logo', logo);
    }
    return this.http.post<BackendAuthResponse>('/auth/register-company', formData).pipe(
      switchMap((authData) => {
        this.saveUser(this.mapLoginBodyToAuthResponse(authData));
        return this.fetchUserProfile();
      }),
    );
  }

  /**
   * Inscription chauffeur covoiturage (CNI, photo conducteur, véhicule, date de fin de validité CNI).
   * `idValidUntil` en ISO date (yyyy-MM-dd).
   */
  registerCarpoolChauffeur(
    body: {
      firstname: string;
      lastname: string;
      login: string;
      email: string;
      password: string;
      idValidUntil: string;
      vehicleBrand: string;
      vehiclePlate: string;
      vehicleColor: string;
      greyCardNumber: string;
    },
    idFront: File,
    idBack: File,
    driverPhoto: File,
    vehiclePhoto: File,
  ): Observable<unknown> {
    const formData = new FormData();
    formData.append('user', new Blob([JSON.stringify(body)], { type: 'application/json' }));
    formData.append('idFront', idFront);
    formData.append('idBack', idBack);
    formData.append('driverPhoto', driverPhoto);
    formData.append('vehiclePhoto', vehiclePhoto);
    return this.http.post('/auth/register-carpool-chauffeur', formData);
  }

  /** Aperçu compagnie + gares pour auto-inscription responsable (code partenaire). */
  previewGareRegistration(code: string): Observable<GarePreviewResponse> {
    const q = encodeURIComponent(code.trim().toUpperCase());
    return this.http.get<GarePreviewResponse>(`/auth/registration/gare/preview?code=${q}`);
  }

  /**
   * Inscription gare : compte actif (connexion) ou
   * `awaiting_approval` si le partenaire doit valider la gare (compte inactif, pas de token).
   */
  registerGare(req: GareSelfRegisterRequest): Observable<GareRegisterOutcome> {
    return this.http
      .post<{
        token: string | null;
        login: string;
        userId: number;
        id?: number;
        accountPending?: boolean | null;
      }>('/auth/registration/gare', req)
      .pipe(
        switchMap((r) => {
          const id = (r as { id?: number }).id ?? r.userId;
          if (r.accountPending) {
            return of({ status: 'awaiting_approval' as const, login: r.login, userId: id });
          }
          if (r.token == null || id == null) {
            return throwError(
              () => new Error("Réponse d'inscription gare inattendue (token ou identifiant manquant)."),
            );
          }
          const base: AuthResponse = {
            token: r.token,
            login: r.login,
            id,
            firstname: '',
            lastname: '',
            email: '',
            avatarUrl: '',
            roles: [],
          };
          this.saveUser(base);
          return this.fetchUserProfile().pipe(
            map((u) => ({ status: 'activated' as const, user: u })),
          );
        }),
      );
  }

  // Dans auth.service.ts

  // auth.service.ts

  hasRole(roleName: string): boolean {
    const user = this.currentUser();
    if (!user || !user.roles) return false;

    const cleanRoleName = roleName.replace(/^ROLE_/, '').toUpperCase();
    const accepted = new Set([cleanRoleName, `ROLE_${cleanRoleName}`]);
    return (user.roles as RoleLike[]).some((role) => {
      const roleValue = typeof role === 'string' ? role : role?.name;
      if (!roleValue) return false;
      return accepted.has(roleValue.toUpperCase());
    });
  }

  /**
   * Met à jour le profil de l'utilisateur (Infos + Avatar)
   */
  updateProfile(userId: number, formData: FormData): Observable<AuthResponse> {
    // 💡 L'intercepteur ajoutera /v1/users/${userId}
    return this.http.put<AuthResponse>(`/users/${userId}`, formData).pipe(
      tap(() => {
        // Une fois mis à jour, on rafraîchit les signaux globaux
        this.fetchUserProfile().subscribe();
      }),
    );
  }

 
}
