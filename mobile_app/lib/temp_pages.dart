import 'package:flutter/material.dart';

// Ce fichier temporaire permet de simuler toutes les pages importées par le GoRouter
// On le supprimera au fur et à mesure qu'on avancera avec les autres agents !

class LoginPage extends StatelessWidget { const LoginPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Login'))); }
class RegisterPage extends StatelessWidget { const RegisterPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Register'))); }
class RegisterCompanyPage extends StatelessWidget { const RegisterCompanyPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Register Company'))); }
class RegisterChauffeurPage extends StatelessWidget { const RegisterChauffeurPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Register Chauffeur'))); }
class TripsListPage extends StatelessWidget { const TripsListPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Trips List'))); }
class TripDetailPage extends StatelessWidget { final int tripId; const TripDetailPage({super.key, required this.tripId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Trip Detail $tripId'))); }
class TripStopsPage extends StatelessWidget { final int tripId; const TripStopsPage({super.key, required this.tripId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Trip Stops $tripId'))); }
class TripChannelPage extends StatelessWidget { final int tripId; const TripChannelPage({super.key, required this.tripId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Trip Channel $tripId'))); }
class TripSearchPage extends StatelessWidget { const TripSearchPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Trip Search'))); }
class BookingCreatePage extends StatelessWidget { final int tripId; const BookingCreatePage({super.key, required this.tripId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Booking Create $tripId'))); }
class BookingDetailPage extends StatelessWidget { final int bookingId; const BookingDetailPage({super.key, required this.bookingId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Booking Detail $bookingId'))); }
class MyBookingsPage extends StatelessWidget { const MyBookingsPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('My Bookings'))); }
class PaymentWebviewPage extends StatelessWidget { final int bookingId; final String checkoutUrl; const PaymentWebviewPage({super.key, required this.bookingId, required this.checkoutUrl}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Payment Webview $bookingId'))); }
class PaymentResultPage extends StatelessWidget { final int bookingId; const PaymentResultPage({super.key, required this.bookingId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Payment Result $bookingId'))); }
class MyTicketsPage extends StatelessWidget { const MyTicketsPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('My Tickets'))); }
class TicketDetailPage extends StatelessWidget { final int ticketId; const TicketDetailPage({super.key, required this.ticketId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Ticket Detail $ticketId'))); }
class NotificationsPage extends StatelessWidget { const NotificationsPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Notifications'))); }
class PartnersListPage extends StatelessWidget { const PartnersListPage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Partners List'))); }
class PartnerDetailPage extends StatelessWidget { final int partnerId; const PartnerDetailPage({super.key, required this.partnerId}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Partner Detail $partnerId'))); }
class ProfilePage extends StatelessWidget { const ProfilePage({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Profile'))); }

// Coque pour la barre de navigation du bas
class ShellPage extends StatelessWidget {
  final Widget navigationShell;
  const ShellPage({super.key, required this.navigationShell});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recherche'),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Réservations'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      );
}

// Simulation du provider d'authentification pour éviter les erreurs
class AuthStateMock { final String? value; const AuthStateMock(this.value); }
final authStateProvider = Object(); // Juste pour la compilation