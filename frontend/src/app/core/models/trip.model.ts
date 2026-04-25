export interface Trip {
  id?: number;
  departureCity: string;
  arrivalCity: string;
  departureDateTime: string;
  price: number;
  availableSeats: number;
  vehicleType: string;
  boardingPoint: string; // Lieu d'embarquement
  vehiclePhoto?: string; // URL ou Base64 de la photo
  stops: string; // Villes sur le trajet
}
