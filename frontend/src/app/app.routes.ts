import { Routes } from '@angular/router';
import { authGuard } from './core/guard/auth.guard';
import { adminGuard } from './core/guard/admin.guard';
import { chauffeurGuard } from './core/guard/chauffeur.guard';
import { AdminDashboard } from './features/admin/admin-dashboard/admin-dashboard';
import { AdminPartners } from './features/admin/admin-partners/admin-partners';
import { AdminUsers } from './features/admin/admin-users/admin-users';

export const routes: Routes = [
  // ============ ROUTES PUBLIQUES ============
  {
    path: '',
    loadComponent: () =>
      import('./features/public/home/home.component').then((m) => m.HomeComponent),
  },
  {
    path: 'search-results',
    loadComponent: () =>
      import('./features/public/search-results/search-results.component').then(
        (m) => m.SearchResultsComponent,
      ),
  },
  {
    path: 'auth/login',
    loadComponent: () =>
      import('./features/auth/login/login.component').then((m) => m.LoginComponent),
  },
  {
    path: 'auth/inscription',
    loadComponent: () =>
      import('./features/auth/register/register.component').then((m) => m.RegisterComponent),
  },
  {
    path: 'auth/register',
    loadComponent: () =>
      import('./features/auth/register/register.component').then((m) => m.RegisterComponent),
  },
  {
    path: 'auth/register-gare',
    loadComponent: () =>
      import('./features/auth/register-gare/register-gare.component').then(
        (m) => m.RegisterGareComponent,
      ),
  },
  {
    path: 'auth/register-carpool-chauffeur',
    loadComponent: () =>
      import('./features/auth/register-carpool-chauffeur/register-carpool-chauffeur.component').then(
        (m) => m.RegisterCarpoolChauffeurComponent,
      ),
  },

  // ============ ESPACE VOYAGEUR (shell custom) ============
  {
    path: 'my-account',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./features/user/user-shell/user-shell.component').then((m) => m.UserShellComponent),
    children: [
      { path: '', redirectTo: 'profile', pathMatch: 'full' },
      {
        path: 'profile',
        loadComponent: () =>
          import('./features/user/profile/profile.component').then((m) => m.ProfileComponent),
      },
      {
        path: 'profile-edit',
        loadComponent: () =>
          import('./features/user/profile/user-edit/user-edit.component').then(
            (m) => m.UserEditComponent,
          ),
      },
      {
        path: 'bookings',
        loadComponent: () =>
          import('./features/user/my-bookings/my-bookings.component').then(
            (m) => m.MyBookingsComponent,
          ),
      },
      {
        path: 'my-tickets',
        loadComponent: () =>
          import('./features/bookings/my-tickets/my-tickets.component').then(
            (m) => m.MyTicketsComponent,
          ),
      },
      {
        path: 'notifications',
        loadComponent: () =>
          import('./features/notifications/inbox-page/inbox-page.component').then((m) => m.InboxPageComponent),
      },
      {
        path: 'trip-channel/:tripId',
        loadComponent: () =>
          import('./features/notifications/trip-channel-page/trip-channel-page.component').then(
            (m) => m.TripChannelPageComponent,
          ),
      },
    ],
  },

  // Partenaire + gare : déployés sur Mobili Business (ex. 4201 en local) — voir businessWebBase (mobili-shared).
  {
    path: 'partenaire',
    children: [
      {
        path: '**',
        loadComponent: () =>
          import('./features/routing/redirect-to-business.component').then(
            (m) => m.RedirectToBusinessComponent,
          ),
      },
    ],
  },
  {
    path: 'gare',
    children: [
      {
        path: '**',
        loadComponent: () =>
          import('./features/routing/redirect-to-business.component').then(
            (m) => m.RedirectToBusinessComponent,
          ),
      },
    ],
  },
  // Covoiturage solo (chauffeur particulier) : même code que Mobili Business, déployé sur l’origine business (4201).
  {
    path: 'covoiturage',
    children: [
      {
        path: '**',
        loadComponent: () =>
          import('./features/routing/redirect-to-business.component').then(
            (m) => m.RedirectToBusinessComponent,
          ),
      },
    ],
  },
  {
    path: 'chauffeur',
    canActivate: [chauffeurGuard],
    loadComponent: () =>
      import('./features/chauffeur/chauffeur-shell/chauffeur-shell.component').then(
        (m) => m.ChauffeurShellComponent,
      ),
    children: [
      {
        path: '',
        pathMatch: 'full',
        loadComponent: () =>
          import('./features/chauffeur/driver-console/driver-console.component').then(
            (m) => m.DriverConsoleComponent,
          ),
      },
      {
        path: 'scan',
        loadComponent: () =>
          import('./features/gare/scanner/scanner.component').then((m) => m.TicketScannerComponent),
      },
    ],
  },

  // ============ ESPACE ADMIN (shell custom) ============
  {
    path: 'admin',
    canActivate: [adminGuard],
    loadComponent: () =>
      import('./features/admin/admin-shell/admin-shell.component').then(
        (m) => m.AdminShellComponent,
      ),
    children: [
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
      { path: 'dashboard', component: AdminDashboard },
      {
        path: 'analyse-app',
        loadComponent: () =>
          import('./features/admin/admin-app-analytics/admin-app-analytics').then(
            (m) => m.AdminAppAnalytics,
          ),
      },
      {
        path: 'metier',
        loadComponent: () =>
          import('./features/admin/admin-business/admin-business').then((m) => m.AdminBusiness),
      },
      { path: 'users', component: AdminUsers },
      { path: 'partners', component: AdminPartners },
      {
        path: 'communication',
        loadComponent: () =>
          import('./features/admin/admin-communication/admin-communication').then(
            (m) => m.AdminCommunication,
          ),
      },
    ],
  },

  // ============ BOOKING / PAYMENT ============
  {
    path: 'booking',
    canActivate: [authGuard],
    children: [
      {
        path: 'trip/:id',
        loadComponent: () =>
          import('./features/bookings/booking-trip/booking-trip.component').then(
            (m) => m.BookingTripComponent,
          ),
      },
      {
        path: 'confirmation/:id',
        loadComponent: () =>
          import('./features/bookings/booking-confirmation/booking-confirmation.component').then(
            (m) => m.BookingConfirmationComponent,
          ),
      },
    ],
  },
  {
    path: 'payment',
    canActivate: [authGuard],
    children: [
      {
        path: 'success',
        loadComponent: () =>
          import('./features/payment/payment-success/payment-success.component').then(
            (m) => m.PaymentSuccessComponent,
          ),
      },
    ],
  },

  { path: '**', redirectTo: '' },
];
