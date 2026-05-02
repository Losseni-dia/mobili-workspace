import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { vi } from 'vitest';
import { of } from 'rxjs';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from '../services/auth/auth.service';

describe('authInterceptor', () => {
  let http: HttpClient;
  let httpMock: HttpTestingController;
  const logout = vi.fn();
  const navigate = vi.fn();
  const currentUser = vi.fn();
  const refreshAccessTokenFromCookie = vi.fn(() => of(false));

  beforeEach(() => {
    logout.mockReset();
    navigate.mockReset();
    currentUser.mockReset();
    refreshAccessTokenFromCookie.mockReset();
    refreshAccessTokenFromCookie.mockReturnValue(of(false));

    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        {
          provide: AuthService,
          useValue: {
            currentUser,
            logout,
            refreshAccessTokenFromCookie,
          },
        },
        {
          provide: Router,
          useValue: {
            navigate,
          },
        },
      ],
    });

    http = TestBed.inject(HttpClient);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('ajoute le header Authorization quand un token existe', () => {
    currentUser.mockReturnValue({ token: 'abc-token' });

    http.get('/bookings').subscribe();
    const req = httpMock.expectOne('/bookings');

    expect(req.request.headers.get('Authorization')).toBe('Bearer abc-token');
    req.flush({});
  });

  it('déconnecte et redirige sur 401', () => {
    currentUser.mockReturnValue({ token: 'abc-token' });
    let capturedStatus: number | undefined;

    http.get('/bookings').subscribe({
      error: (err) => {
        capturedStatus = (err as HttpErrorResponse).status;
      },
    });

    const req = httpMock.expectOne('/bookings');
    req.flush({ message: 'unauthorized' }, { status: 401, statusText: 'Unauthorized' });

    expect(logout).toHaveBeenCalled();
    expect(navigate).toHaveBeenCalledWith(['/auth/login']);
    expect(capturedStatus).toBe(401);
  });

  it('retente une fois sur 401 si le refresh réussit', () => {
    const state = { token: 'expired' };
    currentUser.mockImplementation(() => ({ token: state.token } as { token: string }));
    refreshAccessTokenFromCookie.mockImplementation(() => {
      state.token = 'fresh';
      return of(true);
    });

    let result: unknown;
    http.get('/bookings').subscribe((r) => {
      result = r;
    });

    const r1 = httpMock.expectOne('/bookings');
    expect(r1.request.headers.get('Authorization')).toBe('Bearer expired');
    r1.flush({ message: 'n' }, { status: 401, statusText: 'Unauthorized' });

    expect(refreshAccessTokenFromCookie).toHaveBeenCalled();
    const r2 = httpMock.expectOne('/bookings');
    expect(r2.request.headers.get('Authorization')).toBe('Bearer fresh');
    r2.flush({ data: 1 });
    expect(result).toEqual({ data: 1 });
  });
});
