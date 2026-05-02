import { InjectionToken } from '@angular/core';

/** `passenger` = appli voyageurs (réservations) ; `business` = Mobili Business (pro). */
export type MobiliAppKind = 'passenger' | 'business';

export const MOBILI_APP_KIND = new InjectionToken<MobiliAppKind>('MOBILI_APP_KIND');
