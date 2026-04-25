import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface TripChannelMessage {
  id: number;
  body: string;
  createdAt: string;
  authorName: string;
  authorRole: string;
}

@Injectable({ providedIn: 'root' })
export class TripChannelService {
  private http = inject(HttpClient);

  list(tripId: number): Observable<TripChannelMessage[]> {
    return this.http.get<TripChannelMessage[]>(`/trips/${tripId}/channel/messages`);
  }

  post(tripId: number, body: string): Observable<TripChannelMessage> {
    return this.http.post<TripChannelMessage>(`/trips/${tripId}/channel/messages`, { body });
  }
}
