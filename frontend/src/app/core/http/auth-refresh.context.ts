import { HttpContextToken } from '@angular/common/http';

/** Règle : la requête `POST /auth/refresh` ne déclenche pas une boucle 401 → refresh. */
export const skipAuthRefreshRetry = new HttpContextToken<boolean>(() => false);
