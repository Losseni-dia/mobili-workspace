import { HttpClient, provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { TripService } from './trip.service';

describe('TripService', () => {
  let service: TripService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [TripService, provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(TripService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('searchTrips envoie departure, arrival et date en query', () => {
    service.searchTrips('Abidjan', 'Gagnoa', '2030-06-01').subscribe();

    const req = httpMock.expectOne(
      (r) => r.url.endsWith('/trips/search') && r.method === 'GET',
    );
    expect(req.request.params.get('departure')).toBe('Abidjan');
    expect(req.request.params.get('arrival')).toBe('Gagnoa');
    expect(req.request.params.get('date')).toBe('2030-06-01');
    req.flush([]);
  });

  it('searchTrips n’ajoute pas date si vide ou blanc', () => {
    service.searchTrips('A', 'B', '   ').subscribe();

    const req = httpMock.expectOne((r) => r.url.endsWith('/trips/search'));
    expect(req.request.params.get('departure')).toBe('A');
    expect(req.request.params.get('arrival')).toBe('B');
    expect(req.request.params.has('date')).toBe(false);
    req.flush([]);
  });
});
