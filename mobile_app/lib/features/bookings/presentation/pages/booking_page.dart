import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/core/services/analytics_service.dart';
import 'package:mobili/features/auth/presentation/pages/login_page.dart';
import 'package:mobili/features/auth/providers/auth_provider.dart';
import 'package:mobili/features/bookings/presentation/pages/my_tickets_page.dart';
import 'package:mobili/features/bookings/presentation/pages/payment_webview_page.dart';
import 'package:mobili/features/notifications/providers/notification_provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/mobili_app_bar.dart';
import '../../../../shared/widgets/mobili_button.dart';
import '../../../../shared/widgets/mobili_loader.dart';
import '../../../trips/domain/models/trip.dart';
import '../../../trips/providers/trip_provider.dart';
import '../../data/booking_service.dart';
import '../widgets/seat_map_widget.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key, required this.trip});
  final Trip trip;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  final List<String> _selectedSeats = [];
  final List<TextEditingController> _passengerCtrls = [];
  int _boardingIndex = 0;
  int _alightingIndex = 0;
  int _extraBags = 0;
  late List<String> _stopLabels;

  // Mobile Money présélectionné : comportement le plus proche de l'existant
  // (FedaPay était le seul choix jusqu'ici). L'utilisateur peut basculer sur
  // Carte bancaire via le sélecteur affiché plus bas.
  String _selectedPaymentProvider = 'FEDAPAY';

  final _scrollController = ScrollController();
  final _passengerSectionKey = GlobalKey();
  final _couponController = TextEditingController();

  // État du coupon : la remise n'est calculée par le backend qu'au moment
  // où on appuie sur "Appliquer" (GET /coupons/{code}/validate) — jamais
  // automatiquement en tapant, pour ne pas spammer l'API à chaque frappe.
  // _couponAppliedCode doit correspondre au texte actuel du champ, sinon la
  // remise est considérée périmée (voir _invalidateCoupon).
  String? _couponAppliedCode;
  double? _couponDiscountedSeatSubtotal;
  bool _couponLoading = false;
  String? _couponError;

  // Aperçu du forfait client — recalculé côté serveur (POST /bookings/price-preview,
  // même séquence que la création réelle, jamais dupliquée ici) à chaque changement pouvant
  // affecter le prix. _previewSeq écarte les réponses obsolètes (deux previews en vol, la
  // plus ancienne revient après la plus récente).
  int? _serviceFee;
  double? _previewTotal;
  int _previewSeq = 0;

  @override
  void initState() {
    super.initState();
    _stopLabels = _buildStopLabels();
    _alightingIndex = _stopLabels.length - 1;
  }

  @override
  void dispose() {
    for (final c in _passengerCtrls) {
      c.dispose();
    }
    _couponController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _buildStopLabels() {
    final dep = widget.trip.departureCity;
    final arr = widget.trip.arrivalCity;
    final more = widget.trip.moreInfo ?? '';
    final labels = <String>[dep];
    if (more.isNotEmpty) {
      for (final city in more.split(',')) {
        final t = city.trim();
        if (t.isNotEmpty && t.toLowerCase() != dep.toLowerCase()) {
          labels.add(t[0].toUpperCase() + t.substring(1).toLowerCase());
        }
      }
    }
    if (arr.toLowerCase() != labels.last.toLowerCase()) {
      labels.add(arr);
    }
    return labels;
  }

  double _pricePerSeat() {
    final fares = widget.trip.legFares;
    final lastIndex = _stopLabels.length - 1;

    // Trajet complet → prix principal direct
    if (_boardingIndex == 0 && _alightingIndex == lastIndex) {
      return widget.trip.priceXof;
    }

    if (fares != null && fares.isNotEmpty) {
      // 1. Prix direct boarding→alighting
      final direct = fares.where((f) =>
          f.fromStopIndex == _boardingIndex &&
          f.toStopIndex == _alightingIndex);
      if (direct.isNotEmpty) return direct.first.priceXof;

      // 2. Somme tronçons consécutifs
      double total = 0;
      bool allFound = true;
      for (var i = _boardingIndex; i < _alightingIndex; i++) {
        final leg =
            fares.where((f) => f.fromStopIndex == i && f.toStopIndex == i + 1);
        if (leg.isEmpty) {
          allFound = false;
          break;
        }
        total += leg.first.priceXof;
      }
      if (allFound && total > 0) return total;
    }

    return widget.trip.priceXof;
  }

  double _luggageFee() => _extraBags * (widget.trip.extraHoldBagPrice ?? 0);

  // Sous-total sièges seuls, avant bagages — même base que
  // BookingService.create() côté backend (perSeatPrice * requestedSeats),
  // sur laquelle le coupon est appliqué avant d'ajouter les bagages.
  double _seatSubtotal() => _selectedSeats.length * _pricePerSeat();

  double _totalPrice() {
    final couponStillValid = _couponAppliedCode != null &&
        _couponAppliedCode == _couponController.text.trim() &&
        _couponDiscountedSeatSubtotal != null;
    final seatPart =
        couponStillValid ? _couponDiscountedSeatSubtotal! : _seatSubtotal();
    return seatPart + _luggageFee();
  }

  /// La remise appliquée n'est plus fiable dès que les sièges, le tronçon,
  /// ou le code lui-même changent — mieux vaut forcer un nouveau clic sur
  /// "Appliquer" que d'afficher un montant obsolète.
  void _invalidateCoupon() {
    if (_couponAppliedCode != null || _couponError != null) {
      setState(() {
        _couponAppliedCode = null;
        _couponDiscountedSeatSubtotal = null;
        _couponError = null;
      });
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _couponLoading = true;
      _couponError = null;
    });
    try {
      final discounted = await ref
          .read(bookingServiceProvider)
          .validateCoupon(code, _seatSubtotal());
      if (!mounted) return;
      setState(() {
        _couponAppliedCode = code;
        _couponDiscountedSeatSubtotal = discounted;
        _couponLoading = false;
      });
      _refreshPricePreview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponAppliedCode = null;
        _couponDiscountedSeatSubtotal = null;
        _couponError =
            e is DioException ? e.asMobili.message : 'Coupon invalide.';
        _couponLoading = false;
      });
    }
  }

  int _maxExtraBags() =>
      _selectedSeats.length * widget.trip.maxExtraHoldBagsPerPassenger;

  /// Recalcule le forfait client (et le total serveur) après tout changement affectant le
  /// prix (sièges, tronçon, bagages, coupon). Silencieux en cas d'échec réseau — l'écran
  /// retombe sur `_totalPrice()` calculé localement (sans forfait) plutôt que de bloquer la
  /// réservation ; le montant réellement facturé reste de toute façon calculé côté serveur.
  Future<void> _refreshPricePreview() async {
    if (_selectedSeats.isEmpty) {
      setState(() {
        _serviceFee = null;
        _previewTotal = null;
      });
      return;
    }
    final seq = ++_previewSeq;
    final couponStillValid = _couponAppliedCode != null &&
        _couponAppliedCode == _couponController.text.trim();
    try {
      final preview = await ref.read(bookingServiceProvider).previewPrice(
            tripId: widget.trip.id,
            numberOfSeats: _selectedSeats.length,
            boardingStopIndex: _boardingIndex,
            alightingStopIndex: _alightingIndex,
            extraHoldBags: _extraBags,
            couponCode: couponStillValid ? _couponAppliedCode : null,
          );
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _serviceFee = preview.serviceFee;
        _previewTotal = preview.total;
      });
    } catch (_) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _serviceFee = null;
        _previewTotal = null;
      });
    }
  }

  static const int _maxTicketsPerBooking = 5;

  void _onSeatTap(int seatNumber, List<int> occupied) {
    if (occupied.contains(seatNumber) ||
        occupied.contains(seatNumber.toString())) {
      return;
    }
    final seat = '$seatNumber';

    // Limite structurelle (aussi imposée côté backend, @Max sur BookingRequestDTO) — retour
    // immédiat sans attendre un rejet serveur, l'utilisateur doit savoir tout de suite
    // pourquoi son tap n'a rien fait.
    if (!_selectedSeats.contains(seat) &&
        _selectedSeats.length >= _maxTicketsPerBooking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 tickets par réservation'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final wasEmpty = _selectedSeats.isEmpty;
    setState(() {
      if (_selectedSeats.contains(seat)) {
        final idx = _selectedSeats.indexOf(seat);
        _selectedSeats.remove(seat);
        _passengerCtrls[idx].dispose();
        _passengerCtrls.removeAt(idx);
      } else {
        _selectedSeats.add(seat);
        _passengerCtrls.add(TextEditingController());
      }
      if (_extraBags > _maxExtraBags()) _extraBags = _maxExtraBags();
    });
    // Le nombre de sièges change le sous-total sur lequel la remise a été
    // calculée — une remise déjà appliquée n'est plus fiable.
    _invalidateCoupon();
    _refreshPricePreview();

    // Dès qu'on sélectionne le premier siège, on scroll automatiquement
    // vers la section "Noms des passagers" pour éviter d'avoir à remonter
    // manuellement — elle apparaît juste en dessous une fois _selectedSeats
    // non vide (voir le `if` dans build()).
    if (wasEmpty && _selectedSeats.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _passengerSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  bool get _isValid {
    if (_selectedSeats.isEmpty) return false;
    if (_alightingIndex <= _boardingIndex) return false;
    for (final c in _passengerCtrls) {
      if (c.text.trim().isEmpty) return false;
    }
    return true;
  }

  // Cette page est atteinte via Navigator.push (trip_detail_page.dart,
  // trips_list_page.dart), donc HORS du guard d'authentification de
  // go_router.dart (redirect: ...), qui ne s'applique qu'aux routes déclarées
  // dans le router. Sans ce contrôle, un utilisateur non connecté pouvait
  // arriver jusqu'à la sélection de sièges et au choix de paiement côté
  // client (AUDIT-MOBILI.md §3.7). Même logique d'attente que go_router.dart
  // (on ne redirige jamais tant que l'état auth est encore initial/loading,
  // pour ne pas éjecter un utilisateur réellement connecté pendant la
  // vérification du token au démarrage). Réactif via ref.watch : si la
  // session expire pendant que la page est ouverte, l'utilisateur est
  // également renvoyé au login.
  bool _redirectingToLogin = false;

  void _guardAuthOrRedirect(BuildContext context, AuthState? authState) {
    final isLoadingAuth =
        authState?.isLoading == true || authState?.status == AuthStatus.initial;
    final isAuthenticated = authState?.isAuthenticated ?? false;
    if (isLoadingAuth || isAuthenticated || _redirectingToLogin) return;

    _redirectingToLogin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).valueOrNull;
    _guardAuthOrRedirect(context, authState);
    if (!(authState?.isAuthenticated ?? false)) {
      return const Scaffold(body: Center(child: MobiliLoader()));
    }

    final bookingState = ref.watch(bookingNotifierProvider);
    final covoiturageRequestState =
        ref.watch(covoiturageRequestNotifierProvider);
    final occupiedAsync = ref.watch(occupiedSeatsProvider(
      OccupiedSeatsParams(
        tripId: widget.trip.id,
        boardingStopIndex: _boardingIndex,
        alightingStopIndex: _alightingIndex,
      ),
    ));

    ref.listen<BookingState>(bookingNotifierProvider, (_, next) {
      if (next.step == BookingStep.done) _showSuccess();
      // Sans ce cas, un coupon invalide/expiré (ou toute autre erreur de
      // création de réservation — 400 côté backend) échouait en silence :
      // le bouton "Payer" ne faisait plus rien, sans aucun message. Même
      // schéma que le flux covoiturage ci-dessous, qui gérait déjà ce cas.
      if (next.step == BookingStep.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Erreur lors de la réservation.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    ref.listen<CovoiturageRequestState>(covoiturageRequestNotifierProvider,
        (_, next) {
      if (next.step == CovoiturageRequestStep.sent) _showRequestSent();
      if (next.step == CovoiturageRequestStep.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.errorMessage ?? 'Erreur lors de la demande.'),
              backgroundColor: AppColors.danger),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: MobiliAppBar(
        title: 'Réservation',
        subtitle: '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
        backRoute: '/',
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Segment embarquement/descente ──────
                  // (Le résumé trajet a été retiré : déjà affiché sur la
                  // page précédente — trip_detail_page.dart — même carte,
                  // redondant ici.)
                  if (_stopLabels.length > 2) ...[
                    const _SectionTitle(
                        icon: Icons.route_rounded, label: 'Votre tronçon'),
                    const SizedBox(height: 10),
                    _SegmentSelector(
                      stopLabels: _stopLabels,
                      boardingIndex: _boardingIndex,
                      alightingIndex: _alightingIndex,
                      pricePerSeat: _pricePerSeat(),
                      onBoardingChanged: (i) {
                        setState(() {
                          _boardingIndex = i;
                          if (_alightingIndex <= i) _alightingIndex = i + 1;
                        });
                        _invalidateCoupon();
                        _refreshPricePreview();
                      },
                      onAlightingChanged: (i) {
                        setState(() => _alightingIndex = i);
                        _invalidateCoupon();
                        _refreshPricePreview();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Sièges ─────────────────────────────
                  const _SectionTitle(
                      icon: Icons.event_seat_rounded,
                      label: 'Choisissez vos sièges'),
                  const SizedBox(height: 10),
                  occupiedAsync.when(
                    loading: () => const MobiliLoader(),
                    error: (e, _) {
                      final is403 = e.toString().contains('403');
                      if (is403) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) context.go('/login');
                        });
                        return const SizedBox.shrink();
                      }
                      return const Text('Erreur de chargement des sièges');
                    },
                    data: (occupied) => SeatMapWidget(
                      totalSeats: widget.trip.totalSeats,
                      occupied: occupied,
                      selected: _selectedSeats,
                      onTap: (n) => _onSeatTap(n, occupied),
                      vehicleType: widget.trip.vehicleType,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Noms passagers ─────────────────────
                  if (_selectedSeats.isNotEmpty) ...[
                    _SectionTitle(
                      key: _passengerSectionKey,
                      icon: Icons.people_outline_rounded,
                      label: 'Noms des passagers',
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(
                      _selectedSeats.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PassengerField(
                          seatNumber: _selectedSeats[i],
                          controller: _passengerCtrls[i],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // ── Bagages ────────────────────────────
                  if ((widget.trip.extraHoldBagPrice ?? 0) > 0 &&
                      _selectedSeats.isNotEmpty) ...[
                    const _SectionTitle(
                        icon: Icons.luggage_rounded,
                        label: 'Bagages supplémentaires'),
                    const SizedBox(height: 10),
                    _BaggageSelector(
                      extraBags: _extraBags,
                      maxBags: _maxExtraBags(),
                      pricePerBag: widget.trip.extraHoldBagPrice ?? 0,
                      onChanged: (v) {
                        setState(() => _extraBags = v);
                        _refreshPricePreview();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // ── Coupon ────────────────────────────
                  if (_selectedSeats.isNotEmpty) ...[
                    const _SectionTitle(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Code promo'),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _couponController,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) => _invalidateCoupon(),
                            decoration: const InputDecoration(
                              hintText: 'Entrez votre code',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Pas de SizedBox(height:...) englobant sans largeur
                        // fixe ici : placé tel quel dans un Row (largeur non
                        // bornée), ça forçait une largeur infinie sur
                        // l'ElevatedButton et cassait tout le layout de la
                        // page ("BoxConstraints forces an infinite width").
                        // La hauteur se règle via minimumSize du style.
                        ElevatedButton(
                          onPressed: _couponLoading ? null : _applyCoupon,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mobiliBlue,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _couponLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Appliquer',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (_couponAppliedCode != null &&
                        _couponAppliedCode == _couponController.text.trim() &&
                        _couponDiscountedSeatSubtotal != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Coupon appliqué : -${(_seatSubtotal() - _couponDiscountedSeatSubtotal!).toStringAsFixed(0)} FCFA',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.stationGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_couponError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _couponError!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // ── Moyen de paiement ──────────────────
                  if (_selectedSeats.isNotEmpty && !widget.trip.isCovoiturage) ...[
                    const _SectionTitle(
                        icon: Icons.payment_rounded,
                        label: 'Moyen de paiement'),
                    const SizedBox(height: 10),
                    _PaymentMethodSelector(
                      selected: _selectedPaymentProvider,
                      onChanged: (v) =>
                          setState(() => _selectedPaymentProvider = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Barre prix + paiement / demande ──────────────
          _PriceBar(
            selectedCount: _selectedSeats.length,
            pricePerSeat: _pricePerSeat(),
            luggageFee: _luggageFee(),
            serviceFee: _serviceFee,
            // Le total serveur (avec forfait) prime dès qu'il est disponible ; en attendant
            // sa réponse, on retombe sur le total local (sans forfait) plutôt que d'afficher
            // un vide — jamais un total opaque, mais une transition sans à-coup.
            total: _previewTotal ?? _totalPrice(),
            isLoading: widget.trip.isCovoiturage
                ? covoiturageRequestState.isLoading
                : bookingState.isLoading,
            isValid: _isValid,
            isCovoiturage: widget.trip.isCovoiturage,
            onPay: () async {
              final profile = ref.read(authProvider).valueOrNull?.profile;
              if (profile == null) return;

              final request = CreateBookingRequest(
                tripId: widget.trip.id,
                userId: profile.id,
                numberOfSeats: _selectedSeats.length,
                selections: _selectedSeats
                    .asMap()
                    .entries
                    .map(
                      (e) => SeatSelection(
                        seatNumber: e.value,
                        passengerName: _passengerCtrls[e.key].text.trim(),
                      ),
                    )
                    .toList(),
                boardingStopIndex: _boardingIndex,
                alightingStopIndex: _alightingIndex,
                extraHoldBags: _extraBags,
                couponCode: _couponController.text.trim().isNotEmpty ? _couponController.text.trim() : null,
              );

            // ── Covoiturage : demande au chauffeur, pas de paiement immédiat ──
              if (widget.trip.isCovoiturage) {
                await ref
                    .read(covoiturageRequestNotifierProvider.notifier)
                    .sendRequest(request);
                // Le compteur "places restantes" affiché sur le catalogue
                // doit refléter la place bloquée par cette demande, sans
                // attendre un refresh manuel de l'utilisateur.
                ref.invalidate(tripsProvider);
                ref.invalidate(tripDetailProvider(widget.trip.id));
                return;
              }

              // ── Trajet public : flux inchangé ──
              AnalyticsService.logBeginBooking(
                tripId: widget.trip.id,
                route:
                    '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
                seats: _selectedSeats.length,
                price: _totalPrice(),
              );

              await ref.read(bookingNotifierProvider.notifier).createAndPay(
                    request,
                    provider: _selectedPaymentProvider,
                    customerEmail: profile.email,
                  );
              final state = ref.read(bookingNotifierProvider);
              if (state.paymentUrl != null && mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentWebViewPage(
                      paymentUrl: state.paymentUrl!,
                      providerLabel: _selectedPaymentProvider == 'STRIPE'
                          ? 'Carte bancaire'
                          : 'Mobile Money',
                      onSuccess: () {
                        ref
                            .read(bookingNotifierProvider.notifier)
                            .verifyAfterReturn();
                      },
                      onCancel: () {},
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    // Analytics — conversion paiement réussi
    AnalyticsService.logPaymentSuccess(
      bookingId: 0, // bookingId non disponible ici directement
      tripId: widget.trip.id,
      route: '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
      seats: _selectedSeats.length,
      amount: _totalPrice(),
    );
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
    // MyTicketsPage vit dans un StatefulShellRoute.indexedStack : l'onglet
    // reste monté en arrière-plan en changeant d'onglet, donc ticketsProvider
    // (FutureProvider.autoDispose) ne se redéclenche jamais tout seul —
    // sans cette invalidation explicite, le ticket fraîchement créé
    // n'apparaît pas (liste mise en cache depuis la dernière visite).
    final profile = ref.read(authProvider).valueOrNull?.profile;
    if (profile != null) {
      ref.invalidate(ticketsProvider(profile.id));
    }
    // Redirection immédiate vers l'onglet Mes tickets — le ticket vient
    // d'être créé, pas besoin d'un tap supplémentaire sur un dialogue pour
    // le voir. SnackBar affiché avant la navigation (contexte encore monté
    // ici avec certitude) pour confirmer ce qui vient de se passer.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Réservation confirmée ! Bon voyage 🎉'),
        backgroundColor: AppColors.stationGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/tickets');
  }

  void _showRequestSent() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded,
                color: AppColors.warning, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('Demande envoyée !', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: const Text(
          'Votre demande a été transmise au conducteur. '
          'Vous recevrez une notification dès qu\'il aura répondu '
          '(sous 24h maximum). S\'il accepte, vous aurez 30 minutes '
          'pour finaliser le paiement.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/my-bookings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mobiliBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Voir mes réservations',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur tronçon
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentSelector extends StatelessWidget {
  const _SegmentSelector({
    required this.stopLabels,
    required this.boardingIndex,
    required this.alightingIndex,
    required this.pricePerSeat,
    required this.onBoardingChanged,
    required this.onAlightingChanged,
  });

  final List<String> stopLabels;
  final int boardingIndex;
  final int alightingIndex;
  final double pricePerSeat;
  final ValueChanged<int> onBoardingChanged;
  final ValueChanged<int> onAlightingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Embarquement',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.gray400,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        )),
                    const SizedBox(height: 4),
                    _StopDropdown(
                      value: boardingIndex,
                      options: stopLabels
                          .sublist(0, stopLabels.length - 1)
                          .asMap()
                          .entries
                          .map((e) => MapEntry(e.key, e.value))
                          .toList(),
                      onChanged: onBoardingChanged,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color: AppColors.mobiliBlue, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descente',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.gray400,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        )),
                    const SizedBox(height: 4),
                    _StopDropdown(
                      value: alightingIndex,
                      options: stopLabels
                          .sublist(boardingIndex + 1)
                          .asMap()
                          .entries
                          .map((e) =>
                              MapEntry(boardingIndex + 1 + e.key, e.value))
                          .toList(),
                      onChanged: onAlightingChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlueFog,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sell_outlined,
                    size: 14, color: AppColors.mobiliBlue),
                const SizedBox(width: 6),
                Text(
                  'Prix pour ce tronçon : ${pricePerSeat.toStringAsFixed(0)} FCFA / place',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.mobiliBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopDropdown extends StatelessWidget {
  const _StopDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<MapEntry<int, String>> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.gray400),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.mobiliBlueDeep,
            fontSize: 13,
          ),
          items: options
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Champ nom passager
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerField extends StatelessWidget {
  const _PassengerField({
    required this.seatNumber,
    required this.controller,
    required this.onChanged,
  });

  final String seatNumber;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.mobiliYellow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(seatNumber,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.mobiliBlueDeep,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.mobiliBlueDeep),
            decoration: InputDecoration(
              hintText: 'Nom du passager',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.gray300),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 18, color: AppColors.gray400),
              filled: true,
              fillColor: AppColors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gray200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.mobiliBlue, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur bagages
// ─────────────────────────────────────────────────────────────────────────────

class _BaggageSelector extends StatelessWidget {
  const _BaggageSelector({
    required this.extraBags,
    required this.maxBags,
    required this.pricePerBag,
    required this.onChanged,
  });

  final int extraBags;
  final int maxBags;
  final double pricePerBag;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          const Icon(Icons.luggage_rounded,
              color: AppColors.mobiliBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bagages soute supplémentaires',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w600,
                    )),
                Text(
                    '${pricePerBag.toStringAsFixed(0)} FCFA / bagage · max $maxBags',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.gray400,
                      fontSize: 11,
                    )),
              ],
            ),
          ),
          Row(
            children: [
              _CountBtn(
                icon: Icons.remove_rounded,
                onTap: extraBags > 0 ? () => onChanged(extraBags - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$extraBags',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                    )),
              ),
              _CountBtn(
                icon: Icons.add_rounded,
                onTap:
                    extraBags < maxBags ? () => onChanged(extraBags + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur moyen de paiement (Mobile Money / Carte bancaire)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  /// 'FEDAPAY' (Mobile Money) ou 'STRIPE' (carte bancaire).
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentMethodCard(
            icon: Icons.phone_android_rounded,
            label: 'Mobile Money',
            selected: selected == 'FEDAPAY',
            onTap: () => onChanged('FEDAPAY'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentMethodCard(
            icon: Icons.credit_card_rounded,
            label: 'Carte bancaire',
            selected: selected == 'STRIPE',
            onTap: () => onChanged('STRIPE'),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.mobiliBlueFog : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.mobiliBlue : AppColors.gray200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color:
                    selected ? AppColors.mobiliBlue : AppColors.gray400),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected
                      ? AppColors.mobiliBlueDeep
                      : AppColors.gray500,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  const _CountBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onTap != null ? AppColors.mobiliBlueFog : AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: onTap != null ? AppColors.mobiliBlue : AppColors.gray300),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre prix + bouton paiement / demande
// ─────────────────────────────────────────────────────────────────────────────

class _PriceBar extends StatelessWidget {
  const _PriceBar({
    required this.selectedCount,
    required this.pricePerSeat,
    required this.luggageFee,
    required this.total,
    required this.isLoading,
    required this.isValid,
    required this.onPay,
    this.isCovoiturage = false,
    this.serviceFee,
  });

  final int selectedCount;
  final double pricePerSeat;
  final double luggageFee;
  final double total;
  final bool isLoading;
  final bool isValid;
  final VoidCallback onPay;
  final bool isCovoiturage;

  /// Forfait client — null tant que la prévisualisation serveur n'a pas encore répondu
  /// (voir _refreshPricePreview) ; la ligne n'apparaît alors simplement pas plutôt que
  /// d'afficher un montant faux à 0 FCFA.
  final int? serviceFee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$selectedCount siège${selectedCount > 1 ? 's' : ''} × ${pricePerSeat.toStringAsFixed(0)} FCFA',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray500),
                ),
                Text(
                  '${(selectedCount * pricePerSeat).toStringAsFixed(0)} FCFA',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.gray600),
                ),
              ],
            ),
            if (luggageFee > 0) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bagages',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray500)),
                  Text(
                    '${luggageFee.toStringAsFixed(0)} FCFA',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.gray600),
                  ),
                ],
              ),
            ],
            if (serviceFee != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Frais de réservation',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray500)),
                  Text(
                    '$serviceFee FCFA',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.gray600),
                  ),
                ],
              ),
            ],
            const Divider(height: 12, color: AppColors.gray100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mobiliBlueDeep,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  '${total.toStringAsFixed(0)} FCFA',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.mobiliBlueDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          MobiliButton(
            label: isValid
                ? (isCovoiturage
                    ? 'Envoyer la demande au conducteur'
                    : 'Payer ${total.toStringAsFixed(0)} FCFA')
                : selectedCount == 0
                    ? 'Sélectionnez un siège'
                    : 'Renseignez les noms des passagers',
            enabled: isValid && !isLoading,
            isLoading: isLoading,
            onPressed: isValid ? onPay : null,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mobiliBlue),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.mobiliBlueDeep,
                fontWeight: FontWeight.w700,
              )),
        ],
      );
}
