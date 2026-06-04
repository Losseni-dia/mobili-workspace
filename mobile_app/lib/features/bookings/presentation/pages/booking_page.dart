import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/booking_service.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../../trips/domain/models/trip.dart';
import '../../../trips/providers/trip_provider.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key, required this.trip});
  final Trip trip;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int? _selectedSeat;
  final int _boardingStopIndex = 0;
  final int _alightingStopIndex = 1;

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final occupiedAsync = ref.watch(occupiedSeatsProvider(OccupiedSeatsParams(tripId: widget.trip.id)));

    ref.listen<BookingState>(bookingNotifierProvider, (_, next) {
      if (next.step == BookingStep.done) {
        _showSuccess();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.gray50,
      appBar: AppBar(title: const Text('Sélection du siège')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sièges disponibles', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 16),
                  occupiedAsync.when(
                    loading: () => const MobiliLoader(),
                    error: (_, __) => const Text('Erreur de chargement'),
                    data: (occupied) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: widget.trip.totalSeats,
                      itemBuilder: (_, i) {
                        final seatNumber = i + 1;
                        final isOccupied = occupied.contains(seatNumber);
                        final isSelected = _selectedSeat == seatNumber;

                        return GestureDetector(
                          onTap: isOccupied ? null : () => setState(() => _selectedSeat = seatNumber),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isOccupied 
                                  ? AppColors.gray300 
                                  : isSelected ? AppColors.mobiliYellow : AppColors.mobiliBlueFog,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('$seatNumber', style: AppTextStyles.titleMedium),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: MobiliButton(
              label: _selectedSeat != null ? 'Procéder au paiement (FedaPay)' : 'Sélectionnez un siège',
              enabled: _selectedSeat != null && !bookingState.isLoading,
              isLoading: bookingState.isLoading,
              onPressed: () async {
                await ref.read(bookingNotifierProvider.notifier).createAndPay(
                  CreateBookingRequest(
                    tripId: widget.trip.id,
                    seatNumber: _selectedSeat!,
                    boardingStopIndex: _boardingStopIndex,
                    alightingStopIndex: _alightingStopIndex,
                  ),
                );
                
                final state = ref.read(bookingNotifierProvider);
                if (state.paymentUrl != null && mounted) {
                  final uri = Uri.parse(state.paymentUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    ref.read(bookingNotifierProvider.notifier).verifyAfterReturn();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Félicitations !'),
        content: const Text('Votre réservation sur Mobili est validée avec succès. Bon voyage !'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // fermer la boîte
              context.go('/'); // retour à l'accueil via GoRouter
            },
            child: const Text("Retour à l'accueil"),
          )
        ],
      ),
    );
  }
}