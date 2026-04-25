import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { vi } from 'vitest';
import { adminGuard } from './admin.guard';
import { AuthService } from '../services/auth/auth.service';

describe('adminGuard', () => {
  const navigate = vi.fn();
  const hasRole = vi.fn();

  beforeEach(() => {
    navigate.mockReset();
    hasRole.mockReset();
    TestBed.configureTestingModule({
      providers: [
        { provide: Router, useValue: { navigate } },
        { provide: AuthService, useValue: { hasRole } },
      ],
    });
  });

  it('autorise un admin', () => {
    hasRole.mockReturnValue(true);

    const result = TestBed.runInInjectionContext(() => adminGuard({} as any, {} as any));

    expect(result).toBe(true);
    expect(navigate).not.toHaveBeenCalled();
  });

  it('redirige un non-admin vers la home', () => {
    hasRole.mockReturnValue(false);

    const result = TestBed.runInInjectionContext(() => adminGuard({} as any, {} as any));

    expect(result).toBe(false);
    expect(navigate).toHaveBeenCalledWith(['/']);
  });
});
