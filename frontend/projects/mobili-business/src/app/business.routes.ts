import { Routes } from '@angular/router';
import { authGuard } from '@mobili-app/core/guard/auth.guard';
import { covoiturageSoloGuard } from '@mobili-app/core/guard/covoiturage-solo.guard';
import { gareOperationsGuard } from '@mobili-app/core/guard/gare-operations.guard';
import { partnerOperationsGuard } from '@mobili-app/core/guard/partner-operations.guard';

/**
 * Portail partenaire + gare + covoiturage solo. Même `features` que l’appli racine, chemins stables.
 */
export const businessRoutes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'auth/portail' },

  {
    path: 'auth/portail',
    loadComponent: () =>
      import('@mobili-app/features/auth/business-portal/business-portal.component').then(
        (m) => m.BusinessPortalComponent,
      ),
  },
  {
    path: 'auth/inscription-business',
    loadComponent: () =>
      import(
        '@mobili-app/features/auth/business-registration-hub/business-registration-hub.component'
      ).then((m) => m.BusinessRegistrationHubComponent),
  },
  {
    path: 'auth/login',
    loadComponent: () =>
      import('@mobili-app/features/auth/login/login.component').then((m) => m.LoginComponent),
  },
  { path: 'auth/inscription', redirectTo: 'auth/portail', pathMatch: 'full' },
  { path: 'auth/register', redirectTo: 'auth/inscription-business', pathMatch: 'full' },
  {
    path: 'auth/register-partner',
    loadComponent: () =>
      import('@mobili-app/features/auth/register-partner/register-partner.component').then(
        (m) => m.RegisterPartnerComponent,
      ),
  },
  {
    path: 'auth/register-gare',
    loadComponent: () =>
      import('@mobili-app/features/auth/traveler-shell-redirect/traveler-route-redirect.component').then(
        (m) => m.TravelerRouteRedirectComponent,
      ),
    data: { travelerPath: '/auth/register-gare' },
  },
  {
    path: 'auth/register-carpool-chauffeur',
    loadComponent: () =>
      import('@mobili-app/features/auth/traveler-shell-redirect/traveler-route-redirect.component').then(
        (m) => m.TravelerRouteRedirectComponent,
      ),
    data: { travelerPath: '/auth/register-carpool-chauffeur' },
  },

  {
    path: 'partenaire/register',
    redirectTo: 'auth/register-partner',
    pathMatch: 'full',
  },
  {
    path: 'partenaire',
    canActivate: [authGuard],
    loadComponent: () =>
      import('@mobili-app/features/partenaire/partner-shell/partner-shell.component').then(
        (m) => m.PartnerShellComponent,
      ),
    children: [
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
      {
        path: 'dashboard',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/partenaire/dashboard/dashboard.component').then(
            (m) => m.DashboardComponent,
          ),
      },
      {
        path: 'gares',
        loadComponent: () =>
          import('@mobili-app/features/partenaire/station-list/station-list.component').then(
            (m) => m.StationListComponent,
          ),
      },
      {
        path: 'chauffeurs',
        loadComponent: () =>
          import('@mobili-app/features/partenaire/chauffeur-list/chauffeur-list.component').then(
            (m) => m.ChauffeurListComponent,
          ),
      },
      {
        path: 'company-messages',
        loadComponent: () =>
          import('@mobili-app/features/shared/company-messages/company-messages.component').then(
            (m) => m.CompanyMessagesComponent,
          ),
      },
      {
        path: 'settings',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/partenaire/partner-edit/partner-edit.component').then(
            (m) => m.PartnerEditComponent,
          ),
      },
      {
        path: 'trips',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/partenaire/trip-management/trip-management.component').then(
            (m) => m.TripManagementComponent,
          ),
      },
      {
        path: 'add-trip',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/partenaire/trip-management/trip-add/add-trip.component').then(
            (m) => m.AddTripComponent,
          ),
      },
      {
        path: 'edit-trip/:id',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/partenaire/trip-management/trip-edit/trip-edit.component').then(
            (m) => m.TripEditComponent,
          ),
      },
      {
        path: 'bookings',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/partenaire/my-customers-bookings/booking-list.component').then(
            (m) => m.BookingListComponent,
          ),
      },
      {
        path: 'notifications',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/notifications/inbox-page/inbox-page.component').then(
            (m) => m.InboxPageComponent,
          ),
      },
      {
        path: 'trip-channel/:tripId',
        canActivate: [partnerOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/notifications/trip-channel-page/trip-channel-page.component').then(
            (m) => m.TripChannelPageComponent,
          ),
      },
    ],
  },

  {
    path: 'gare',
    canActivate: [authGuard],
    loadComponent: () =>
      import('@mobili-app/features/gare/gare-shell/gare-shell.component').then(
        (m) => m.GareShellComponent,
      ),
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'accueil' },
      {
        path: 'accueil',
        loadComponent: () =>
          import('@mobili-app/features/gare/gare-home/gare-home.component').then(
            (m) => m.GareHomeComponent,
          ),
      },
      {
        path: 'company-messages',
        loadComponent: () =>
          import('@mobili-app/features/shared/company-messages/company-messages.component').then(
            (m) => m.CompanyMessagesComponent,
          ),
      },
      {
        path: 'scan',
        canActivate: [gareOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/gare/scanner/scanner.component').then(
            (m) => m.TicketScannerComponent,
          ),
      },
      {
        path: 'profil',
        canActivate: [gareOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/gare/gare-home/gare-profile/gare-profile.component').then(
            (m) => m.GareProfileComponent,
          ),
      },
      {
        path: 'compte',
        canActivate: [gareOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/user/profile/user-edit/user-edit.component').then(
            (m) => m.UserEditComponent,
          ),
      },
      {
        path: 'notifications',
        canActivate: [gareOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/notifications/inbox-page/inbox-page.component').then(
            (m) => m.InboxPageComponent,
          ),
      },
      {
        path: 'trip-channel/:tripId',
        canActivate: [gareOperationsGuard],
        loadComponent: () =>
          import('@mobili-app/features/notifications/trip-channel-page/trip-channel-page.component').then(
            (m) => m.TripChannelPageComponent,
          ),
      },
    ],
  },

  {
    path: 'covoiturage',
    canActivate: [covoiturageSoloGuard],
    loadComponent: () =>
      import('@mobili-app/features/covoiturage/covoiturage-shell/covoiturage-shell.component').then(
        (m) => m.CovoiturageShellComponent,
      ),
    children: [
      { path: '', redirectTo: 'accueil', pathMatch: 'full' },
      {
        path: 'accueil',
        loadComponent: () =>
          import('@mobili-app/features/covoiturage/covoiturage-home/covoiturage-home.component').then(
            (m) => m.CovoiturageHomeComponent,
          ),
      },
      {
        path: 'publier',
        loadComponent: () =>
          import('@mobili-app/features/covoiturage/covoiturage-publish/covoiturage-publish.component').then(
            (m) => m.CovoituragePublishComponent,
          ),
      },
      {
        path: 'piloter',
        loadComponent: () =>
          import('@mobili-app/features/chauffeur/driver-console/driver-console.component').then(
            (m) => m.DriverConsoleComponent,
          ),
      },
      {
        path: 'scan',
        loadComponent: () =>
          import('@mobili-app/features/gare/scanner/scanner.component').then((m) => m.TicketScannerComponent),
      },
      {
        path: 'notifications',
        loadComponent: () =>
          import('@mobili-app/features/notifications/inbox-page/inbox-page.component').then((m) => m.InboxPageComponent),
      },
    ],
  },

  { path: '**', redirectTo: 'auth/portail' },
];
